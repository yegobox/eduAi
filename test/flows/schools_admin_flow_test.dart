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
  /// Enrols with a class code, then opens the school it resolved to — the only
  /// way a student reaches a school page now that the catalog is gone.
  Future<void> enrolAndOpenSchool(WidgetTester tester) async {
    await tester.tap(find.text('Join by code').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('not-enrolled-join')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'ENG6');
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kigali Modern Academy').first);
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

    testWidgets('a student is not offered class authoring', (tester) async {
      // The server refuses the insert (`classes_insert_self`), so this was never
      // a hole — but a button that always fails is still a bug.
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await enrolAndOpenSchool(tester);

      expect(find.text('Add class'), findsNothing);
    });

    testWidgets('a student is not offered school creation', (tester) async {
      // "New school" used to be an unguarded button for every signed-in account.
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await tester.tap(find.text('Join by code').last);
      await tester.pumpAndSettle();

      expect(find.text('New school'), findsNothing);
    });

    testWidgets('joining a class counts as joining its school', (tester) async {
      // The membership row carries both ids, so a student who joined a class is
      // already in the school — offering "Join this school" again would add a
      // second, redundant row.
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await enrolAndOpenSchool(tester);

      expect(find.text('You are a member'), findsOneWidget);
      expect(find.text('You joined through a class below.'), findsOneWidget);
      expect(find.text('Join this school'), findsNothing);
      // Leaving is the class tile's job, not the school card's.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('You are a member'),
            matching: find.byType(AppCard),
          ),
          matching: find.widgetWithText(OutlinedButton, 'Leave'),
        ),
        findsNothing,
      );
    });

    testWidgets('leaving the class removes the school from the list', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await enrolAndOpenSchool(tester);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Leave').first);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('You have not joined a school yet'), findsOneWidget);
    });
  });
}
