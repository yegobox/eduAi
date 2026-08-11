import 'package:equatable/equatable.dart';

/// A domain-level, UI-safe description of something that went wrong.
///
/// Data-layer exceptions (SocketException, AuthException, PlatformException…)
/// are translated into a [Failure] at the repository boundary so that the
/// presentation layer never has to reason about transport-specific errors.
sealed class Failure extends Equatable {
  const Failure({required this.message, this.cause});

  /// Human-readable, already-localisable message safe to surface in the UI.
  final String message;

  /// The original error, kept for logging. Never shown to the user.
  final Object? cause;

  @override
  List<Object?> get props => [message, runtimeType];

  @override
  String toString() => '$runtimeType($message)';
}

/// No connectivity / server unreachable.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please try again.',
    super.cause,
  });
}

/// Credentials rejected, session invalid/expired, OTP wrong, etc.
class AuthFailure extends Failure {
  const AuthFailure(String message, {super.cause}) : super(message: message);
}

/// Local secure-storage / cache problem.
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Could not read secured data on this device.',
    super.cause,
  });
}

/// Caller passed something invalid (bad PIN format, empty email…).
class ValidationFailure extends Failure {
  const ValidationFailure(String message, {super.cause})
      : super(message: message);
}

/// Requested an online-only action while offline.
class OfflineUnsupportedFailure extends Failure {
  const OfflineUnsupportedFailure({
    super.message = 'This action needs an internet connection.',
    super.cause,
  });
}

/// Anything unclassified.
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Something went wrong. Please try again.',
    super.cause,
  });
}
