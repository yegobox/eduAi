import 'package:equatable/equatable.dart';

/// One purchasable licence tier, read from the server's `plan_tiers` table.
///
/// The price is quoted here for display only. What a school actually pays is
/// recomputed server-side at settlement, so editing this on the client changes
/// the label and nothing else.
class PlanTier extends Equatable {
  const PlanTier({
    required this.id,
    required this.name,
    required this.pricePerSeatRwf,
    required this.seatsLabel,
    required this.features,
    this.maxSeats,
  });

  final String id;
  final String name;

  /// RWF per student per month.
  final int pricePerSeatRwf;

  /// Human range, e.g. "Up to 800 students".
  final String seatsLabel;

  final List<String> features;

  /// Hard seat ceiling for the tier, or null for unlimited (District).
  final int? maxSeats;

  /// True when [seats] would not fit on this tier.
  bool exceededBy(int seats) => maxSeats != null && seats > maxSeats!;

  factory PlanTier.fromJson(Map<String, dynamic> json) => PlanTier(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    pricePerSeatRwf: (json['price_per_seat_rwf'] as num?)?.round() ?? 0,
    seatsLabel: json['seats_label'] as String? ?? '',
    features:
        (json['features'] as List?)?.map((e) => e.toString()).toList() ??
        const [],
    maxSeats: (json['max_seats'] as num?)?.round(),
  );

  @override
  List<Object?> get props => [
    id,
    name,
    pricePerSeatRwf,
    seatsLabel,
    features,
    maxSeats,
  ];
}

/// How a recorded payment turned out.
///
/// `disputed` is the case worth naming: the gateway reported less than the
/// server had quoted, so nothing was granted and a human needs to look. Hiding
/// that as "failed" would lose real money that a school genuinely sent.
enum PaymentState {
  settled,
  pending,
  disputed,
  failed;

  String get label => switch (this) {
    PaymentState.settled => 'Paid',
    PaymentState.pending => 'Pending',
    PaymentState.disputed => 'Check',
    PaymentState.failed => 'Failed',
  };

  static PaymentState fromWire(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'settled' => PaymentState.settled,
        'disputed' => PaymentState.disputed,
        'failed' => PaymentState.failed,
        _ => PaymentState.pending,
      };
}

/// One row of the payment ledger — a real Mobile Money reference, not a
/// generated invoice number, so a school's records tie back to their statement.
class Invoice extends Equatable {
  const Invoice({
    required this.reference,
    required this.issuedOn,
    required this.amountRwf,
    required this.state,
    this.seats,
    this.tierName,
  });

  final String reference;
  final DateTime issuedOn;
  final int amountRwf;
  final PaymentState state;

  /// Seats billed, when the payment metadata recorded them.
  final int? seats;
  final String? tierName;

  /// A short, readable id for the row: the tail of the MTN reference.
  String get shortReference => reference.length <= 10
      ? reference
      : '…${reference.substring(reference.length - 8)}';

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final metadata = json['metadata'];
    final meta = metadata is Map ? Map<String, dynamic>.from(metadata) : const {};
    return Invoice(
      reference: json['reference'] as String? ?? '',
      issuedOn:
          DateTime.tryParse(
            (json['settled_at'] ?? json['created_at']) as String? ?? '',
          )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      // What was actually charged, falling back to what was quoted.
      amountRwf:
          (json['amount_reported_rwf'] as num?)?.round() ??
          (json['amount_expected_rwf'] as num?)?.round() ??
          0,
      state: PaymentState.fromWire(json['status'] as String?),
      seats: (meta['seats'] as num?)?.round(),
      tierName: meta['tier_name'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    reference,
    issuedOn,
    amountRwf,
    state,
    seats,
    tierName,
  ];
}

/// Renewal-conversation numbers for the school board.
class UsageStats extends Equatable {
  const UsageStats({
    required this.activeStudentRatio,
    required this.sessionsPerStudentPerWeek,
    required this.masteryLiftRatio,
    required this.topSubject,
  });

  final double activeStudentRatio;
  final double sessionsPerStudentPerWeek;
  final double masteryLiftRatio;
  final String topSubject;

  @override
  List<Object?> get props => [
    activeStudentRatio,
    sessionsPerStudentPerWeek,
    masteryLiftRatio,
    topSubject,
  ];
}
