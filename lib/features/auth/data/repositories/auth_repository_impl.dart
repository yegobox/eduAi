import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/app_role.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/phone_otp_challenge.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_phone_auth_data_source.dart';
import '../datasources/offline_credential_store.dart';
import '../datasources/profile_remote_data_source.dart';
import '../datasources/supabase_auth_data_source.dart';

/// The one implementation of [AuthRepository]. It coordinates three data
/// sources (Supabase, Firebase phone, offline cache), translates every
/// transport error into a [Failure], and publishes a single merged auth
/// stream to the app.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required SupabaseAuthDataSource supabaseSource,
    required FirebasePhoneAuthDataSource phoneSource,
    required OfflineCredentialStore offlineStore,
    ProfileRemoteDataSource? profileSource,
  })  : _supabase = supabaseSource,
        _phone = phoneSource,
        _offline = offlineStore,
        _profiles = profileSource {
    _wireSupabaseStream();
  }

  final SupabaseAuthDataSource _supabase;
  final FirebasePhoneAuthDataSource _phone;
  final OfflineCredentialStore _offline;

  /// Null on builds with no Supabase; sessions then keep whatever role the
  /// offline cache already held.
  final ProfileRemoteDataSource? _profiles;

  static const _log = AppLogger('AuthRepo');

  final _controller = StreamController<AuthSession?>.broadcast();
  StreamSubscription<AuthSession?>? _supabaseSub;

  void _wireSupabaseStream() {
    _supabaseSub = _supabase.authStateChanges().listen((session) async {
      if (session == null) {
        _controller.add(null);
        return;
      }
      // Resolve the role before publishing: the router picks a shell from it,
      // and emitting a student session first would flash the wrong shell at a
      // parent or a director on every token refresh.
      final resolved = await _withServerRole(session);
      await _cacheFromSession(resolved);
      _controller.add(resolved);
    });
  }

  /// Replaces the session's role with the one on `profiles`.
  ///
  /// A null answer (offline, no Supabase, no row yet) leaves the role alone,
  /// falling back to whatever this device last cached for the account, so a
  /// dropped request never demotes a director to the student shell.
  Future<AuthSession> _withServerRole(AuthSession session) async {
    final profiles = _profiles;
    if (profiles == null || !profiles.isConfigured) {
      return _withCachedRole(session);
    }
    final profile = await profiles.fetchProfile(session.user.id);
    if (profile == null) return _withCachedRole(session);
    unawaited(
      profiles.syncDisplayFields(
        userId: session.user.id,
        displayName: session.user.displayName,
        phone: session.user.phoneNumber,
      ),
    );
    final withRole = _copyWithRole(session, profile.role);

    // An email sign-up has no phone on its Supabase identity, so the number
    // saved after a Mobile Money payment is the only one the payment sheet can
    // pre-fill from. The identity's own number always wins when it has one.
    final own = session.user.phoneNumber?.trim();
    final saved = profile.phone;
    if ((own != null && own.isNotEmpty) || saved == null || saved.isEmpty) {
      return withRole;
    }
    return AuthSession(
      user: withRole.user.copyWith(phoneNumber: saved),
      provider: withRole.provider,
      accessToken: withRole.accessToken,
      refreshToken: withRole.refreshToken,
      expiresAt: withRole.expiresAt,
    );
  }

  Future<AuthSession> _withCachedRole(AuthSession session) async {
    try {
      final cached = await _offline.read();
      if (cached == null || cached.user.id != session.user.id) return session;
      return _copyWithRole(session, cached.user.role);
    } catch (_) {
      return session;
    }
  }

  AuthSession _copyWithRole(AuthSession session, AppRole role) {
    if (session.user.role == role) return session;
    return AuthSession(
      user: session.user.copyWith(role: role),
      provider: session.provider,
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      expiresAt: session.expiresAt,
    );
  }

  Future<void> _cacheFromSession(AuthSession session) async {
    try {
      await _offline.cacheAccount(
        user: session.user,
        provider: session.provider,
        refreshToken: session.refreshToken,
        now: DateTime.now(),
      );
    } catch (e, s) {
      _log.warn('Could not refresh offline cache: $e');
      _log.debug(s);
    }
  }

  @override
  Stream<AuthSession?> authStateChanges() => _controller.stream;

  @override
  Future<AuthSession?> restoreSession() async {
    // 1) A live/persisted Supabase session (readable offline from disk).
    final supa = _supabase.currentSession;
    if (supa != null) return _withServerRole(supa);
    // 2) A live Firebase phone session.
    final fbSession = _phone.currentSession;
    if (fbSession != null) return _withCachedRole(fbSession);
    return null;
  }

  // ---- Supabase email ----------------------------------------------------

  @override
  Future<Result<AuthSession>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final invalid = _validateEmail(email) ?? _validatePassword(password);
    if (invalid != null) return Result.failure(invalid);

    try {
      final signedIn =
          await _supabase.signInWithEmail(email: email, password: password);
      final session = await _withServerRole(signedIn);
      await _cacheFromSession(session);
      _controller.add(session);
      return Result.success(session);
    } catch (e, s) {
      _log.error('signInWithEmail failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required AppRole role,
    String? displayName,
  }) async {
    final invalid = _validateEmail(email) ?? _validatePassword(password);
    if (invalid != null) return Result.failure(invalid);

    try {
      final user = await _supabase.signUpWithEmail(
        email: email,
        password: password,
        roleWireName: role.wireName,
        displayName: displayName,
      );
      // The trigger has written the role server-side; reflect the request
      // locally so the confirmation copy can name the right surface.
      return Result.success(user.copyWith(role: role));
    } catch (e, s) {
      _log.error('signUpWithEmail failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    final invalid = _validateEmail(email);
    if (invalid != null) return Result.failure(invalid);
    try {
      await _supabase.sendPasswordReset(email);
      return const Result.success(null);
    } catch (e, s) {
      _log.error('sendPasswordReset failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<void> rememberPayerPhone(String phoneNumber) async {
    final profiles = _profiles;
    final userId = _supabase.currentSession?.user.id;
    final normalized = phoneNumber.trim();
    if (profiles == null || userId == null || normalized.isEmpty) return;
    await profiles.syncDisplayFields(userId: userId, phone: normalized);
  }

  // ---- Firebase phone ----------------------------------------------------

  @override
  Future<Result<PhoneOtpChallenge>> sendPhoneOtp({
    required String phoneNumber,
    int? resendToken,
  }) async {
    final normalized = phoneNumber.trim();
    if (!normalized.startsWith('+') || normalized.length < 8) {
      return const Result.failure(
        ValidationFailure('Enter the number in international format, e.g. +250…'),
      );
    }
    try {
      final challenge = await _phone.sendOtp(
        phoneNumber: normalized,
        resendToken: resendToken,
      );
      return Result.success(challenge);
    } catch (e, s) {
      _log.error('sendPhoneOtp failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  @override
  Future<Result<AuthSession>> verifyPhoneOtp({
    required PhoneOtpChallenge challenge,
    required String smsCode,
  }) async {
    if (smsCode.trim().length < 4) {
      return const Result.failure(ValidationFailure('Enter the code you received.'));
    }
    try {
      final verified =
          await _phone.verifyOtp(challenge: challenge, smsCode: smsCode);
      // Phone identities live in Firebase, not in Supabase, so there is no
      // profiles row to read a role from — see the note in the README. The
      // device cache is the only role source for them.
      final session = await _withCachedRole(verified);
      await _cacheFromSession(session);
      _controller.add(session);
      return Result.success(session);
    } catch (e, s) {
      _log.error('verifyPhoneOtp failed', e, s);
      return Result.failure(_mapError(e));
    }
  }

  // ---- Offline unlock ----------------------------------------------------

  @override
  Future<bool> hasOfflineCredential() async => (await _offline.read()) != null;

  @override
  Future<String?> offlineAccountLabel() async {
    final c = await _offline.read();
    return c?.user.email ?? c?.user.phoneNumber ?? c?.user.displayName;
  }

  @override
  Future<bool> hasOfflinePin() async => (await _offline.read())?.hasPin ?? false;

  @override
  Future<Result<void>> setOfflinePin(String pin) async {
    final invalid = _validatePin(pin);
    if (invalid != null) return Result.failure(invalid);
    try {
      final ok = await _offline.setPin(pin);
      if (!ok) {
        return const Result.failure(
          CacheFailure(
            message: 'Sign in online once before setting an offline PIN.',
          ),
        );
      }
      return const Result.success(null);
    } catch (e, s) {
      _log.error('setOfflinePin failed', e, s);
      return const Result.failure(CacheFailure());
    }
  }

  @override
  Future<Result<AuthSession>> unlockOffline(String pin) async {
    final invalid = _validatePin(pin);
    if (invalid != null) return Result.failure(invalid);
    try {
      final credential = await _offline.read();
      if (credential == null || !credential.hasPin) {
        return const Result.failure(
          AuthFailure('No offline PIN is set up on this device.'),
        );
      }
      final ok = await _offline.verifyPin(pin);
      if (!ok) {
        return const Result.failure(AuthFailure('Incorrect PIN. Try again.'));
      }
      final session = AuthSession(
        user: credential.user,
        provider: AuthProvider.offline,
      );
      _controller.add(session);
      return Result.success(session);
    } catch (e, s) {
      _log.error('unlockOffline failed', e, s);
      return const Result.failure(CacheFailure());
    }
  }

  // ---- Sign out ----------------------------------------------------------

  @override
  Future<Result<void>> signOut({bool forgetDevice = false}) async {
    try {
      await _supabase.signOut();
      await _phone.signOut();
      if (forgetDevice) await _offline.clear();
      _controller.add(null);
      return const Result.success(null);
    } catch (e, s) {
      _log.error('signOut failed', e, s);
      // Even if remote sign-out fails, drop the local session.
      _controller.add(null);
      return Result.failure(_mapError(e));
    }
  }

  Future<void> dispose() async {
    await _supabaseSub?.cancel();
    await _controller.close();
  }

  // ---- Validation & error mapping ---------------------------------------

  Failure? _validateEmail(String email) {
    final e = email.trim();
    if (e.isEmpty) return const ValidationFailure('Email is required.');
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e);
    return ok ? null : const ValidationFailure('Enter a valid email address.');
  }

  Failure? _validatePassword(String password) {
    if (password.isEmpty) return const ValidationFailure('Password is required.');
    if (password.length < 6) {
      return const ValidationFailure('Password must be at least 6 characters.');
    }
    return null;
  }

  Failure? _validatePin(String pin) {
    final ok = RegExp(r'^\d{4,8}$').hasMatch(pin);
    return ok ? null : const ValidationFailure('PIN must be 4–8 digits.');
  }

  Failure _mapError(Object error) {
    if (error is SupabaseUnavailable || error is PhoneAuthUnavailable) {
      return OfflineUnsupportedFailure(message: error.toString());
    }
    if (error is sb.AuthRetryableFetchException) {
      return NetworkFailure(cause: error);
    }
    if (error is sb.AuthException) {
      return AuthFailure(error.message, cause: error);
    }
    if (error is fb.FirebaseAuthException) {
      return AuthFailure(_firebaseMessage(error), cause: error);
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('connection') ||
        text.contains('failed host lookup')) {
      return NetworkFailure(cause: error);
    }
    return UnknownFailure(cause: error);
  }

  String _firebaseMessage(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'That phone number looks invalid.';
      case 'invalid-verification-code':
        return 'That code is incorrect. Please re-check it.';
      case 'session-expired':
        return 'The code expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? 'Phone verification failed.';
    }
  }
}
