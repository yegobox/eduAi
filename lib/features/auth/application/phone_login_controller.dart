import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/entities/auth_session.dart';
import '../domain/entities/phone_otp_challenge.dart';
import 'auth_providers.dart';

enum PhonePhase { enterPhone, enterCode }

/// UI state for the SMS sign-in flow.
class PhoneLoginState extends Equatable {
  const PhoneLoginState({
    this.phase = PhonePhase.enterPhone,
    this.submitting = false,
    this.challenge,
    this.failure,
  });

  final PhonePhase phase;
  final bool submitting;
  final PhoneOtpChallenge? challenge;
  final Failure? failure;

  PhoneLoginState copyWith({
    PhonePhase? phase,
    bool? submitting,
    PhoneOtpChallenge? challenge,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return PhoneLoginState(
      phase: phase ?? this.phase,
      submitting: submitting ?? this.submitting,
      challenge: challenge ?? this.challenge,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [phase, submitting, challenge, failure];
}

/// Drives the two-step SMS flow: request code, then verify it.
class PhoneLoginController extends AutoDisposeNotifier<PhoneLoginState> {
  @override
  PhoneLoginState build() => const PhoneLoginState();

  Future<void> sendCode(String phoneNumber) async {
    state = state.copyWith(submitting: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .sendPhoneOtp(phoneNumber: phoneNumber);
    state = result.when(
      success: (challenge) => state.copyWith(
        submitting: false,
        phase: PhonePhase.enterCode,
        challenge: challenge,
        clearFailure: true,
      ),
      failure: (f) => state.copyWith(submitting: false, failure: f),
    );
  }

  Future<Result<AuthSession>> verifyCode(String smsCode) async {
    final challenge = state.challenge;
    if (challenge == null) {
      const f = ValidationFailure('Request a code first.');
      state = state.copyWith(failure: f);
      return const Result.failure(f);
    }
    state = state.copyWith(submitting: true, clearFailure: true);
    final result = await ref
        .read(authRepositoryProvider)
        .verifyPhoneOtp(challenge: challenge, smsCode: smsCode);
    state = result.when(
      success: (_) => state.copyWith(submitting: false, clearFailure: true),
      failure: (f) => state.copyWith(submitting: false, failure: f),
    );
    return result;
  }

  /// Back to the phone-entry step (e.g. wrong number).
  void reset() => state = const PhoneLoginState();
}

final phoneLoginControllerProvider =
    AutoDisposeNotifierProvider<PhoneLoginController, PhoneLoginState>(
  PhoneLoginController.new,
);
