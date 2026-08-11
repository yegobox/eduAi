import 'dart:convert';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/security/pin_hasher.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_session.dart';
import '../models/offline_credential.dart';

/// Owns the lifecycle of the single [OfflineCredential] record in secure
/// storage: read/write, PIN set, PIN verify, wipe.
class OfflineCredentialStore {
  OfflineCredentialStore(this._storage, [this._hasher = const PinHasher()]);

  final SecureStorage _storage;
  final PinHasher _hasher;

  static const _log = AppLogger('OfflineStore');
  static const _key = 'eduai.offline_credential.v1';

  Future<OfflineCredential?> read() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null || raw.isEmpty) return null;
      return OfflineCredential.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e, s) {
      _log.error('Failed to read offline credential', e, s);
      return null;
    }
  }

  Future<void> _write(OfflineCredential credential) async {
    await _storage.write(_key, jsonEncode(credential.toJson()));
  }

  /// Records/refreshes the cached account after a successful online login.
  /// Preserves any existing PIN unless [resetPin] is set.
  Future<void> cacheAccount({
    required AppUser user,
    required AuthProvider provider,
    String? refreshToken,
    required DateTime now,
    bool resetPin = false,
  }) async {
    final existing = await read();
    final sameUser = existing != null && existing.user.id == user.id;

    final credential = OfflineCredential(
      user: user,
      originalProvider: provider,
      salt: (sameUser && !resetPin) ? existing.salt : _hasher.newSalt(),
      pinHash: (sameUser && !resetPin) ? existing.pinHash : null,
      refreshToken: refreshToken ?? (sameUser ? existing.refreshToken : null),
      cachedAt: now,
    );
    await _write(credential);
  }

  /// Sets/replaces the PIN on the cached account. Fails if nothing is cached.
  Future<bool> setPin(String pin) async {
    final existing = await read();
    if (existing == null) return false;
    final salt = existing.salt;
    final hash = _hasher.hash(pin, salt);
    await _write(existing.copyWith(pinHash: hash));
    return true;
  }

  /// Verifies [pin] against the cached hash.
  Future<bool> verifyPin(String pin) async {
    final existing = await read();
    if (existing == null || !existing.hasPin) return false;
    return _hasher.verify(
      pin: pin,
      saltB64: existing.salt,
      expectedHashB64: existing.pinHash!,
    );
  }

  Future<void> clear() => _storage.delete(_key);
}
