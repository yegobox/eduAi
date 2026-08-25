import 'package:eduai/app/shell/app_shell.dart';
import 'package:eduai/core/network/connectivity_service.dart';
import 'package:eduai/core/platform/app_platform_style.dart';
import 'package:eduai/core/router/app_routes.dart';
import 'package:eduai/features/auth/domain/entities/app_role.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const _session = AuthSession(
  user: AppUser(id: 'u1', displayName: 'Mura'),
  provider: AuthProvider.supabaseEmail,
);

const _parentSession = AuthSession(
  user: AppUser(id: 'p1', displayName: 'Parent', role: AppRole.parent),
  provider: AuthProvider.supabaseEmail,
);

const _adminSession = AuthSession(
  user: AppUser(id: 'a1', displayName: 'Admin', role: AppRole.schoolAdmin),
  provider: AuthProvider.supabaseEmail,
);

void main() {
  group('Adaptive shell', () {
    for (final platform in AppPlatformStyle.values) {
      testWidgets('renders the student tabs on ${platform.name}', (
        tester,
      ) async {
        await pumpApp(
          tester,
          auth: FakeAuthRepository(initialSession: _session),
          platform: platform,
        );

        expect(tester.takeException(), isNull);
        // Every tab is reachable from the chrome, whatever shape it takes.
        for (final label in [
          'Home',
          'Tutor',
          'Workbook',
          'Lessons',
          'Progress',
        ]) {
          expect(find.text(label), findsWidgets, reason: '$platform / $label');
        }
        expect(find.textContaining('Hello, Mura'), findsOneWidget);
      });

      testWidgets('switches tabs on ${platform.name}', (tester) async {
        await pumpApp(
          tester,
          auth: FakeAuthRepository(initialSession: _session),
          platform: platform,
        );

        // Tap the chrome's own Lessons control (the last "Lessons" in the
        // tree is the nav item, not the Home card).
        await tester.tap(find.text('Lessons').last);
        await tester.pumpAndSettle();

        expect(find.text('P1–P6'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Android uses a Material NavigationBar', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        platform: AppPlatformStyle.android,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('iOS uses its own tab bar, not a NavigationBar', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        platform: AppPlatformStyle.ios,
      );
      expect(find.byType(NavigationBar), findsNothing);
      // The large title is the iOS nav bar.
      expect(find.text('Home'), findsWidgets);
    });

    testWidgets('desktop chrome carries no bottom tab bar', (tester) async {
      for (final platform in [
        AppPlatformStyle.macos,
        AppPlatformStyle.windows,
      ]) {
        await pumpApp(
          tester,
          auth: FakeAuthRepository(initialSession: _session),
          platform: platform,
        );
        expect(find.byType(NavigationBar), findsNothing, reason: '$platform');
      }
    });

    testWidgets('a phone-width desktop window moves the tabs to the bottom', (
      tester,
    ) async {
      // A resized macOS window (or a phone frame in the device previewer) has
      // no room for the toolbar's title + segmented control + status actions.
      for (final platform in AppPlatformStyle.values) {
        await pumpApp(
          tester,
          auth: FakeAuthRepository(initialSession: _session),
          platform: platform,
          size: mobileSize,
        );
        expect(tester.takeException(), isNull, reason: '$platform');
        for (final label in ['Home', 'Tutor', 'Workbook']) {
          expect(find.text(label), findsWidgets, reason: '$platform / $label');
        }
      }
    });

    testWidgets('a phone-width window opens the menu as a sheet', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        platform: AppPlatformStyle.macos,
        size: mobileSize,
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('the desktop toolbar survives a mid-width window', (
      tester,
    ) async {
      // Just above the compact breakpoint — the widest window that still shows
      // a desktop toolbar, and the one that used to overflow.
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        platform: AppPlatformStyle.macos,
        size: const Size(710, 900),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('Windows shows the app identity strip', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        platform: AppPlatformStyle.windows,
      );
      expect(find.text('EduAI'), findsOneWidget);
    });
  });

  group('Status chip', () {
    testWidgets('reads Online when there is a transport', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('reads Offline with no transport', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        network: NetworkStatus.offline,
      );
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('calls out an offline session specifically', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(
          initialSession: const AuthSession(
            user: AppUser(id: 'u1', displayName: 'Mura'),
            provider: AuthProvider.offline,
          ),
        ),
      );
      expect(find.text('Offline session'), findsOneWidget);
    });

    testWidgets('compacts to a dot on desktop', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        platform: AppPlatformStyle.macos,
        network: NetworkStatus.offline,
      );
      expect(find.text('Offline'), findsOneWidget);
    });
  });

  group('More menu', () {
    testWidgets('offers PIN, language and sign out', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Set / change offline PIN'), findsOneWidget);
      expect(find.text('Language: English'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('changing the language updates the menu label', (tester) async {
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Language: English'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kinyarwanda'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Language: Kinyarwanda'), findsOneWidget);
    });

    testWidgets('opens as a dialog on desktop', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        platform: AppPlatformStyle.windows,
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });

  group('Role routing', () {
    testWidgets('a parent identity lands in the parent shell', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _parentSession),
      );
      for (final label in ['Overview', 'Reports', 'Messages', 'Plan']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      // Student tabs are not in a parent's chrome.
      expect(find.text('Workbook'), findsNothing);
    });

    testWidgets('a school-admin identity lands in the admin shell', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _adminSession),
      );
      // "People" rather than "Seats": the tab shows who occupies the seats and
      // lets the admin invite their parents.
      for (final label in ['License', 'People', 'Invoices', 'Usage']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    });

    testWidgets('a student deep-linked into the parent shell is bounced home', (
      tester,
    ) async {
      await pumpApp(tester, auth: FakeAuthRepository(initialSession: _session));

      // A student account has no parent identity, so this must not open the
      // parent billing tab.
      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutes.parentPlan);
      await tester.pumpAndSettle();

      expect(find.textContaining('Hello, Mura'), findsOneWidget);
      expect(find.text('Want more AI Tutor sessions?'), findsNothing);
    });

    testWidgets('a parent deep-linked into the admin shell is bounced home', (
      tester,
    ) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _parentSession),
      );

      GoRouter.of(
        tester.element(find.byType(AppShell)),
      ).go(AppRoutes.adminSeats);
      await tester.pumpAndSettle();

      expect(find.text('Seats by class'), findsNothing);
      expect(find.text('Overview'), findsWidgets);
    });
  });
}
