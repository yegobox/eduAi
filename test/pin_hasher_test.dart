import 'package:eduai/core/security/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hasher = PinHasher();

  group('PinHasher', () {
    test('verifies a correct PIN against its own hash', () {
      final salt = hasher.newSalt();
      final hash = hasher.hash('1234', salt);
      expect(
        hasher.verify(pin: '1234', saltB64: salt, expectedHashB64: hash),
        isTrue,
      );
    });

    test('rejects an incorrect PIN', () {
      final salt = hasher.newSalt();
      final hash = hasher.hash('1234', salt);
      expect(
        hasher.verify(pin: '9999', saltB64: salt, expectedHashB64: hash),
        isFalse,
      );
    });

    test('same PIN with different salts yields different hashes', () {
      final h1 = hasher.hash('4321', hasher.newSalt());
      final h2 = hasher.hash('4321', hasher.newSalt());
      expect(h1, isNot(equals(h2)));
    });

    test('hash is deterministic for a fixed salt', () {
      final salt = hasher.newSalt();
      expect(hasher.hash('5678', salt), equals(hasher.hash('5678', salt)));
    });
  });
}
