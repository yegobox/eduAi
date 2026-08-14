import 'package:equatable/equatable.dart';

/// Where a request-to-pay currently stands.
enum MomoPaymentStatus {
  /// The push has been sent; the payer has not entered their PIN yet.
  pending,
  successful,
  failed;

  /// MTN reports `SUCCESSFUL` / `PENDING` / `FAILED` / `REJECTED` /
  /// `TIMEOUT`. Anything unrecognised is treated as still pending rather than
  /// failed — polling can then resolve it, and we never tell a parent their
  /// money vanished because of an unfamiliar status string.
  static MomoPaymentStatus fromWire(String? value) {
    return switch (value?.trim().toUpperCase()) {
      'SUCCESSFUL' => MomoPaymentStatus.successful,
      'FAILED' ||
      'REJECTED' ||
      'TIMEOUT' ||
      'EXPIRED' => MomoPaymentStatus.failed,
      _ => MomoPaymentStatus.pending,
    };
  }
}

/// One poll of `GET /v2/api/requesttopay/status/{reference}/{branchId}`.
class MomoSettlement extends Equatable {
  const MomoSettlement({
    required this.reference,
    required this.status,
    this.financialTransactionId,
    this.externalId,
    this.settledAmountRwf,
    this.reason,
  });

  /// The request-to-pay id — the same value MTN calls `X-Reference-Id`.
  final String reference;

  final MomoPaymentStatus status;

  /// MTN's own transaction id, present once settled. This is the number a
  /// parent will read off their SMS receipt.
  final String? financialTransactionId;

  final String? externalId;

  /// The amount MTN actually settled. Trusted over the requested amount.
  final int? settledAmountRwf;

  /// Gateway-supplied failure reason, when it gives one.
  final String? reason;

  bool get isSuccessful => status == MomoPaymentStatus.successful;
  bool get isPending => status == MomoPaymentStatus.pending;

  factory MomoSettlement.fromJson(String reference, Map<String, dynamic> json) {
    final amount = json['amount'];
    return MomoSettlement(
      reference: reference,
      status: MomoPaymentStatus.fromWire(json['status']?.toString()),
      financialTransactionId: json['financialTransactionId']?.toString(),
      externalId: json['externalId']?.toString(),
      settledAmountRwf: amount is num
          ? amount.round()
          : int.tryParse(amount?.toString().trim() ?? ''),
      reason: json['reason']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
    reference,
    status,
    financialTransactionId,
    externalId,
    settledAmountRwf,
    reason,
  ];
}

/// What the caller is paying for. Sent as payNow's `paymentType` and used to
/// label the transaction in the payer's MoMo statement.
enum MomoPurpose {
  /// A parent buying extra AI Tutor sessions on top of existing access.
  tutorTopUp('EduAI top-up', 'EduAI tutor sessions'),

  /// A school paying its per-seat licence.
  schoolLicense('EduAI school licence', 'EduAI licence'),

  /// A parent buying access directly, with no school involved.
  parentSubscription('EduAI family plan', 'EduAI family plan');

  const MomoPurpose(this.payerMessage, this.payeeNote);

  final String payerMessage;
  final String payeeNote;
}
