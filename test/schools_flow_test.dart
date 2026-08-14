import 'package:eduai/core/widgets/app_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'teacher@eduai.dev',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }

  /// Enrols with a code from the student's own school page.
  Future<void> joinWithCode(WidgetTester tester, String code) async {
    await tester.tap(find.text('Join by code').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, code);
    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();
  }

  group('Schools flow', () {
    testWidgets('a student with no school is offered the code, not a list', (
      tester,
    ) async {
      // Browsing every school in the country was never a student flow, and
      // enrolling from that list consumed a seat on somebody else's licence.
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);

      await tester.tap(find.text('Join by code').last);
      await tester.pumpAndSettle();

      expect(find.text('My school'), findsOneWidget);
      expect(find.text('You have not joined a school yet'), findsOneWidget);
      expect(find.byKey(const Key('not-enrolled-join')), findsOneWidget);
      // No catalog.
      expect(find.text('Kigali Modern Academy'), findsNothing);
      expect(find.text('Green Hills Secondary'), findsNothing);
    });

    testWidgets('a code enrols, and only that school is listed', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);
      await tester.tap(find.text('Join by code').last);
      await tester.pumpAndSettle();
      await joinWithCode(tester, 'ENG6');

      // The class code resolved its school, which is now the only one shown.
      expect(find.text('Kigali Modern Academy'), findsWidgets);
      expect(find.text('Green Hills Secondary'), findsNothing);
      expect(find.text('You have not joined a school yet'), findsNothing);
    });

    testWidgets('the joined school opens, and the class reads as joined', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);
      await tester.tap(find.text('Join by code').last);
      await tester.pumpAndSettle();
      await joinWithCode(tester, 'ENG6');

      await tester.tap(find.text('Kigali Modern Academy').first);
      await tester.pumpAndSettle();

      expect(find.text('P6 — English'), findsOneWidget);
      final classCard = find.ancestor(
        of: find.text('P6 — English'),
        matching: find.byType(AppCard),
      );
      expect(
        find.descendant(of: classCard, matching: find.text('Leave')),
        findsOneWidget,
      );
      // Already in the school through that class.
      expect(find.text('You are a member'), findsOneWidget);
      expect(find.text('Join this school'), findsNothing);
    });

    testWidgets('it shows on home under My schools & classes', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);
      await tester.tap(find.text('Join by code').last);
      await tester.pumpAndSettle();
      await joinWithCode(tester, 'ENG6');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello'), findsOneWidget);
      expect(find.text('Kigali Modern Academy'), findsWidgets);
      expect(find.text("You haven't joined anywhere yet"), findsNothing);
    });

    testWidgets('an invalid code keeps the dialog open with the reason', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);
      await tester.tap(find.text('Join by code').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('not-enrolled-join')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'NOPE');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(find.text('Join with a code'), findsOneWidget);
      expect(
        find.textContaining('No school or class matches that code'),
        findsOneWidget,
      );
    });
  });
}
