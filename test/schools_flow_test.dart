import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';
import 'support/harness.dart';

void main() {
  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(
        find.byType(TextFormField).at(0), 'teacher@eduai.dev');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }

  group('Schools flow', () {
    testWidgets('browse → open school → join a class → shows on home',
        (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);

      await tester.tap(find.text('Browse schools'));
      await tester.pumpAndSettle();
      expect(find.text('Schools'), findsOneWidget);
      expect(find.text('Kigali Modern Academy'), findsWidgets);

      await tester.tap(find.text('Kigali Modern Academy').first);
      await tester.pumpAndSettle();
      expect(find.text('P5 — Maths'), findsOneWidget);

      final classCard = find.ancestor(
        of: find.text('P5 — Maths'),
        matching: find.byType(Card),
      );
      await tester.tap(find.descendant(
        of: classCard,
        matching: find.widgetWithText(FilledButton, 'Join'),
      ));
      await tester.pumpAndSettle();

      // Class now reads as joined.
      expect(
        find.descendant(of: classCard, matching: find.text('Leave')),
        findsOneWidget,
      );

      // Pop detail → list → home (two pushes deep), then confirm the school
      // shows under "My schools & classes".
      await tester.pageBack(); // detail → schools list
      await tester.pumpAndSettle();
      await tester.pageBack(); // schools list → home
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello'), findsOneWidget);
      expect(find.text('Kigali Modern Academy'), findsWidgets);
    });

    testWidgets('valid join code enrols and marks the school joined',
        (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);

      await tester.tap(find.text('Browse schools'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Join by code'));
      await tester.pumpAndSettle();
      expect(find.text('Join with a code'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'GHS24');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pumpAndSettle();

      expect(find.text('Join with a code'), findsNothing); // dialog closed
      expect(find.text('Joined'), findsWidgets);
    });

    testWidgets('invalid join code shows an error and keeps the dialog open',
        (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);

      await tester.tap(find.text('Browse schools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Join by code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'NOPE99');
      await tester.tap(find.widgetWithText(FilledButton, 'Join'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
          find.text('No school or class matches that code.'), findsOneWidget);
      expect(find.text('Join with a code'), findsOneWidget); // still open
    });
  });
}
