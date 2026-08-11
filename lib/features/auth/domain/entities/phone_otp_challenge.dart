import 'package:equatable/equatable.dart';

/// Opaque handle returned after an SMS code has been dispatched. The
/// [verificationId] is passed back when the user enters the code they receive.
class PhoneOtpChallenge extends Equatable {
  const PhoneOtpChallenge({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  final String phoneNumber;
  final String verificationId;

  /// Platform token (Android) used to force a resend without re-triggering
  /// the whole flow. Null elsewhere.
  final int? resendToken;

  @override
  List<Object?> get props => [phoneNumber, verificationId, resendToken];
}
