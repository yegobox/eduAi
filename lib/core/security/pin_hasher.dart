import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Derives and verifies offline-PIN hashes using PBKDF2-HMAC-SHA256.
///
/// The PIN is never stored — only a random salt and the derived key are kept
/// (in secure storage). A high iteration count makes brute-forcing a short PIN
/// on a stolen device expensive.
class PinHasher {
  const PinHasher();

  static const int _iterations = 120000;
  static const int _dkLen = 32; // one SHA-256 block
  static const int _saltLen = 16;

  /// A fresh, cryptographically-random salt, base64-encoded.
  String newSalt() {
    final rng = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(_saltLen, (_) => rng.nextInt(256)),
    );
    return base64Encode(bytes);
  }

  /// Derives the base64 hash of [pin] using [saltB64].
  String hash(String pin, String saltB64) {
    final salt = base64Decode(saltB64);
    final dk = _pbkdf2(utf8.encode(pin), salt, _iterations, _dkLen);
    return base64Encode(dk);
  }

  /// Constant-time comparison of a candidate PIN against a stored hash.
  bool verify({
    required String pin,
    required String saltB64,
    required String expectedHashB64,
  }) {
    final candidate = base64Decode(hash(pin, saltB64));
    final expected = base64Decode(expectedHashB64);
    if (candidate.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < candidate.length; i++) {
      diff |= candidate[i] ^ expected[i];
    }
    return diff == 0;
  }

  // Single-block PBKDF2 (dkLen == hLen == 32) — no block loop needed.
  List<int> _pbkdf2(
    List<int> password,
    List<int> salt,
    int iterations,
    int dkLen,
  ) {
    final hmac = Hmac(sha256, password);
    // INT_32_BE(1) block index appended to the salt.
    final firstInput = <int>[...salt, 0, 0, 0, 1];
    var u = hmac.convert(firstInput).bytes;
    final t = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    return t.sublist(0, dkLen);
  }
}
