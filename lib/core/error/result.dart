import 'failure.dart';

/// A lightweight functional result type: either a [Success] carrying a value
/// or a [ResultFailure] carrying a [Failure].
///
/// Repositories and use cases return `Result<T>` instead of throwing, so the
/// presentation layer handles both branches explicitly.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = ResultFailure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is ResultFailure<T>;

  /// The value if successful, otherwise null.
  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        ResultFailure<T>() => null,
      };

  /// The failure if failed, otherwise null.
  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        ResultFailure<T>(:final failure) => failure,
      };

  /// Exhaustive pattern-match helper.
  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) {
    return switch (this) {
      Success<T>(:final value) => success(value),
      ResultFailure<T>(failure: final f) => failure(f),
    };
  }

  /// Transform the success value, preserving failures.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(:final value) => Success<R>(transform(value)),
      ResultFailure<T>(:final failure) => ResultFailure<R>(failure),
    };
  }
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.failure);
  final Failure failure;
}
