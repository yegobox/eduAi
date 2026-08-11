import 'package:eduai/core/error/failure.dart';
import 'package:eduai/core/error/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('success carries its value and folds via when()', () {
      const Result<int> r = Result.success(42);
      expect(r.isSuccess, isTrue);
      expect(r.valueOrNull, 42);
      expect(r.when(success: (v) => v * 2, failure: (_) => -1), 84);
    });

    test('failure carries its Failure and folds via when()', () {
      const Result<int> r = Result.failure(AuthFailure('nope'));
      expect(r.isFailure, isTrue);
      expect(r.failureOrNull, isA<AuthFailure>());
      expect(r.when(success: (_) => 'ok', failure: (f) => f.message), 'nope');
    });

    test('map transforms success, preserves failure', () {
      const Result<int> ok = Result.success(2);
      expect(ok.map((v) => v + 1).valueOrNull, 3);

      const Result<int> bad = Result.failure(NetworkFailure());
      expect(bad.map((v) => v + 1).failureOrNull, isA<NetworkFailure>());
    });
  });
}
