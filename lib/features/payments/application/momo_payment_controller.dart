import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/error/failure.dart';
import '../../../core/network/http_client_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../data/datasources/momo_remote_data_source.dart';
import '../data/repositories/payments_repository_impl.dart';
import '../domain/entities/momo_payment.dart';
import '../domain/momo_msisdn.dart';
import '../domain/repositories/payments_repository.dart';

// ---- DI graph ------------------------------------------------------------

final _momoRemoteProvider = Provider<MomoRemoteDataSource>((ref) {
  return MomoRemoteDataSource(
    ref.watch(httpClientProvider),
    ref.watch(appConfigProvider),
  );
});

final paymentsRepositoryProvider = Provider<PaymentsRepository>((ref) {
  return PaymentsRepositoryImpl(remoteSource: ref.watch(_momoRemoteProvider));
});

/// How often the request-to-pay status is polled. Matches Flipper's cadence;
/// overridden to milliseconds in tests.
final momoPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 12),
);

/// How long to wait for the payer to enter their PIN before giving up on the
/// *poll* (the payment itself may still settle later, which is why the
/// timeout copy never says the payment failed).
final momoPollTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 5),
);

// ---- State ---------------------------------------------------------------

enum MomoStage {
  idle,

  /// payNow in flight.
  initiating,

  /// Push delivered; waiting for the payer to approve on their handset.
  awaitingApproval,
  confirmed,
  failed,

  /// Still unresolved when the poll window closed.
  timedOut,
}

class MomoPaymentState extends Equatable {
  const MomoPaymentState({
    this.stage = MomoStage.idle,
    this.reference,
    this.settlement,
    this.failure,
    this.amountRwf = 0,
  });

  final MomoStage stage;
  final String? reference;
  final MomoSettlement? settlement;
  final Failure? failure;
  final int amountRwf;

  bool get isBusy =>
      stage == MomoStage.initiating || stage == MomoStage.awaitingApproval;

  MomoPaymentState copyWith({
    MomoStage? stage,
    String? reference,
    MomoSettlement? settlement,
    Failure? failure,
    bool clearFailure = false,
    int? amountRwf,
  }) {
    return MomoPaymentState(
      stage: stage ?? this.stage,
      reference: reference ?? this.reference,
      settlement: settlement ?? this.settlement,
      failure: clearFailure ? null : (failure ?? this.failure),
      amountRwf: amountRwf ?? this.amountRwf,
    );
  }

  @override
  List<Object?> get props => [stage, reference, settlement, failure, amountRwf];
}

// ---- Controller ----------------------------------------------------------

/// Drives one Mobile Money collection: validate → payNow → poll until MTN
/// reports a terminal status or the window closes.
class MomoPaymentController extends AutoDisposeNotifier<MomoPaymentState> {
  bool _disposed = false;

  @override
  MomoPaymentState build() {
    ref.onDispose(() => _disposed = true);
    return const MomoPaymentState();
  }

  /// Writes only while the controller is alive. Closing the payment sheet
  /// mid-poll disposes this notifier; the payment continues server-side and
  /// the next status read will find it settled.
  void _set(MomoPaymentState next) {
    if (_disposed) return;
    state = next;
  }

  void reset() => _set(const MomoPaymentState());

  Future<void> pay({
    required String phoneNumber,
    required int amountRwf,
    required MomoPurpose purpose,
  }) async {
    if (state.isBusy) return;

    if (!MomoMsisdn.isValid(phoneNumber)) {
      _set(
        state.copyWith(
          stage: MomoStage.failed,
          failure: const ValidationFailure(
            'Enter a valid MTN or Airtel number, e.g. 0788123456.',
          ),
        ),
      );
      return;
    }

    _set(MomoPaymentState(stage: MomoStage.initiating, amountRwf: amountRwf));

    final initiated = await ref
        .read(paymentsRepositoryProvider)
        .initiate(
          phoneNumber: phoneNumber,
          amountRwf: amountRwf,
          purpose: purpose,
        );

    final reference = initiated.valueOrNull;
    if (reference == null) {
      _set(
        state.copyWith(
          stage: MomoStage.failed,
          failure: initiated.failureOrNull,
        ),
      );
      return;
    }

    _set(
      state.copyWith(stage: MomoStage.awaitingApproval, reference: reference),
    );
    await _pollUntilSettled(reference, payerPhone: phoneNumber);
  }

  Future<void> _pollUntilSettled(
    String reference, {
    required String payerPhone,
  }) async {
    final interval = ref.read(momoPollIntervalProvider);
    final timeout = ref.read(momoPollTimeoutProvider);
    final deadline = DateTime.now().add(timeout);

    while (!_disposed && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(interval);
      if (_disposed) return;

      final result = await ref
          .read(paymentsRepositoryProvider)
          .fetchStatus(reference);
      final settlement = result.valueOrNull;

      // A failed *read* is not a failed payment — the handset may simply be
      // offline. Keep polling until the deadline.
      if (settlement == null) continue;

      // A pending status can still carry an explanation, and when it does it is
      // usually the reason no prompt will ever arrive — a gateway that could
      // not reach MTN reports PENDING with the transport error attached. Keep
      // polling (the gateway's own sweep may still resolve it) but stop hiding
      // it: waiting five silent minutes for a push that was never sent is how
      // a broken gateway looks exactly like a slow payer.
      final reason = settlement.reason?.trim();
      if (settlement.isPending && reason != null && reason.isNotEmpty) {
        _set(state.copyWith(settlement: settlement));
      }

      if (settlement.isSuccessful) {
        // Remember the number that actually paid, so an account that signed up
        // with an email does not retype it every month. Unawaited and
        // best-effort: the money has already moved, and a failed write here
        // must not turn a settled payment into an error.
        unawaited(
          ref.read(authRepositoryProvider).rememberPayerPhone(payerPhone),
        );
        _set(
          state.copyWith(
            stage: MomoStage.confirmed,
            settlement: settlement,
            clearFailure: true,
          ),
        );
        return;
      }
      if (settlement.status == MomoPaymentStatus.failed) {
        _set(
          state.copyWith(
            stage: MomoStage.failed,
            settlement: settlement,
            failure: UnknownFailure(
              message: settlement.reason?.isNotEmpty == true
                  ? settlement.reason!
                  : 'The payment was not completed on your phone.',
            ),
          ),
        );
        return;
      }
    }

    _set(state.copyWith(stage: MomoStage.timedOut));
  }
}

final momoPaymentControllerProvider =
    AutoDisposeNotifierProvider<MomoPaymentController, MomoPaymentState>(
      MomoPaymentController.new,
    );
