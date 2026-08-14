import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';

/// Wraps the Supabase auth client and maps its types to our domain entities.
/// Throws Supabase's [sb.AuthException] on failure — the repository translates.
///
/// When [client] is null (no credentials configured) every online method
/// throws [SupabaseUnavailable] so callers fall back to offline paths.
class SupabaseAuthDataSource {
  SupabaseAuthDataSource(this._client);

  final sb.SupabaseClient? _client;

  bool get isConfigured => _client != null;

  sb.SupabaseClient get _c {
    final c = _client;
    if (c == null) throw const SupabaseUnavailable();
    return c;
  }

  AppUser? _mapUser(sb.User? u) {
    if (u == null) return null;
    final meta = u.userMetadata ?? const {};
    return AppUser(
      id: u.id,
      email: u.email,
      phoneNumber: u.phone,
      displayName: (meta['display_name'] ?? meta['name']) as String?,
      avatarUrl: meta['avatar_url'] as String?,
    );
  }

  AuthSession? _mapSession(sb.Session? s) {
    if (s == null) return null;
    final user = _mapUser(s.user);
    if (user == null) return null;
    return AuthSession(
      user: user,
      provider: AuthProvider.supabaseEmail,
      accessToken: s.accessToken,
      refreshToken: s.refreshToken,
      expiresAt: s.expiresAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(s.expiresAt! * 1000),
    );
  }

  /// The locally-persisted session, if any. Available offline (read from disk),
  /// which is what lets a recently-authenticated user resolve without network.
  AuthSession? get currentSession => _mapSession(_client?.auth.currentSession);

  Stream<AuthSession?> authStateChanges() {
    final c = _client;
    if (c == null) return const Stream<AuthSession?>.empty();
    return c.auth.onAuthStateChange.map((event) => _mapSession(event.session));
  }

  Future<AuthSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final res = await _c.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final session = _mapSession(res.session);
    if (session == null) {
      throw const sb.AuthException('Sign-in did not return a session.');
    }
    return session;
  }

  /// [roleWireName] travels as sign-up metadata, where the `handle_new_user`
  /// trigger reads it. The trigger validates it rather than trusting it, so a
  /// modified client cannot mint itself an admin account this way.
  Future<AppUser> signUpWithEmail({
    required String email,
    required String password,
    required String roleWireName,
    String? displayName,
  }) async {
    final res = await _c.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'role': roleWireName, 'display_name': ?displayName},
    );
    final user = _mapUser(res.user);
    if (user == null) {
      throw const sb.AuthException('Sign-up did not return a user.');
    }
    return user;
  }

  Future<void> sendPasswordReset(String email) {
    return _c.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    final c = _client;
    if (c == null) return;
    await c.auth.signOut();
  }
}

/// Thrown when Supabase is not configured on this build.
class SupabaseUnavailable implements Exception {
  const SupabaseUnavailable();
  @override
  String toString() => 'Supabase is not configured on this device.';
}
