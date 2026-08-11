import 'package:flutter_test/flutter_test.dart';

import 'package:eduai/core/network/connectivity_service.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'support/fakes.dart';
import 'support/harness.dart';

/// Boots the app in each entry state at mobile + desktop sizes and asserts the
/// frame lays out with no exception — with the REAL theme applied. This guards
/// the "infinite width / not laid out" class of bug across whole screens.
void main() {
  const sizes = {'mobile': mobileSize, 'desktop': desktopSize};

  const authedSession = AuthSession(
    user: AppUser(id: 'u1', displayName: 'Test Teacher', email: 'a@b.dev'),
    provider: AuthProvider.supabaseEmail,
  );

  for (final entry in sizes.entries) {
    final label = entry.key;
    final size = entry.value;

    testWidgets('login renders cleanly ($label)', (tester) async {
      await pumpApp(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('home renders cleanly ($label)', (tester) async {
      await pumpApp(
        tester,
        size: size,
        auth: FakeAuthRepository(initialSession: authedSession),
      );
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Hello'), findsOneWidget);
    });

    testWidgets('offline unlock renders cleanly ($label)', (tester) async {
      await pumpApp(
        tester,
        size: size,
        network: NetworkStatus.offline,
        auth: FakeAuthRepository(
          hasCredential: true,
          offlineLabel: 'a@b.dev',
          offlinePin: '1234',
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Unlock'), findsOneWidget);
    });

    testWidgets('schools list + detail render cleanly ($label)',
        (tester) async {
      await pumpApp(
        tester,
        size: size,
        auth: FakeAuthRepository(initialSession: authedSession),
      );
      await tester.tap(find.text('Browse schools'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Kigali Modern Academy').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('P5 — Maths'), findsOneWidget);
    });
  }
}
