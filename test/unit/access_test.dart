import 'package:eduai/features/access/domain/entities/access_state.dart';
import 'package:eduai/features/access/domain/entities/payment_quote.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccessState.fromJson', () {
    test('parses a school-licence answer', () {
      final state = AccessState.fromJson({
        'status': 'entitled',
        'source': 'school_license',
        'role': 'school_admin',
        'school_id': 's1',
        'school_name': 'Kigali Modern Academy',
        'tier_id': 'growth',
        'license_status': 'active',
        'seats_purchased': 150,
        'seats_used': 135,
        'trial_seat_cap': 50,
        'valid_until': '2026-09-01T00:00:00Z',
        'children_linked': 0,
      });

      expect(state.status, AccessStatus.entitled);
      expect(state.source, AccessSource.schoolLicense);
      expect(state.role, AppRole.schoolAdmin);
      expect(state.licenseStatus, LicenseStatus.active);
      expect(state.schoolName, 'Kigali Modern Academy');
      expect(state.hasSchool, isTrue);
      expect(state.grantsAccess, isTrue);
    });

    test('parses a parent subscription answer', () {
      final state = AccessState.fromJson({
        'status': 'entitled',
        'source': 'parent_subscription',
        'role': 'parent',
        'plan_id': 'family_monthly',
        'children_covered': 2,
        'children_linked': 2,
        'valid_until': '2026-09-01T00:00:00Z',
      });

      expect(state.source, AccessSource.parentSubscription);
      expect(state.role, AppRole.parent);
      expect(state.planId, 'family_monthly');
      expect(state.childrenCovered, 2);
      expect(state.hasSchool, isFalse);
    });

    test('an unrecognised status is unknown, never entitled', () {
      // A server that grows a new status must not accidentally hand out access.
      final state = AccessState.fromJson({
        'status': 'suspended_for_fraud',
        'source': 'none',
        'role': 'student',
      });
      expect(state.status, AccessStatus.unknown);
      expect(state.grantsAccess, isFalse);
    });

    test('an unrecognised role falls back to student', () {
      final state = AccessState.fromJson({
        'status': 'entitled',
        'source': 'none',
        'role': 'superintendent',
      });
      expect(state.role, AppRole.student);
    });

    test('needs_setup and needs_payment are distinct, and neither grants', () {
      for (final wire in ['needs_setup', 'needs_payment']) {
        final state = AccessState.fromJson({
          'status': wire,
          'source': 'none',
          'role': 'parent',
        });
        expect(state.grantsAccess, isFalse, reason: wire);
      }
      expect(
        AccessState.fromJson({
          'status': 'needs_setup',
          'source': 'none',
          'role': 'parent',
        }).needsSetup,
        isTrue,
      );
      expect(
        AccessState.fromJson({
          'status': 'needs_payment',
          'source': 'none',
          'role': 'parent',
        }).needsPayment,
        isTrue,
      );
    });
  });

  group('AccessState derived values', () {
    AccessState trial({
      required DateTime until,
      int seatsUsed = 10,
      int cap = 50,
    }) => AccessState(
      status: AccessStatus.trialing,
      source: AccessSource.schoolLicense,
      role: AppRole.schoolAdmin,
      licenseStatus: LicenseStatus.trialing,
      validUntil: until,
      seatsUsed: seatsUsed,
      trialSeatCap: cap,
    );

    test('counts whole days left and floors at zero', () {
      final now = DateTime(2026, 8, 14, 12);
      expect(
        trial(until: DateTime(2026, 8, 24, 12)).daysLeft(now: now),
        10,
      );
      // Part of a day still counts as a day — "0 days left" while access
      // remains would read as already expired.
      expect(trial(until: DateTime(2026, 8, 15)).daysLeft(now: now), 1);
      expect(trial(until: DateTime(2026, 8, 1)).daysLeft(now: now), 0);
    });

    test('has no countdown when there is no period', () {
      const state = AccessState(
        status: AccessStatus.needsSetup,
        source: AccessSource.none,
        role: AppRole.schoolAdmin,
      );
      expect(state.daysLeft(), isNull);
    });

    test('flags a roster that has outgrown the trial cap', () {
      final over = trial(until: DateTime(2030), seatsUsed: 51, cap: 50);
      expect(over.overTrialCap, isTrue);
      expect(trial(until: DateTime(2030), seatsUsed: 50).overTrialCap, isFalse);
    });

    test('only a trial can be over the trial cap', () {
      const paid = AccessState(
        status: AccessStatus.entitled,
        source: AccessSource.schoolLicense,
        role: AppRole.schoolAdmin,
        licenseStatus: LicenseStatus.active,
        seatsUsed: 900,
        trialSeatCap: 50,
      );
      expect(paid.overTrialCap, isFalse);
    });

    test('bills the larger of seats bought and seats in use', () {
      const underBought = AccessState(
        status: AccessStatus.entitled,
        source: AccessSource.schoolLicense,
        role: AppRole.schoolAdmin,
        seatsPurchased: 50,
        seatsUsed: 300,
      );
      // A school cannot enrol 300 students against 50 seats and pay for 50.
      expect(underBought.billableSeats, 300);

      const overBought = AccessState(
        status: AccessStatus.entitled,
        source: AccessSource.schoolLicense,
        role: AppRole.schoolAdmin,
        seatsPurchased: 500,
        seatsUsed: 300,
      );
      expect(overBought.billableSeats, 500);
    });
  });

  group('AccessState caching', () {
    test('round-trips through JSON', () {
      const state = AccessState(
        status: AccessStatus.entitled,
        source: AccessSource.parentSubscription,
        role: AppRole.parent,
        planId: 'family_termly',
        childrenCovered: 3,
        childrenLinked: 3,
      );
      final restored = AccessState.fromCache(state.toJson());
      expect(restored.source, AccessSource.parentSubscription);
      expect(restored.role, AppRole.parent);
      expect(restored.planId, 'family_termly');
      expect(restored.childrenCovered, 3);
    });

    test('a cached entitlement cannot outlive the period it was for', () {
      final state = AccessState(
        status: AccessStatus.entitled,
        source: AccessSource.schoolLicense,
        role: AppRole.student,
        licenseStatus: LicenseStatus.active,
        validUntil: DateTime(2026, 8, 1),
      );
      final restored = AccessState.fromCache(
        state.toJson(),
        now: DateTime(2026, 9, 1),
      );
      // Offline for a month past renewal is not a free month.
      expect(restored.status, AccessStatus.needsPayment);
      expect(restored.grantsAccess, isFalse);
      expect(restored.stale, isTrue);
    });

    test('a cached entitlement inside its period still grants access', () {
      final state = AccessState(
        status: AccessStatus.entitled,
        source: AccessSource.schoolLicense,
        role: AppRole.student,
        validUntil: DateTime(2026, 12, 1),
      );
      final restored = AccessState.fromCache(
        state.toJson(),
        now: DateTime(2026, 9, 1),
      );
      expect(restored.grantsAccess, isTrue);
      expect(restored.stale, isTrue);
    });

    test('past_due survives the wire spelling both ways', () {
      const state = AccessState(
        status: AccessStatus.needsPayment,
        source: AccessSource.schoolLicense,
        role: AppRole.schoolAdmin,
        licenseStatus: LicenseStatus.pastDue,
      );
      expect(state.toJson()['license_status'], 'past_due');
      expect(
        AccessState.fromCache(state.toJson()).licenseStatus,
        LicenseStatus.pastDue,
      );
    });
  });

  group('Unenforceable builds', () {
    test('open up, but never claim a plan was paid for', () {
      const state = AccessState.unconfigured();
      // No backend means entitlement cannot be checked; locking every screen
      // behind a paywall the build cannot satisfy would make it useless.
      expect(state.grantsAccess, isTrue);
      // And `enforced: false` is what stops the UI inventing a payer.
      expect(state.enforced, isFalse);
      expect(state.source, AccessSource.none);
    });

    test('the unknown state grants nothing and enforces', () {
      const state = AccessState.unknown();
      expect(state.status, AccessStatus.unknown);
      expect(state.grantsAccess, isFalse);
      expect(state.enforced, isTrue);
    });
  });

  group('Server-priced quotes', () {
    test('a licence quote carries the seats it was priced for', () {
      final quote = SchoolLicenseQuote.fromJson({
        'school_id': 's1',
        'tier_id': 'growth',
        'tier_name': 'Growth',
        'seats': 150,
        'seats_used': 135,
        'price_per_seat_rwf': 1500,
        'amount_rwf': 225000,
        'period_days': 30,
      });
      expect(quote.amountRwf, 225000);
      expect(quote.seats, 150);
      expect(quote.seatsUsed, 135);
    });

    test('a family quote prices per linked child', () {
      final quote = ParentPlanQuote.fromJson({
        'plan_id': 'family_monthly',
        'plan_name': 'Family — monthly',
        'children': 2,
        'price_per_child_rwf': 3000,
        'amount_rwf': 6000,
        'period_days': 30,
      });
      expect(quote.children, 2);
      expect(quote.amountRwf, 6000);
    });

    test('a plan option labels its period from the day count', () {
      const monthly = ParentPlanOption(
        id: 'm',
        name: 'Monthly',
        pricePerChildRwf: 3000,
        periodDays: 30,
        features: [],
      );
      const termly = ParentPlanOption(
        id: 't',
        name: 'Termly',
        pricePerChildRwf: 7500,
        periodDays: 90,
        features: [],
      );
      const yearly = ParentPlanOption(
        id: 'y',
        name: 'Yearly',
        pricePerChildRwf: 25000,
        periodDays: 365,
        features: [],
      );
      expect(monthly.periodLabel, 'per child / month');
      expect(termly.periodLabel, 'per child / term');
      expect(yearly.periodLabel, 'per child / year');
    });
  });

}
