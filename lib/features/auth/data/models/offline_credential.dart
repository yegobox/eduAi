import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';

/// The device-local record that powers offline unlock. Persisted (as JSON) in
/// the OS-encrypted secure store — see [OfflineCredentialStore].
///
/// It never contains the plaintext PIN or password; only a salted PBKDF2 hash
/// of the PIN plus (optionally) the last known refresh token so the session
/// can be silently re-established when connectivity returns.
class OfflineCredential {
  const OfflineCredential({
    required this.user,
    required this.originalProvider,
    required this.salt,
    required this.cachedAt,
    this.pinHash,
    this.pinIterations = 120000,
    this.refreshToken,
  });

  final AppUser user;
  final AuthProvider originalProvider;

  /// Base64 salt used for the PIN hash.
  final String salt;

  /// Base64 PBKDF2 hash of the PIN, or null until the user sets a PIN.
  final String? pinHash;

  final int pinIterations;

  /// Last known Supabase refresh token, for silent re-auth when back online.
  final String? refreshToken;

  final DateTime cachedAt;

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  OfflineCredential copyWith({
    AppUser? user,
    AuthProvider? originalProvider,
    String? salt,
    String? pinHash,
    int? pinIterations,
    String? refreshToken,
    DateTime? cachedAt,
  }) {
    return OfflineCredential(
      user: user ?? this.user,
      originalProvider: originalProvider ?? this.originalProvider,
      salt: salt ?? this.salt,
      pinHash: pinHash ?? this.pinHash,
      pinIterations: pinIterations ?? this.pinIterations,
      refreshToken: refreshToken ?? this.refreshToken,
      cachedAt: cachedAt ?? this.cachedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'originalProvider': originalProvider.name,
        'salt': salt,
        'pinHash': pinHash,
        'pinIterations': pinIterations,
        'refreshToken': refreshToken,
        'cachedAt': cachedAt.toIso8601String(),
      };

  factory OfflineCredential.fromJson(Map<String, dynamic> json) {
    return OfflineCredential(
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      originalProvider: AuthProvider.values.firstWhere(
        (p) => p.name == json['originalProvider'],
        orElse: () => AuthProvider.supabaseEmail,
      ),
      salt: json['salt'] as String,
      pinHash: json['pinHash'] as String?,
      pinIterations: (json['pinIterations'] as num?)?.toInt() ?? 120000,
      refreshToken: json['refreshToken'] as String?,
      cachedAt: DateTime.tryParse(json['cachedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
