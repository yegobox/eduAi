import 'package:eduai/core/error/failure.dart';
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

  Future<void> openTutor(WidgetTester tester) async {
    // Jump via the Home card, which routes to the Tutor tab.
    await tester.tap(find.text('AI Tutor'));
    await tester.pumpAndSettle();
    expect(find.text("Ask me anything you're studying"), findsOneWidget);
  }

  group('Tutor flow', () {
    testWidgets('asking a question renders the reply blocks', (tester) async {
      final tutor = FakeTutorRepository();
      await pumpApp(tester, auth: FakeAuthRepository(), tutor: tutor);
      await signIn(tester);
      await openTutor(tester);

      await tester.tap(find.text('Why is the sky blue?'));
      await tester.pumpAndSettle();

      // The question is echoed as the user's own turn…
      expect(find.text('Why is the sky blue?'), findsWidgets);
      // …and the fake's canned answer renders: explanation, concept check,
      // and a follow-up suggestion — proof all three block types render.
      expect(find.text('Quick check'), findsOneWidget);
      expect(
        find.text('Which color scatters most in the atmosphere?'),
        findsOneWidget,
      );
      expect(find.text('Why does the sunset look red?'), findsOneWidget);
      expect(tutor.askedMessages, ['Why is the sky blue?']);
    });

    testWidgets('selecting the correct check answer reveals the explanation', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository());
      await signIn(tester);
      await openTutor(tester);

      await tester.enterText(find.byType(TextField), 'why is the sky blue');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(
        find.text('Blue light has a shorter wavelength, so it scatters more.'),
        findsNothing,
      );

      await tester.tap(find.text('Blue'));
      await tester.pumpAndSettle();

      expect(
        find.text('Blue light has a shorter wavelength, so it scatters more.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping a follow-up chip sends it as the next question', (
      tester,
    ) async {
      final tutor = FakeTutorRepository();
      await pumpApp(tester, auth: FakeAuthRepository(), tutor: tutor);
      await signIn(tester);
      await openTutor(tester);

      await tester.tap(find.text('Why is the sky blue?'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Why does the sunset look red?'));
      await tester.pumpAndSettle();

      expect(tutor.askedMessages, [
        'Why is the sky blue?',
        'Why does the sunset look red?',
      ]);
      // The second call's history includes the first question and answer.
      expect(tutor.historySeenPerCall[1], hasLength(2));
    });

    testWidgets('a repository failure shows a dismissible error banner', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(),
        tutor: FakeTutorRepository(failure: const NetworkFailure()),
      );
      await signIn(tester);
      await openTutor(tester);

      await tester.tap(find.text('Why is the sky blue?'));
      await tester.pumpAndSettle();

      expect(
        find.text('No internet connection. Please try again.'),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(
        find.text('No internet connection. Please try again.'),
        findsNothing,
      );
    });
  });
}
