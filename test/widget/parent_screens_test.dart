import 'package:eduai/core/config/app_config.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/parent/application/parent_providers.dart';
import 'package:eduai/features/payments/application/momo_payment_controller.dart';
import 'package:eduai/features/payments/domain/entities/momo_payment.dart';
import 'package:eduai/features/progress/application/mastery_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const _parentSession = AuthSession(
  user: AppUser(
    id: 'p1',
    displayName: 'Parent',
    phoneNumber: '+250788123456',
    role: AppRole.parent,
  ),
  provider: AuthProvider.supabaseEmail,
);

/// A build with the tutor backend wired but no Mobile Money credentials.
const _noMomoConfig = AppConfig(
  supabaseUrl: '',
  supabaseAnonKey: '',
  enablePhoneAuth: true,
  flavor: 'test',
  dataConnectorUrl: 'http://localhost:8084',
);

Future<AppUnderTest> pumpParent(
  WidgetTester tester, {
  List<Override> extraOverrides = const [],
  Size size = desktopSize,
}) {
  return pumpApp(
    tester,
    auth: FakeAuthRepository(initialSession: _parentSession),
    size: size,
    extraOverrides: extraOverrides,
  );
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('Parent overview', () {
    testWidgets('shows this week at a glance for the first child', (
      tester,
    ) async {
      await pumpParent(tester);

      expect(find.text('210'), findsOneWidget); // minutes this week
      expect(find.text('34'), findsOneWidget); // questions asked
      expect(find.text('5d'), findsOneWidget); // streak
      expect(find.text('Needs a little attention'), findsOneWidget);
      expect(find.text('Recent activity'), findsOneWidget);
      expect(find.text('Works without internet'), findsOneWidget);
    });

    testWidgets('switching child updates the numbers', (tester) async {
      await pumpParent(tester);
      expect(find.text('Alice K.'), findsWidgets);

      await tester.tap(find.text('Jean P.'));
      await tester.pumpAndSettle();

      expect(find.text('96'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.textContaining("Jean's lessons"), findsOneWidget);
    });

    testWidgets('the child selection carries over to Reports', (tester) async {
      await pumpParent(tester);
      await tester.tap(find.text('Jean P.'));
      await tester.pumpAndSettle();

      await openTab(tester, 'Reports');

      // Jean's English mastery is 41%, Alice's is 64%.
      expect(find.text('41%'), findsOneWidget);
      expect(find.text('64%'), findsNothing);
    });

    testWidgets('says so plainly when no child is linked', (tester) async {
      await pumpParent(
        tester,
        extraOverrides: [
          parentChildrenProvider.overrideWith((ref) async => []),
        ],
      );
      expect(find.text('No children linked yet'), findsOneWidget);
    });
  });

  group('Parent reports', () {
    testWidgets('renders per-subject mastery bars', (tester) async {
      await pumpParent(tester);
      await openTab(tester, 'Reports');

      expect(find.text("This week's report"), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('78%'), findsOneWidget);
      expect(find.textContaining('not every wrong answer'), findsOneWidget);
    });

    testWidgets('respects the student turning sharing off', (tester) async {
      await pumpParent(
        tester,
        extraOverrides: [progressSharingProvider.overrideWith(_SharingOff.new)],
      );
      await openTab(tester, 'Reports');

      expect(find.text('Sharing is turned off'), findsOneWidget);
      expect(find.text("This week's report"), findsNothing);
    });
  });

  group('Parent messages', () {
    testWidgets('shows the teacher thread', (tester) async {
      await pumpParent(tester);
      await openTab(tester, 'Messages');

      expect(
        find.textContaining("Alice did great on this week's fractions quiz"),
        findsOneWidget,
      );
      expect(
        find.text('Yes — REB worksheet 4, shared in Lessons.'),
        findsOneWidget,
      );
    });

    testWidgets('sending appends the parent\'s own message', (tester) async {
      await pumpParent(tester);
      await openTab(tester, 'Messages');

      await tester.enterText(
        find.byKey(const Key('parent-message-field')),
        'Thank you, we will practise tonight.',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('parent-message-send')));
      await tester.pumpAndSettle();

      expect(find.text('Thank you, we will practise tonight.'), findsOneWidget);
    });

    testWidgets('the send button is disabled while the field is empty', (
      tester,
    ) async {
      await pumpParent(tester);
      await openTab(tester, 'Messages');

      final button = tester.widget<IconButton>(
        find.byKey(const Key('parent-message-send')),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('Parent plan', () {
    testWidgets('leads with the school covering the cost, not a paywall', (
      tester,
    ) async {
      await pumpParent(tester);
      await openTab(tester, 'Plan');

      expect(
        find.textContaining("Included in Kigali Modern Academy's EduAI plan"),
        findsOneWidget,
      );
      expect(
        find.textContaining('never required to keep learning'),
        findsOneWidget,
      );
      expect(
        find.textContaining('never sold or used for advertising'),
        findsOneWidget,
      );
      expect(find.text('Small top-up'), findsOneWidget);
      expect(find.text('500 RWF'), findsOneWidget);
    });

    testWidgets('hides the buy action when MoMo is not configured', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _parentSession),
        config: _noMomoConfig,
      );
      await openTab(tester, 'Plan');

      expect(
        find.textContaining('Mobile Money is not set up on this build'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('topup-small')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('a settled MoMo payment credits the sessions', (tester) async {
      final payments = FakePaymentsRepository(reference: 'ref-77');
      await pumpParent(
        tester,
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );
      await openTab(tester, 'Plan');

      await tester.tap(find.byKey(const Key('topup-small')));
      await tester.pumpAndSettle();

      // The phone number is pre-filled from the signed-in parent account
      // (the hint shows the same digits, so read the field's own value).
      final field = tester.widget<TextField>(
        find.byKey(const Key('momo-phone-field')),
      );
      expect(field.controller?.text, '0788123456');

      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(payments.initiateCalls, 1);
      expect(payments.lastAmount, 500);
      expect(find.text('20 sessions added — thank you.'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
    });

    testWidgets('a rejected payment credits nothing', (tester) async {
      final payments = FakePaymentsRepository(
        statuses: [MomoPaymentStatus.failed],
      );
      await pumpParent(
        tester,
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );
      await openTab(tester, 'Plan');

      await tester.tap(find.byKey(const Key('topup-small')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(find.text('Payment not completed'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      // Back to the entry state, nothing credited.
      expect(find.byKey(const Key('momo-pay-button')), findsOneWidget);
      expect(find.text('Added'), findsNothing);
    });

    testWidgets('an invalid number is caught before the gateway is called', (
      tester,
    ) async {
      final payments = FakePaymentsRepository();
      await pumpParent(
        tester,
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
        ],
      );
      await openTab(tester, 'Plan');

      await tester.tap(find.byKey(const Key('topup-small')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('momo-phone-field')),
        '0700000',
      );
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(payments.initiateCalls, 0);
      expect(find.textContaining('valid MTN or Airtel number'), findsOneWidget);
    });

    testWidgets('a pending status that explains itself is shown, not hidden', (
      tester,
    ) async {
      // A gateway that cannot reach MTN answers PENDING with the transport
      // error attached. Waiting five silent minutes for a push that was never
      // sent is indistinguishable from a slow payer, so the reason is surfaced
      // while polling continues.
      final payments = FakePaymentsRepository(
        statuses: [MomoPaymentStatus.pending],
        pendingReason:
            'status check failed: MTN token request failed (411 Length Required)',
      );
      await pumpParent(
        tester,
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
          momoPollTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 60),
          ),
        ],
      );
      await openTab(tester, 'Plan');

      await tester.tap(find.byKey(const Key('topup-small')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byKey(const Key('momo-pending-reason')), findsOneWidget);
      expect(find.textContaining('411 Length Required'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('a slow approval never claims the payment failed', (
      tester,
    ) async {
      final payments = FakePaymentsRepository(
        statuses: [MomoPaymentStatus.pending],
      );
      await pumpParent(
        tester,
        extraOverrides: [
          paymentsRepositoryProvider.overrideWithValue(payments),
          momoPollTimeoutProvider.overrideWithValue(
            const Duration(milliseconds: 30),
          ),
        ],
      );
      await openTab(tester, 'Plan');

      await tester.tap(find.byKey(const Key('topup-small')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('momo-pay-button')));
      await tester.pumpAndSettle();

      expect(find.text('Still waiting for your approval'), findsOneWidget);
      expect(find.textContaining('do not pay twice'), findsOneWidget);
    });
  });
}

/// A sharing flag that is off, for the Reports gating test.
class _SharingOff extends ProgressSharingController {
  @override
  Future<bool> build() async => false;
}
