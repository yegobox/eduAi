import 'package:equatable/equatable.dart';

/// What a school owes for its licence right now, priced by the server.
///
/// The client never proposes an amount. It asks for a quote, shows exactly
/// that, pays exactly that, and the settle call recomputes it server-side
/// before granting anything — so a modified build cannot buy the District
/// tier for 1 RWF.
class SchoolLicenseQuote extends Equatable {
  const SchoolLicenseQuote({
    required this.schoolId,
    required this.tierId,
    required this.tierName,
    required this.seats,
    required this.seatsUsed,
    required this.pricePerSeatRwf,
    required this.amountRwf,
    required this.periodDays,
    this.fullAmountRwf,
    this.testMode = false,
  });

  final String schoolId;
  final String tierId;
  final String tierName;

  /// Seats being billed — the larger of seats bought and seats in use.
  final int seats;
  final int seatsUsed;

  final int pricePerSeatRwf;

  /// What will actually be collected. Equals [fullAmountRwf] unless test
  /// pricing is enabled on the project.
  final int amountRwf;

  /// What the licence really costs at list price, kept so a test charge can be
  /// shown next to the figure it is standing in for.
  final int? fullAmountRwf;

  /// True when the server is quoting a reduced amount for testing.
  final bool testMode;

  final int periodDays;

  factory SchoolLicenseQuote.fromJson(Map<String, dynamic> json) {
    return SchoolLicenseQuote(
      schoolId: json['school_id'] as String? ?? '',
      tierId: json['tier_id'] as String? ?? '',
      tierName: json['tier_name'] as String? ?? '',
      seats: _int(json['seats']),
      seatsUsed: _int(json['seats_used']),
      pricePerSeatRwf: _int(json['price_per_seat_rwf']),
      amountRwf: _int(json['amount_rwf']),
      periodDays: _int(json['period_days']),
      fullAmountRwf: json['full_amount_rwf'] == null
          ? null
          : _int(json['full_amount_rwf']),
      testMode: json['test_mode'] == true,
    );
  }

  @override
  List<Object?> get props => [
    schoolId,
    tierId,
    tierName,
    seats,
    seatsUsed,
    pricePerSeatRwf,
    amountRwf,
    periodDays,
    fullAmountRwf,
    testMode,
  ];
}

/// What a directly-paying parent owes, priced by the server per linked child.
class ParentPlanQuote extends Equatable {
  const ParentPlanQuote({
    required this.planId,
    required this.planName,
    required this.children,
    required this.pricePerChildRwf,
    required this.amountRwf,
    required this.periodDays,
    this.fullAmountRwf,
    this.testMode = false,
  });

  final String planId;
  final String planName;
  final int children;
  final int pricePerChildRwf;

  /// What will actually be collected — reduced when test pricing is on.
  final int amountRwf;

  /// The real list price, for showing alongside a test charge.
  final int? fullAmountRwf;

  final bool testMode;
  final int periodDays;

  factory ParentPlanQuote.fromJson(Map<String, dynamic> json) {
    return ParentPlanQuote(
      planId: json['plan_id'] as String? ?? '',
      planName: json['plan_name'] as String? ?? '',
      children: _int(json['children']),
      pricePerChildRwf: _int(json['price_per_child_rwf']),
      amountRwf: _int(json['amount_rwf']),
      periodDays: _int(json['period_days']),
      fullAmountRwf: json['full_amount_rwf'] == null
          ? null
          : _int(json['full_amount_rwf']),
      testMode: json['test_mode'] == true,
    );
  }

  @override
  List<Object?> get props => [
    planId,
    planName,
    children,
    pricePerChildRwf,
    amountRwf,
    periodDays,
    fullAmountRwf,
    testMode,
  ];
}

/// One row of the direct-to-parent price list.
class ParentPlanOption extends Equatable {
  const ParentPlanOption({
    required this.id,
    required this.name,
    required this.pricePerChildRwf,
    required this.periodDays,
    required this.features,
  });

  final String id;
  final String name;
  final int pricePerChildRwf;
  final int periodDays;
  final List<String> features;

  /// `per month` / `per term` — how the price reads on the card.
  String get periodLabel => switch (periodDays) {
    <= 31 => 'per child / month',
    <= 100 => 'per child / term',
    _ => 'per child / year',
  };

  factory ParentPlanOption.fromJson(Map<String, dynamic> json) {
    return ParentPlanOption(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      pricePerChildRwf: _int(json['price_per_child_rwf']),
      periodDays: _int(json['period_days']),
      features:
          (json['features'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    pricePerChildRwf,
    periodDays,
    features,
  ];
}

int _int(Object? value) => switch (value) {
  final num n => n.round(),
  final String s => int.tryParse(s.trim()) ?? 0,
  _ => 0,
};
