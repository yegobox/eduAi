import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/entities/phone_otp_challenge.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/firebase_phone_auth_data_source.dart';
import '../datasources/offline_credential_store.dart';
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
  })  : _supabase = supabaseSource,
        _phone = phoneSource,
        _offline = offlineStore {
    _wireSupabaseStream();
  }

  final SupabaseAuthDataSource _supabase;
  final FirebasePhoneAuthDataSource _phone;
  final OfflineCredentialStore _offline;

  static const _log = AppLogger('AuthRepo');

  final _controller = StreamController<AuthSession?>.broadcast();
  StreamSubscription<AuthSession?>? _supabaseSub;

  void _wireSupabaseStream() {
    _supabaseSub = _supabase.authStateChanges().listen((session) {
      if (session != null) {
        // Keep the offline cache fresh whenever Supabase hands us a session.
        unawaited(_cacheFromSession(session));
      }
      _controller.add(session);
    });
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
    if (supa != null) return supa;
    // 2) A live Firebase phone session.
    final fbSession = _phone.currentSession;
    if (fbSession != null) return fbSession;
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
      final session =
          await _supabase.signInWithEmail(email: email, password: password);
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
    String? displayName,
  }) async {
    final invalid = _validateEmail(email) ?? _validatePassword(password);
    if (invalid != null) return Result.failure(invalid);

    try {
      final user = await _supabase.signUpWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      return Result.success(user);
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
      final session =
          await _phone.verifyOtp(challenge: challenge, smsCode: smsCode);
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
