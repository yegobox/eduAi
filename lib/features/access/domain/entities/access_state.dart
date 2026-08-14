import 'package:equatable/equatable.dart';

import '../../../auth/domain/entities/app_role.dart';

/// Whether the signed-in account may use the paid surface, and why.
///
/// Mirrors the `status` field of the server's `access_state()` function. The
/// decision is made server-side; this enum is how the client renders it.
enum AccessStatus {
  /// Still resolving, or nobody is signed in.
  unknown,

  /// Paid and current.
  entitled,

  /// Inside the trial window — full access, on a clock.
  trialing,

  /// There is something to bill, and it has not been paid.
  needsPayment,

  /// Nothing to bill yet: a director with no school, a parent with no child
  /// linked, a student with no school and no paying parent.
  needsSetup;

  /// True when the paid features may be used right now.
  bool get grantsAccess =>
      this == AccessStatus.entitled || this == AccessStatus.trialing;
}

/// Who is paying.
enum AccessSource {
  none,

  /// A school licence covers this student's seat.
  schoolLicense,

  /// A parent pays directly; no school is involved.
  parentSubscription;

  static AccessSource fromWire(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'school_license' => AccessSource.schoolLicense,
        'parent_subscription' => AccessSource.parentSubscription,
        _ => AccessSource.none,
      };
}

/// The billing state of one school licence, as the server reports it.
enum LicenseStatus {
  none,
  trialing,
  active,
  pastDue,
  expired,
  canceled;

  static LicenseStatus fromWire(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'trialing' => LicenseStatus.trialing,
        'active' => LicenseStatus.active,
        'past_due' => LicenseStatus.pastDue,
        'expired' => LicenseStatus.expired,
        'canceled' => LicenseStatus.canceled,
        _ => LicenseStatus.none,
      };

  String get label => switch (this) {
    LicenseStatus.none => 'No licence',
    LicenseStatus.trialing => 'Trial',
    LicenseStatus.active => 'Active',
    LicenseStatus.pastDue => 'Payment due',
    LicenseStatus.expired => 'Expired',
    LicenseStatus.canceled => 'Cancelled',
  };
}

/// One answer to "may this account use EduAI, and who paid for it?".
///
/// Built from a single `access_state()` round trip so no screen has to
/// assemble entitlement out of several reads and risk disagreeing with
/// another screen.
class AccessState extends Equatable {
  const AccessState({
    required this.status,
    required this.source,
    required this.role,
    this.enforced = true,
    this.schemaMissing = false,
    this.validUntil,
    this.schoolId,
    this.schoolName,
    this.tierId,
    this.licenseStatus = LicenseStatus.none,
    this.seatsPurchased = 0,
    this.seatsUsed = 0,
    this.trialSeatCap = 0,
    this.planId,
    this.childrenCovered = 0,
    this.childrenLinked = 0,
    this.stale = false,
  });

  /// Startup / signed-out placeholder.
  const AccessState.unknown()
    : this(
        status: AccessStatus.unknown,
        source: AccessSource.none,
        role: AppRole.student,
      );

  /// A build with no Supabase credentials (local demo, widget tests, design
  /// review). Entitlement cannot be enforced without a backend, so the app
  /// opens up rather than locking every screen behind a paywall it has no way
  /// to satisfy — [enforced] is false so the UI never claims someone paid.
  const AccessState.unconfigured()
    : this(
        status: AccessStatus.entitled,
        source: AccessSource.none,
        role: AppRole.student,
        enforced: false,
      );

  /// Supabase is there, but the billing schema is not. Same open-up behaviour
  /// as [AccessState.unconfigured] — there is nothing to enforce against — but
  /// flagged so the UI can say exactly what is wrong and how to fix it.
  const AccessState.schemaMissing()
    : this(
        status: AccessStatus.entitled,
        source: AccessSource.none,
        role: AppRole.student,
        enforced: false,
        schemaMissing: true,
      );

  final AccessStatus status;
  final AccessSource source;

  /// The server-side role, which is the authority over [AppUser.role].
  final AppRole role;

  /// False on builds with no billing backend. Screens use it to suppress
  /// "included in your plan" copy that would otherwise be a lie.
  final bool enforced;

  /// True when Supabase answered but the billing schema is not installed —
  /// `access_state()` or `profiles` is missing, i.e. migration 0003 has not
  /// been run against this project.
  ///
  /// This case used to be indistinguishable from a network blip, which made it
  /// invisible: roles fell back to student, entitlement resolved to "unknown"
  /// (which grants access), and the app quietly behaved like the build that had
  /// no paywall at all. Nobody gets billed and nothing says why, so it is
  /// surfaced loudly instead.
  final bool schemaMissing;

  /// When the current trial or paid period runs out.
  final DateTime? validUntil;

  final String? schoolId;
  final String? schoolName;
  final String? tierId;
  final LicenseStatus licenseStatus;

  /// Seats the school has bought, and seats its roster actually consumes.
  final int seatsPurchased;
  final int seatsUsed;

  /// How many students a trial covers before payment is required.
  final int trialSeatCap;

  /// Parent-paid plan, when [source] is [AccessSource.parentSubscription].
  final String? planId;
  final int childrenCovered;

  /// How many children are linked to this parent account.
  final int childrenLinked;

  /// True when this came from the on-device cache rather than the server.
  final bool stale;

  bool get grantsAccess => status.grantsAccess;
  bool get isTrialing => status == AccessStatus.trialing;
  bool get needsPayment => status == AccessStatus.needsPayment;
  bool get needsSetup => status == AccessStatus.needsSetup;

  /// A director who signed up but has not created their school yet.
  bool get hasSchool => schoolId != null;

  /// Whole days left in the current period, floored at zero. Null when there
  /// is no period to count down.
  int? daysLeft({DateTime? now}) {
    final until = validUntil;
    if (until == null) return null;
    final diff = until.difference(now ?? DateTime.now()).inHours;
    return diff <= 0 ? 0 : (diff / 24).ceil();
  }

  /// Seats the school will actually be billed for: it cannot enrol 300
  /// students against 50 purchased seats and pay for 50.
  int get billableSeats =>
      seatsPurchased > seatsUsed ? seatsPurchased : seatsUsed;

  /// True when the roster has outgrown the trial's seat cap.
  bool get overTrialCap =>
      isTrialing && trialSeatCap > 0 && seatsUsed > trialSeatCap;

  AccessState copyWith({bool? stale}) => AccessState(
    status: status,
    source: source,
    role: role,
    enforced: enforced,
    schemaMissing: schemaMissing,
    validUntil: validUntil,
    schoolId: schoolId,
    schoolName: schoolName,
    tierId: tierId,
    licenseStatus: licenseStatus,
    seatsPurchased: seatsPurchased,
    seatsUsed: seatsUsed,
    trialSeatCap: trialSeatCap,
    planId: planId,
    childrenCovered: childrenCovered,
    childrenLinked: childrenLinked,
    stale: stale ?? this.stale,
  );

  static AccessStatus _statusFrom(String? value) =>
      switch (value?.trim().toLowerCase()) {
        'entitled' => AccessStatus.entitled,
        'trialing' => AccessStatus.trialing,
        'needs_payment' => AccessStatus.needsPayment,
        'needs_setup' => AccessStatus.needsSetup,
        _ => AccessStatus.unknown,
      };

  static int _intFrom(Object? value) => switch (value) {
    final num n => n.round(),
    final String s => int.tryParse(s.trim()) ?? 0,
    _ => 0,
  };

  factory AccessState.fromJson(Map<String, dynamic> json) {
    final until = json['valid_until'];
    return AccessState(
      status: _statusFrom(json['status'] as String?),
      source: AccessSource.fromWire(json['source'] as String?),
      role: AppRole.fromWire(json['role'] as String?),
      validUntil: until is String ? DateTime.tryParse(until)?.toLocal() : null,
      schoolId: json['school_id'] as String?,
      schoolName: json['school_name'] as String?,
      tierId: json['tier_id'] as String?,
      licenseStatus: LicenseStatus.fromWire(json['license_status'] as String?),
      seatsPurchased: _intFrom(json['seats_purchased']),
      seatsUsed: _intFrom(json['seats_used']),
      trialSeatCap: _intFrom(json['trial_seat_cap']),
      planId: json['plan_id'] as String?,
      childrenCovered: _intFrom(json['children_covered']),
      childrenLinked: _intFrom(json['children_linked']),
    );
  }

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'source': switch (source) {
      AccessSource.schoolLicense => 'school_license',
      AccessSource.parentSubscription => 'parent_subscription',
      AccessSource.none => 'none',
    },
    'role': role.wireName,
    'valid_until': validUntil?.toUtc().toIso8601String(),
    'school_id': schoolId,
    'school_name': schoolName,
    'tier_id': tierId,
    'license_status': switch (licenseStatus) {
      LicenseStatus.pastDue => 'past_due',
      final other => other.name,
    },
    'seats_purchased': seatsPurchased,
    'seats_used': seatsUsed,
    'trial_seat_cap': trialSeatCap,
    'plan_id': planId,
    'children_covered': childrenCovered,
    'children_linked': childrenLinked,
  };

  /// Rebuilds from [toJson], but with [status] recomputed against the clock:
  /// a cached "entitled" must not outlive the period it was entitled for.
  factory AccessState.fromCache(Map<String, dynamic> json, {DateTime? now}) {
    final restored = AccessState.fromJson({
      ...json,
      // fromJson expects the wire spelling for status.
      'status': switch (json['status']) {
        'needsPayment' => 'needs_payment',
        'needsSetup' => 'needs_setup',
        final other => other,
      },
    });
    final until = restored.validUntil;
    final lapsed =
        until != null && !until.isAfter(now ?? DateTime.now());
    return AccessState(
      status: lapsed ? AccessStatus.needsPayment : restored.status,
      source: restored.source,
      role: restored.role,
      validUntil: restored.validUntil,
      schoolId: restored.schoolId,
      schoolName: restored.schoolName,
      tierId: restored.tierId,
      licenseStatus: restored.licenseStatus,
      seatsPurchased: restored.seatsPurchased,
      seatsUsed: restored.seatsUsed,
      trialSeatCap: restored.trialSeatCap,
      planId: restored.planId,
      childrenCovered: restored.childrenCovered,
      childrenLinked: restored.childrenLinked,
      stale: true,
    );
  }

  @override
  List<Object?> get props => [
    status,
    source,
    role,
    enforced,
    schemaMissing,
    validUntil,
    schoolId,
    schoolName,
    tierId,
    licenseStatus,
    seatsPurchased,
    seatsUsed,
    trialSeatCap,
    planId,
    childrenCovered,
    childrenLinked,
    stale,
  ];
}
