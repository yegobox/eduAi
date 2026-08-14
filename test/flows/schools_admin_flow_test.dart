import 'package:eduai/core/widgets/app_widgets.dart';
import 'package:eduai/features/access/domain/entities/access_state.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const _session = AuthSession(
  user: AppUser(id: 'u1', displayName: 'Mura'),
  provider: AuthProvider.supabaseEmail,
);

/// Creating a school is a school-admin action, so the authoring flows need a
/// director identity. A student session reaching the same button was the bug.
const _adminSession = AuthSession(
  user: AppUser(id: 'a1', displayName: 'Director', role: AppRole.schoolAdmin),
  provider: AuthProvider.supabaseEmail,
);

void main() {
  Future<void> openSchools(WidgetTester tester) async {
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
  }

  group('Schools management', () {
    testWidgets('a director creates their school from the Licence tab', (
      tester,
    ) async {
      // The real onboarding path: a school-admin identity with no school yet is
      // asked to create one, and that is what starts the trial licence.
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _adminSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.needsSetup,
            source: AccessSource.none,
            role: AppRole.schoolAdmin,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('create-school-cta')));
      await tester.pumpAndSettle();
      expect(find.text('Create a school'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'Nyanza Primary');
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Create a school'), findsNothing);
    });

    testWidgets('an empty school name keeps the dialog open', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _adminSession),
        access: FakeAccessRepository(
          state: const AccessState(
            status: AccessStatus.needsSetup,
            source: AccessSource.none,
            role: AppRole.schoolAdmin,
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('create-school-cta')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(find.text('Create a school'), findsOneWidget);
    });

    testWidgets('a student cannot create a school', (tester) async {
      // This was the hole: "New school" used to be an unguarded button on the
      // catalog for every signed-in account.
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await openSchools(tester);

      expect(find.text('New school'), findsNothing);
      expect(find.text('Join by code'), findsOneWidget);
      expect(
        find.textContaining('a parent can subscribe for you instead'),
        findsNothing,
      );
    });

    testWidgets('adding a class shows it on the school page', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await openSchools(tester);

      await tester.tap(find.text('Kigali Modern Academy'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add class'));
      await tester.pumpAndSettle();
      expect(find.text('Add a class'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(0), 'P4 — Science');
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await tester.pumpAndSettle();

      expect(find.text('P4 — Science'), findsOneWidget);
    });

    testWidgets('joining then leaving a school flips the membership card', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await openSchools(tester);
      await tester.tap(find.text('Kigali Modern Academy'));
      await tester.pumpAndSettle();

      final membershipCard = find.ancestor(
        of: find.text('Join this school'),
        matching: find.byType(AppCard),
      );
      await tester.tap(
        find.descendant(
          of: membershipCard,
          matching: find.widgetWithText(FilledButton, 'Join'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You are a member'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Leave').first);
      await tester.pumpAndSettle();
      expect(find.text('Join this school'), findsOneWidget);
    });

    testWidgets('a joined school reads as joined in the catalog', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await openSchools(tester);
      await tester.tap(find.text('Kigali Modern Academy'));
      await tester.pumpAndSettle();

      final membershipCard = find.ancestor(
        of: find.text('Join this school'),
        matching: find.byType(AppCard),
      );
      await tester.tap(
        find.descendant(
          of: membershipCard,
          matching: find.widgetWithText(FilledButton, 'Join'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('JOINED'), findsOneWidget);
    });
  });
}
