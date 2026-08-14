import 'package:eduai/core/platform/app_platform_style.dart';
import 'package:eduai/features/access/domain/entities/access_state.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/linking/domain/entities/family_link.dart';
import 'package:eduai/features/payments/application/momo_payment_controller.dart';
import 'package:eduai/features/payments/domain/entities/momo_payment.dart';
import 'package:eduai/features/schools/domain/join_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const _adminSession = AuthSession(
  user: AppUser(id: 'a1', displayName: 'Bursar', role: AppRole.schoolAdmin),
  provider: AuthProvider.supabaseEmail,
);

/// A school on a paid licence: 135 students enrolled against 150 seats bought.
AccessState _activeLicense({
  int seatsUsed = 135,
  int seatsPurchased = 150,
  LicenseStatus status = LicenseStatus.active,
  AccessStatus access = AccessStatus.entitled,
}) => AccessState(
  status: access,
  source: AccessSource.schoolLicense,
  role: AppRole.schoolAdmin,
  schoolId: 's1',
  schoolName: 'Kigali Modern Academy',
  tierId: 'growth',
  licenseStatus: status,
  seatsUsed: seatsUsed,
  seatsPurchased: seatsPurchased,
  trialSeatCap: 50,
  validUntil: DateTime(2026, 9),
);

/// The state a brand-new director is in: signed up, no school yet.
const _noSchool = AccessState(
  status: AccessStatus.needsSetup,
  source: AccessSource.none,
  role: AppRole.schoolAdmin,
);

final _roster = [
  const RosterEntry(
    studentId: 'st1',
    studentName: 'Alice K.',
    parentsLinked: 1,
    invitePending: false,
    className: 'Primary 6 — English',
  ),
  const RosterEntry(
    studentId: 'st2',
    studentName: 'Jean P.',
    parentsLinked: 0,
    invitePending: false,
    className: 'Primary 5 — Mathematics',
  ),
  const RosterEntry(
    studentId: 'st3',
    studentName: 'Chantal M.',
    parentsLinked: 0,
    invitePending: true,
    className: 'Primary 4 — All subjects',
  ),
];

Future<AppUnderTest> pumpAdmin(
  WidgetTester tester, {
  AppPlatformStyle platform = AppPlatformStyle.android,
  Size size = desktopSize,
  AccessState? access,
  List<RosterEntry>? roster,
  FakeSchoolsRepository? schools,
}) {
  return pumpApp(
    tester,
    auth: FakeAuthRepository(initialSession: _adminSession),
    access: FakeAccessRepository(state: access ?? _activeLicense()),
    linking: FakeLinkingRepository(roster: roster ?? _roster),
    schools: schools,
    platform: platform,
    size: size,
  );
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Drags the People list until [finder] is built.
///
/// The roster sits below the seats, classes and teachers cards, and a ListView
/// only builds what is near the viewport. `scrollUntilVisible` cannot be used:
/// the shell nests more than one Scrollable, so it cannot pick one.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  final list = find.byType(ListView).last;
  for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Admin licence', () {
    testWidgets('states the school, plan, cost and renewal up front', (
      tester,
    ) async {
      await pumpAdmin(tester);

      expect(find.text('Kigali Modern Academy'), findsWidgets);
      expect(find.text('Growth'), findsWidgets);
      // 1,500 RWF per seat × 150 seats bought (more than the 135 in use).
      expect(find.text('225,000 RWF'), findsWidgets);
      expect(find.text('1 Sep 2026'), findsOneWidget);
      expect(find.text('Seats used'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('a director with no school is asked to create one', (
      tester,
    ) async {
      await pumpAdmin(tester, access: _noSchool);

      expect(find.text('Create your school'), findsOneWidget);
      expect(find.byKey(const Key('create-school-cta')), findsOneWidget);
      // Nothing to bill yet, so no seat or payment card is shown.
      expect(find.text('Seats used'), findsNothing);
      expect(find.byKey(const Key('pay-license-button')), findsNothing);
    });

    testWidgets('offers a MoMo payment priced by the server', (tester) async {
      await pumpAdmin(tester);

      expect(find.byKey(const Key('pay-license-button')), findsOneWidget);
      expect(
        find.textContaining('150 students × 1,500 RWF = 225,000 RWF'),
        findsOneWidget,
      );
    });

    testWidgets('a settled payment is recorded against its MTN reference', (
      tester,
    ) async {
      final payments = FakePaymentsRepository(reference: 'ref-license-1');
      // Only the gateway repository is faked, so this drives the real payment
      // controller: payNow → poll → settle.
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _adminSession),
        access: FakeAccessRepository(state: _activeLicense()),
        linking: FakeLinkingRepository(roster: _roster),
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );

      await tester.tap(find.byKey(const Key('pay-license-button')));
      await tester.pumpAndSettle();
      // A bursar account has no phone number on file, so the sheet starts
      // empty and the number is typed in.
      await tester.enterText(
        find.byKey(const Key('momo-phone-field')),
        '0788123456',
      );
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(payments.lastAmount, 225000);
      expect(app.access.settledReferences, ['ref-license-1']);
      expect(app.access.lastAmountRwf, 225000);
      expect(find.textContaining('Licence active'), findsOneWidget);
    });

    testWidgets('a rejected payment activates nothing', (tester) async {
      final payments = FakePaymentsRepository(
        statuses: [MomoPaymentStatus.failed],
      );
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _adminSession),
        access: FakeAccessRepository(state: _activeLicense()),
        linking: FakeLinkingRepository(roster: _roster),
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );

      await tester.tap(find.byKey(const Key('pay-license-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('momo-phone-field')),
        '0788123456',
      );
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(find.text('Payment not completed'), findsOneWidget);
      expect(app.access.settledReferences, isEmpty);
    });

    testWidgets('marks the current tier and offers the others', (tester) async {
      await pumpAdmin(tester);

      expect(find.text('CURRENT'), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Current plan'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('switch-tier-starter')), findsOneWidget);
      expect(find.byKey(const Key('switch-tier-district')), findsOneWidget);
    });

    testWidgets('cannot switch tier before a school exists', (tester) async {
      await pumpAdmin(tester, access: _noSchool);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('switch-tier-growth')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a trial says how long is left and how to keep going', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        access: _activeLicense(
          status: LicenseStatus.trialing,
          access: AccessStatus.trialing,
        ),
      );

      expect(find.text('TRIAL'), findsOneWidget);
      expect(find.text('Trial ends'), findsOneWidget);
      expect(find.byKey(const Key('access-notice')), findsOneWidget);
      expect(find.text('Activate now'), findsOneWidget);
    });

    testWidgets('an unpaid licence says so and still offers the way out', (
      tester,
    ) async {
      await pumpAdmin(
        tester,
        access: _activeLicense(
          status: LicenseStatus.expired,
          access: AccessStatus.needsPayment,
        ),
      );

      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.byKey(const Key('access-notice')), findsOneWidget);
      expect(find.byKey(const Key('pay-license-button')), findsOneWidget);
    });

    testWidgets('lays out on a phone-sized window', (tester) async {
      await pumpAdmin(tester, size: mobileSize);
      expect(tester.takeException(), isNull);
    });
  });

  group('Admin people', () {
    testWidgets('lists the roster with each student’s parent state', (
      tester,
    ) async {
      await pumpAdmin(tester);
      await openTab(tester, 'People');

      expect(find.text('3 ENROLLED'), findsOneWidget);
      await scrollTo(tester, find.text('Chantal M.'));

      expect(find.text('Alice K.'), findsOneWidget);
      expect(find.text('Primary 6 — English'), findsOneWidget);
      // Alice has a parent, Chantal has an open invite, Jean has neither.
      expect(find.text('PARENT LINKED'), findsOneWidget);
      expect(find.text('INVITED'), findsOneWidget);
      expect(find.byKey(const Key('invite-parent-st2')), findsOneWidget);
      expect(find.byKey(const Key('invite-parent-st1')), findsNothing);
    });

    testWidgets('inviting a parent hands the admin a code to pass on', (
      tester,
    ) async {
      final app = await pumpAdmin(tester);
      await openTab(tester, 'People');

      await scrollTo(tester, find.byKey(const Key('invite-parent-st2')));
      await tester.tap(find.byKey(const Key('invite-parent-st2')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('invite-parent-contact')),
        '0788123456',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create code'));
      await tester.pumpAndSettle();

      expect(app.linking.lastInvitedStudentId, 'st2');
      expect(find.byKey(const Key('parent-invite-code')), findsOneWidget);
      expect(find.text('CODE1'), findsOneWidget);
      expect(find.textContaining('sign up as a parent'), findsOneWidget);
    });

    testWidgets('shows seats bought against seats in use', (tester) async {
      await pumpAdmin(tester);
      await openTab(tester, 'People');

      expect(find.text('Seats bought'), findsOneWidget);
      expect(find.text('135 of 150 in use'), findsOneWidget);
      expect(find.byKey(const Key('seats-purchased-value')), findsOneWidget);
    });

    testWidgets('the stepper buys seats in fives', (tester) async {
      final app = await pumpAdmin(tester);
      await openTab(tester, 'People');

      await tester.tap(find.byKey(const Key('seats-plus')));
      await tester.pumpAndSettle();
      expect(app.access.lastSeats, 155);

      await tester.tap(find.byKey(const Key('seats-minus')));
      await tester.pumpAndSettle();
      expect(app.access.lastSeats, 145);
    });

    // The empty-roster copy is asserted in "A paid director can actually run
    // the school", which also checks it no longer points at an unreachable page.

    testWidgets('no school means no roster to show', (tester) async {
      await pumpAdmin(tester, access: _noSchool);
      await openTab(tester, 'People');

      expect(find.text('No school yet'), findsOneWidget);
    });
  });

  group('A paid director can actually run the school', () {
    testWidgets('classes and their join codes are on the People tab', (
      tester,
    ) async {
      // The blocker this fixes: every route into the school pages ran through
      // the *student* shell, so a director who had paid had no way to create a
      // class — and the roster's empty state pointed at a page they could not
      // open.
      await pumpAdmin(tester);
      await openTab(tester, 'People');

      expect(find.text('Classes'), findsOneWidget);
      expect(find.byKey(const Key('admin-add-class')), findsOneWidget);
      // The code is the thing an admin has to hand out, so it is readable
      // rather than hidden behind a tap.
      expect(find.byKey(const Key('class-code-c2')), findsOneWidget);
      expect(find.text('ENG6'), findsOneWidget);
    });

    testWidgets('a class with no code says so instead of showing a blank', (
      tester,
    ) async {
      await pumpAdmin(tester);
      await openTab(tester, 'People');
      // Seeded class c1 has no join code.
      expect(find.text('No code'), findsWidgets);
    });

    testWidgets('adding a class suggests an unambiguous code', (tester) async {
      final schools = FakeSchoolsRepository();
      await pumpAdmin(tester, schools: schools);
      await openTab(tester, 'People');

      await tester.tap(find.byKey(const Key('admin-add-class')));
      await tester.pumpAndSettle();
      expect(find.text('Add a class'), findsOneWidget);

      // Pre-filled, because a class with no code cannot be joined and nothing
      // would tell the admin why.
      final field = tester.widget<TextField>(
        find.byKey(const Key('class-join-code-field')),
      );
      final suggested = field.controller!.text;
      expect(suggested, isNotEmpty);
      expect(JoinCode.isUnambiguous(suggested), isTrue);

      await tester.enterText(find.byType(TextField).first, 'P4 — Science');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('P4 — Science'), findsWidgets);
    });

    testWidgets('the empty roster points at the codes above it', (
      tester,
    ) async {
      await pumpAdmin(tester, roster: const []);
      await openTab(tester, 'People');

      expect(find.text('No students enrolled yet'), findsOneWidget);
      // No longer names a page the admin shell cannot reach.
      expect(find.textContaining('on the school page'), findsNothing);
      expect(
        find.textContaining('Share a class join code from the Classes card'),
        findsOneWidget,
      );
    });
  });

  group('Admin invoices', () {
    testWidgets('says plainly when nothing has been paid', (tester) async {
      await pumpAdmin(tester);
      await openTab(tester, 'Invoices');

      // The ledger is empty until a real MoMo reference settles — it no longer
      // invents three "Paid" rows.
      expect(find.text('No payments yet'), findsOneWidget);
      expect(find.textContaining('MTN reference'), findsOneWidget);
    });
  });

  group('Admin usage', () {
    testWidgets('frames the numbers for a renewal conversation', (
      tester,
    ) async {
      await pumpAdmin(tester);
      await openTab(tester, 'Usage');

      expect(find.text('87%'), findsOneWidget);
      expect(find.text('4.2'), findsOneWidget);
      expect(find.text('+23%'), findsOneWidget);
      expect(
        find.textContaining('Most-practised subject this month'),
        findsOneWidget,
      );
      expect(
        find.textContaining('share it with your school board'),
        findsOneWidget,
      );
    });
  });

  group('Admin chrome', () {
    for (final platform in AppPlatformStyle.values) {
      testWidgets('renders on ${platform.name}', (tester) async {
        await pumpAdmin(tester, platform: platform);
        expect(tester.takeException(), isNull);
        expect(find.text('Seats used'), findsOneWidget);
      });
    }
  });
}
