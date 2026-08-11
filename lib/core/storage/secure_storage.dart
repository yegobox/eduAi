import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper over [FlutterSecureStorage] so the rest of the app depends on
/// an interface we control (easy to fake in tests, easy to re-key later).
///
/// Backed by the OS keystore: DPAPI on Windows, Keychain on iOS/macOS,
/// EncryptedSharedPreferences / Keystore on Android. Uses the plugin defaults
/// so the code stays valid across plugin major versions.
class SecureStorage {
  SecureStorage(this._storage);

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<bool> containsKey(String key) => _storage.containsKey(key: key);
}

/// The concrete secure-storage instance. Overridable in tests.
final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage(const FlutterSecureStorage());
});
