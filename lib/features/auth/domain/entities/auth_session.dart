import 'package:equatable/equatable.dart';

import 'app_user.dart';

/// Which identity provider established the current session.
enum AuthProvider {
  /// Supabase email/password (or any Supabase-native flow).
  supabaseEmail,

  /// Firebase phone (SMS) verification.
  firebasePhone,

  /// Local unlock with the offline PIN — no live server session.
  offline,
}

/// An authenticated session, provider-agnostic.
class AuthSession extends Equatable {
  const AuthSession({
    required this.user,
    required this.provider,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  final AppUser user;
  final AuthProvider provider;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  /// True when the session was unlocked from the local cache without a live
  /// server session. Online-only features should degrade gracefully.
  bool get isOffline => provider == AuthProvider.offline;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  @override
  List<Object?> get props =>
      [user, provider, accessToken, refreshToken, expiresAt];
}
