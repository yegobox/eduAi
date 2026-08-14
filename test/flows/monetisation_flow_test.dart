import 'package:eduai/features/access/domain/entities/access_state.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/linking/domain/entities/family_link.dart';
import 'package:eduai/features/payments/application/momo_payment_controller.dart';
import 'package:eduai/features/payments/domain/entities/momo_payment.dart';
import 'package:eduai/features/schools/application/schools_action_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

/// End-to-end coverage of the three questions this app has to answer to make
/// money: who is signing in, who is paying, and what happens when nobody has.
/// Opens the family-links page the way a parent actually reaches it: the More
/// menu, which is where linking lives for both the parent and student shells.
Future<void> openFamilyPage(WidgetTester tester) async {
  // The overflow button is an icon on every platform chrome, labelled only for
  // screen readers — so it is found by its semantics, not by visible text.
  await tester.tap(find.bySemanticsLabel('More').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('My children'));
  await tester.pumpAndSettle();
}

void main() {
  const studentSession = AuthSession(
    user: AppUser(id: 'u1', displayName: 'Mura'),
    provider: AuthProvider.supabaseEmail,
  );
  const parentSession = AuthSession(
    user: AppUser(
      id: 'p1',
      displayName: 'Parent',
      phoneNumber: '+250788123456',
      role: AppRole.parent,
    ),
    provider: AuthProvider.supabaseEmail,
  );

  AccessState state(
    AccessStatus status, {
    AppRole role = AppRole.student,
    AccessSource source = AccessSource.none,
    String? schoolName,
    int childrenLinked = 0,
    DateTime? validUntil,
  }) => AccessState(
    status: status,
    source: source,
    role: role,
    schoolId: schoolName == null ? null : 's1',
    schoolName: schoolName,
    childrenLinked: childrenLinked,
    validUntil: validUntil,
  );

  group('Signing up picks a product surface', () {
    testWidgets('the role reaches the repository instead of defaulting', (
      tester,
    ) async {
      final app = await pumpApp(tester);

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      // Student is the default because it is the common case…
      expect(find.byKey(const Key('signup-role-student')), findsOneWidget);
      // …but a director can say so, which is what used to be impossible.
      await tester.tap(find.byKey(const Key('signup-role-school_admin')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'director@school.rw',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create account & start trial'),
      );
      await tester.pumpAndSettle();

      expect(app.auth.lastSignUpRole, AppRole.schoolAdmin);
      expect(
        find.textContaining('create your school to start a 30-day trial'),
        findsOneWidget,
      );
    });

    testWidgets('each role is told what happens next', (tester) async {
      final app = await pumpApp(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('signup-role-parent')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'mum@example.rw',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(app.auth.lastSignUpRole, AppRole.parent);
      expect(
        find.textContaining('link your child with a code'),
        findsOneWidget,
      );
    });
  });

  group('An unpaid student keeps their work', () {
    testWidgets('the AI Tutor locks, with a reason and a next step', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.needsPayment,
            source: AccessSource.schoolLicense,
            schoolName: 'Kigali Modern Academy',
          ),
        ),
      );

      await tester.tap(find.text('Tutor').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('is paused for now'), findsOneWidget);
      expect(
        find.textContaining("Kigali Modern Academy's EduAI licence has lapsed"),
        findsOneWidget,
      );
      // A student cannot pay their school's invoice, so they are not given a
      // button that pretends they can.
      expect(find.byKey(const Key('access-gate-action')), findsNothing);
    });

    testWidgets('lessons and progress stay open while the tutor is locked', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.needsPayment,
            source: AccessSource.schoolLicense,
            schoolName: 'Kigali Modern Academy',
          ),
        ),
      );

      await tester.tap(find.text('Lessons').last);
      await tester.pumpAndSettle();
      // Holding a child's completed work hostage over their school's invoice
      // is not a collections strategy.
      expect(find.textContaining('is paused for now'), findsNothing);

      await tester.tap(find.text('Progress').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('is paused for now'), findsNothing);
    });

    testWidgets('the workbook still writes, only its AI check waits', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.needsPayment,
            source: AccessSource.schoolLicense,
            schoolName: 'Kigali Modern Academy',
          ),
        ),
      );

      await tester.tap(find.text('Workbook').last);
      await tester.pumpAndSettle();

      expect(find.text('Workbook'), findsWidgets);
      expect(
        find.widgetWithText(FilledButton, 'Ask AI to check my work'),
        findsNothing,
      );
      expect(
        find.textContaining('AI checking is paused until the licence is paid'),
        findsOneWidget,
      );
    });

    testWidgets('a student with no school is pointed at a join code', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
        access: FakeAccessRepository(state: state(AccessStatus.needsSetup)),
      );

      await tester.tap(find.text('Tutor').last);
      await tester.pumpAndSettle();

      // The panel names the feature and folds the reason into one heading:
      // "The AI Tutor — join your school to unlock this".
      expect(
        find.textContaining('join your school to unlock this'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('access-gate-action')), findsOneWidget);
    });

    testWidgets('a paid student sees no notice and no lock', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.entitled,
            source: AccessSource.schoolLicense,
            schoolName: 'Kigali Modern Academy',
          ),
        ),
      );

      expect(find.byKey(const Key('access-notice')), findsNothing);
      await tester.tap(find.text('Tutor').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('is paused for now'), findsNothing);
    });

    testWidgets('a trial says how long is left without locking anything', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.trialing,
            source: AccessSource.schoolLicense,
            schoolName: 'Kigali Modern Academy',
            validUntil: DateTime.now().add(const Duration(days: 12)),
          ),
        ),
      );

      expect(find.byKey(const Key('access-notice')), findsOneWidget);
      expect(find.textContaining('12 days left'), findsOneWidget);

      await tester.tap(find.text('Tutor').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('is paused for now'), findsNothing);
    });
  });

  group('A parent pays directly when no school does', () {
    testWidgets('a parent with no child linked is asked to link first', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(AccessStatus.needsSetup, role: AppRole.parent),
        ),
      );

      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();

      // Plans are priced per child, so there is nothing to quote yet.
      expect(find.text('Link a child first'), findsOneWidget);
      expect(find.byKey(const Key('plan-link-child')), findsOneWidget);
      expect(find.byKey(const Key('subscribe-family_monthly')), findsNothing);
    });

    testWidgets('a linked-but-uncovered parent is offered a family plan', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.needsPayment,
            role: AppRole.parent,
            childrenLinked: 2,
          ),
        ),
      );

      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();

      expect(find.text('Choose a family plan'), findsOneWidget);
      expect(find.textContaining('you have 2 linked'), findsOneWidget);
      // 3,000 RWF per child × 2 children.
      expect(find.textContaining('You pay 6,000 RWF today'), findsOneWidget);
      expect(find.byKey(const Key('subscribe-family_monthly')), findsOneWidget);
      // Top-ups are not offered to a family with no access at all.
      expect(find.byKey(const Key('topup-small')), findsNothing);
    });

    testWidgets('a settled family payment is recorded server-side', (
      tester,
    ) async {
      final payments = FakePaymentsRepository(reference: 'ref-family-9');
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.needsPayment,
            role: AppRole.parent,
            childrenLinked: 2,
          ),
        ),
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );

      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('subscribe-family_monthly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(payments.lastAmount, 6000);
      expect(app.access.settledReferences, ['ref-family-9']);
      expect(app.access.lastPlanId, 'family_monthly');
      expect(app.access.lastAmountRwf, 6000);
    });

    testWidgets('a rejected family payment grants nothing', (tester) async {
      final payments = FakePaymentsRepository(
        statuses: [MomoPaymentStatus.failed],
      );
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.needsPayment,
            role: AppRole.parent,
            childrenLinked: 1,
          ),
        ),
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );

      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('subscribe-family_monthly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(find.text('Payment not completed'), findsOneWidget);
      expect(app.access.settledReferences, isEmpty);
    });

    testWidgets('a parent covered by a school is never shown a paywall', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.entitled,
            role: AppRole.parent,
            source: AccessSource.schoolLicense,
            schoolName: 'Kigali Modern Academy',
            childrenLinked: 1,
          ),
        ),
      );

      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining("Included in Kigali Modern Academy's EduAI plan"),
        findsOneWidget,
      );
      expect(find.text('Choose a family plan'), findsNothing);
      expect(find.byKey(const Key('subscribe-family_monthly')), findsNothing);
      // Access is paid for, so the optional extras are on offer.
      expect(find.byKey(const Key('topup-small')), findsOneWidget);
    });
  });

  group('Linking a family, from either side', () {
    testWidgets('a parent redeems the code their school gave them', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(AccessStatus.needsSetup, role: AppRole.parent),
        ),
      );

      await openFamilyPage(tester);

      expect(find.text('My children'), findsWidgets);
      await tester.enterText(
        find.byKey(const Key('redeem-code-field')),
        'k4mpq7a',
      );
      await tester.tap(find.byKey(const Key('redeem-code-button')));
      await tester.pumpAndSettle();

      // Codes are case-insensitive to type but canonical on the wire.
      expect(app.linking.lastRedeemedCode, 'K4MPQ7A');
      expect(find.textContaining('Linked'), findsWidgets);
    });

    testWidgets('a parent mints a code for their own child', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(AccessStatus.needsSetup, role: AppRole.parent),
        ),
      );

      await openFamilyPage(tester);

      await tester.tap(find.byKey(const Key('invite-child-button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('generated-invite-code')), findsOneWidget);
      expect(find.text('CODE1'), findsWidgets);
    });

    testWidgets('a bad code is rejected with the server’s own wording', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(AccessStatus.needsSetup, role: AppRole.parent),
        ),
        linking: FakeLinkingRepository(),
      );

      await openFamilyPage(tester);
      await tester.enterText(find.byKey(const Key('redeem-code-field')), 'AB');
      await tester.tap(find.byKey(const Key('redeem-code-button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter the full code.'), findsOneWidget);
    });

    testWidgets('a linked parent sees the child and can unlink', (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: state(
            AccessStatus.entitled,
            role: AppRole.parent,
            source: AccessSource.schoolLicense,
            schoolName: 'Kigali Modern Academy',
            childrenLinked: 1,
          ),
        ),
        linking: FakeLinkingRepository(
          links: [
            const FamilyLink(
              id: 'l1',
              parentId: 'p1',
              studentId: 'st1',
              createdBySchool: true,
              displayName: 'Alice K.',
            ),
          ],
        ),
      );

      await openFamilyPage(tester);

      expect(find.text('Alice K.'), findsWidgets);
      expect(find.text('Linked by the school'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(app.linking.links, isEmpty);
    });
  });

  _regressions();
}

/// Regressions for the three things that went wrong on first real use:
/// a school account could join another school, a director never saw the
/// create-school step or the payment gate, and a missing migration looked
/// exactly like a working app.
void _regressions() {
  const adminSession = AuthSession(
    user: AppUser(id: 'a1', displayName: 'Director', role: AppRole.schoolAdmin),
    provider: AuthProvider.supabaseEmail,
  );
  const parentSession = AuthSession(
    user: AppUser(id: 'p1', displayName: 'Parent', role: AppRole.parent),
    provider: AuthProvider.supabaseEmail,
  );
  const studentSession = AuthSession(
    user: AppUser(id: 'u1', displayName: 'Mura'),
    provider: AuthProvider.supabaseEmail,
  );

  const noSchool = AccessState(
    status: AccessStatus.needsSetup,
    source: AccessSource.none,
    role: AppRole.schoolAdmin,
  );

  /// A school with a roster, so there is something real to bill.
  const paidSchool = AccessState(
    status: AccessStatus.trialing,
    source: AccessSource.schoolLicense,
    role: AppRole.schoolAdmin,
    schoolId: 's1',
    schoolName: 'DemoSchool',
    tierId: 'growth',
    licenseStatus: LicenseStatus.trialing,
    seatsUsed: 10,
    seatsPurchased: 10,
  );

  group('A school account cannot enrol as a student', () {
    testWidgets('the catalog offers no join affordances to a director', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: noSchool),
      );

      // Reachable from the admin shell's More menu → the catalog is browsable,
      // but it must not invite a director to take a seat somewhere.
      await tester.tap(find.bySemanticsLabel('More').last);
      await tester.pumpAndSettle();
      expect(find.text('My children'), findsNothing);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
    });

    testWidgets('joining is refused for a school account', (tester) async {
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: noSchool),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final result = await container
          .read(schoolsActionControllerProvider.notifier)
          .joinSchool('s1');

      expect(result.isFailure, isTrue);
      expect(
        result.failureOrNull?.message,
        contains('cannot enrol as a student'),
      );
      // And it never reached the repository, so no seat was taken.
      expect(app.schools.joinCalls, 0);
    });

    testWidgets('joining by code is refused too', (tester) async {
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: noSchool),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      // Every enrolment path funnels through one guard, so a second door in
      // cannot bypass it.
      expect(
        (await container
                .read(schoolsActionControllerProvider.notifier)
                .joinByCode('GHS24'))
            .isFailure,
        isTrue,
      );
      expect(
        (await container
                .read(schoolsActionControllerProvider.notifier)
                .joinClass(schoolId: 's1', classId: 'c1'))
            .isFailure,
        isTrue,
      );
      expect(app.schools.joinCalls, 0);
    });

    testWidgets('a parent account cannot enrol either', (tester) async {
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.needsSetup,
            source: AccessSource.none,
            role: AppRole.parent,
          ),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      final result = await container
          .read(schoolsActionControllerProvider.notifier)
          .joinSchool('s1');
      expect(result.failureOrNull?.message, contains('do not join schools'));
      expect(app.schools.joinCalls, 0);
    });

    testWidgets('a student still enrols normally', (tester) async {
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      final result = await container
          .read(schoolsActionControllerProvider.notifier)
          .joinSchool('s1');
      expect(result.isSuccess, isTrue);
      expect(app.schools.joinCalls, 1);
    });
  });

  group('A director is shown the way to create a school', () {
    testWidgets('the create step and the plans are both on the Licence tab', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: noSchool),
      );

      // This is the landing tab for a school_admin, so the very first thing a
      // freshly signed-up director sees is the step that starts their trial.
      expect(find.byKey(const Key('create-school-cta')), findsOneWidget);
      expect(find.text('Create your school'), findsOneWidget);
      expect(find.textContaining('30-day trial'), findsWidgets);
      // The prices are visible before committing to anything.
      expect(find.text('Plans'), findsOneWidget);
      // No banner here: the card itself already says a trial starts on
      // creation, so a notice repeating it would just be noise.
      expect(find.byKey(const Key('access-notice')), findsNothing);
      // Nothing to pay for until the school exists.
      expect(find.byKey(const Key('pay-license-button')), findsNothing);
    });

    testWidgets('the payment gate appears once the school exists', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.trialing,
            source: AccessSource.schoolLicense,
            role: AppRole.schoolAdmin,
            schoolId: 's1',
            schoolName: 'Kigali Modern',
            tierId: 'growth',
            licenseStatus: LicenseStatus.trialing,
            seatsUsed: 10,
            seatsPurchased: 10,
          ),
        ),
      );

      expect(find.byKey(const Key('create-school-cta')), findsNothing);
      expect(find.byKey(const Key('pay-license-button')), findsOneWidget);
      expect(find.text('Activate now'), findsOneWidget);
    });
  });

  group('A missing migration is never silent', () {
    testWidgets('it says what is wrong and how to fix it', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
        access: FakeAccessRepository(state: const AccessState.schemaMissing()),
      );

      // Without this, roles fall back to student and entitlement resolves to a
      // state that grants access — the app looks fine while charging nobody.
      expect(find.byKey(const Key('access-schema-missing')), findsOneWidget);
      expect(find.textContaining('Billing is not installed'), findsOneWidget);
      expect(find.textContaining('migration 0003'), findsOneWidget);
    });

    testWidgets('a properly configured build shows no such warning', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: studentSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.entitled,
            source: AccessSource.schoolLicense,
            role: AppRole.student,
            schoolId: 's1',
            schoolName: 'Kigali Modern',
          ),
        ),
      );
      expect(find.byKey(const Key('access-schema-missing')), findsNothing);
    });
  });

  group('Paying by MoMo when the account signed up with an email', () {
    testWidgets('the sheet asks for a number instead of blocking', (
      tester,
    ) async {
      // A bursar who signed up with an email has no phone on their identity —
      // that must not stop them paying, it just means the field starts empty.
      final payments = FakePaymentsRepository(reference: 'ref-email-1');
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: paidSchool),
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );

      await tester.tap(find.byKey(const Key('pay-license-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('momo-phone-field')),
      );
      expect(field.controller?.text, isEmpty);

      await tester.enterText(
        find.byKey(const Key('momo-phone-field')),
        '0788123456',
      );
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(payments.initiateCalls, 1);
      expect(app.access.settledReferences, ['ref-email-1']);
      // And the number is remembered, so next month it is pre-filled.
      expect(app.auth.rememberedPayerPhone, '0788123456');
    });

    testWidgets('a number already on the account is pre-filled', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(
          initialSession: const AuthSession(
            user: AppUser(
              id: 'a2',
              displayName: 'Bursar',
              phoneNumber: '+250788999888',
              role: AppRole.schoolAdmin,
            ),
            provider: AuthProvider.supabaseEmail,
          ),
        ),
        access: FakeAccessRepository(state: paidSchool),
      );

      await tester.tap(find.byKey(const Key('pay-license-button')));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('momo-phone-field')),
      );
      expect(field.controller?.text, '0788999888');
    });

    testWidgets('a failed payment remembers nothing', (tester) async {
      final payments = FakePaymentsRepository(
        statuses: [MomoPaymentStatus.failed],
      );
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: paidSchool),
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

      expect(app.auth.rememberedPayerPhone, isNull);
    });
  });

  group('An empty roster is not billed for a phantom student', () {
    testWidgets('it asks for students or seats instead of quoting one', (
      tester,
    ) async {
      // The server floors a quote at one seat so it never asks for 0 RWF, but
      // "1 students x 1,500 RWF" against an empty roster invents a student.
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.trialing,
            source: AccessSource.schoolLicense,
            role: AppRole.schoolAdmin,
            schoolId: 's1',
            schoolName: 'DemoSchool',
            tierId: 'growth',
            licenseStatus: LicenseStatus.trialing,
            seatsUsed: 0,
            seatsPurchased: 0,
          ),
        ),
      );

      expect(find.text('Nothing to pay yet'), findsOneWidget);
      expect(find.textContaining('Your roster is empty'), findsOneWidget);
      expect(find.textContaining('students ×'), findsNothing);
      expect(find.textContaining('student ×'), findsNothing);
      // No payment button, and no invented monthly cost in the header.
      expect(find.byKey(const Key('pay-license-button')), findsNothing);
      expect(find.text('1,500 RWF'), findsNothing);
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('seats bought up front are billable with an empty roster', (
      tester,
    ) async {
      // A school that buys 50 seats before enrolling anyone is a real case.
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.trialing,
            source: AccessSource.schoolLicense,
            role: AppRole.schoolAdmin,
            schoolId: 's1',
            schoolName: 'DemoSchool',
            tierId: 'growth',
            licenseStatus: LicenseStatus.trialing,
            seatsUsed: 0,
            seatsPurchased: 50,
          ),
        ),
      );

      expect(find.text('Nothing to pay yet'), findsNothing);
      expect(find.byKey(const Key('pay-license-button')), findsOneWidget);
      expect(find.textContaining('50 students ×'), findsOneWidget);
    });

    testWidgets('a single seat reads as one student, not "1 students"', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.trialing,
            source: AccessSource.schoolLicense,
            role: AppRole.schoolAdmin,
            schoolId: 's1',
            schoolName: 'DemoSchool',
            tierId: 'growth',
            licenseStatus: LicenseStatus.trialing,
            seatsUsed: 1,
            seatsPurchased: 1,
          ),
        ),
      );
      expect(find.textContaining('1 student ×'), findsOneWidget);
    });
  });

  group('Test pricing charges a small real amount', () {
    testWidgets('the licence card shows the real price and the test charge', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: paidSchool, testPricing: true),
      );

      // The breakdown still states what the licence really costs…
      expect(find.textContaining('10 students × 1,500 RWF = 15,000 RWF'),
          findsOneWidget);
      // …and the warning states what will actually be taken.
      expect(find.byKey(const Key('test-pricing-warning')), findsOneWidget);
      expect(
        find.textContaining('charged 100 RWF instead of 15,000 RWF'),
        findsOneWidget,
      );
      expect(find.textContaining('disable_test_pricing'), findsOneWidget);
    });

    testWidgets('the gateway is asked for the test amount, not the list price', (
      tester,
    ) async {
      final payments = FakePaymentsRepository(reference: 'ref-test-1');
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: paidSchool, testPricing: true),
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

      // 100 RWF really leaves the payer's wallet…
      expect(payments.lastAmount, 100);
      // …and settlement is told the same figure, so the server's own
      // recomputation agrees and a full period is granted. This is the whole
      // reason the override lives in the quote and not in the client: a client
      // that paid 100 against a 15,000 quote would be recorded as `disputed`.
      expect(app.access.lastAmountRwf, 100);
      expect(app.access.settledReferences, ['ref-test-1']);
      expect(find.textContaining('Licence active'), findsOneWidget);
    });

    testWidgets('no warning and full pricing when the override is off', (
      tester,
    ) async {
      final payments = FakePaymentsRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: adminSession),
        access: FakeAccessRepository(state: paidSchool),
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );

      expect(find.byKey(const Key('test-pricing-warning')), findsNothing);

      await tester.tap(find.byKey(const Key('pay-license-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('momo-phone-field')),
        '0788123456',
      );
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(payments.lastAmount, 15000);
    });

    testWidgets('a parent is warned before the prices they are reading', (
      tester,
    ) async {
      final payments = FakePaymentsRepository(reference: 'ref-test-fam');
      final app = await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: parentSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.needsPayment,
            source: AccessSource.none,
            role: AppRole.parent,
            childrenLinked: 2,
          ),
          testPricing: true,
        ),
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );

      await tester.tap(find.text('Plan').last);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('parent-test-pricing-warning')),
        findsOneWidget,
      );
      // The card still advertises the list price…
      expect(find.textContaining('You pay 6,000 RWF today'), findsOneWidget);

      await tester.tap(find.byKey(const Key('subscribe-family_monthly')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('momo-phone-field')),
        '0788123456',
      );
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      // …but only the test amount is collected, and settlement agrees.
      expect(payments.lastAmount, 100);
      expect(app.access.lastAmountRwf, 100);
    });
  });
}
