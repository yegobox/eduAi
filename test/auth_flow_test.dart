import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/network/connectivity_service.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

/// End-to-end flow tests driven through the real EduAiApp (router, theme,
/// screens, controllers) with an in-memory data layer. Headless + deterministic.
void main() {
  group('Auth flow', () {
    testWidgets('boots to the login screen when signed out', (tester) async {
      await pumpApp(tester);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('wrong password is rejected and stays on login',
        (tester) async {
      await pumpApp(tester);
      await tester.enterText(
          find.byType(TextFormField).at(0), 'teacher@eduai.dev');
      await tester.enterText(find.byType(TextFormField).at(1), 'wrongpass');
      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Invalid login credentials.'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('correct credentials sign in and land on home',
        (tester) async {
      await pumpApp(tester);
      await tester.enterText(
          find.byType(TextFormField).at(0), 'teacher@eduai.dev');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello, Teacher'), findsOneWidget);
    });

    testWidgets('offline: wrong PIN is rejected on the unlock screen',
        (tester) async {
      await pumpApp(
        tester,
        network: NetworkStatus.offline,
        auth: FakeAuthRepository(
          hasCredential: true,
          offlineLabel: 'teacher@eduai.dev',
          offlinePin: '1234',
        ),
      );
      expect(find.text('Unlock'), findsOneWidget);
      expect(find.textContaining('offline PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '0000');
      await tester.tap(find.text('Unlock'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Incorrect PIN. Try again.'), findsOneWidget);
      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('offline: correct PIN unlocks to home', (tester) async {
      await pumpApp(
        tester,
        network: NetworkStatus.offline,
        auth: FakeAuthRepository(
          hasCredential: true,
          offlineLabel: 'teacher@eduai.dev',
          offlinePin: '1234',
        ),
      );
      await tester.enterText(find.byType(TextField).first, '1234');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello'), findsOneWidget);
    });

    testWidgets('set an offline PIN, then sign out requires offline unlock',
        (tester) async {
      await pumpApp(tester);

      // Sign in.
      await tester.enterText(
          find.byType(TextFormField).at(0), 'teacher@eduai.dev');
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello, Teacher'), findsOneWidget);

      // Overflow menu → Set/change offline PIN.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set/change offline PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Set an offline PIN'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), '4321');
      await tester.enterText(find.byType(TextFormField).at(1), '4321');
      await tester.tap(find.text('Save PIN'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Hello, Teacher'), findsOneWidget);

      // Sign out → a PIN now exists, so we land on offline unlock.
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Unlock'), findsOneWidget);
    });
  });
}
