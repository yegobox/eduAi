import 'package:eduai/core/network/connectivity_service.dart';
import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/features/auth/application/auth_controller.dart';
import 'package:eduai/features/auth/application/auth_providers.dart';
import 'package:eduai/features/auth/application/auth_state.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/home/presentation/home_screen.dart';
import 'package:eduai/features/schools/application/schools_providers.dart';
import 'package:eduai/features/schools/domain/entities/membership.dart';
import 'package:eduai/features/schools/domain/entities/school.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A fake global auth controller so the home screen has a session without
/// touching secure storage / Supabase.
class _FakeAuthController extends AuthController {
  @override
  AuthState build() => AuthState.authenticated(
        const AuthSession(
          user: AppUser(id: 'u1', displayName: 'Test Teacher'),
          provider: AuthProvider.supabaseEmail,
        ),
      );
}

void main() {
  const schools = [
    School(id: 's1', name: 'Kigali Modern Academy'),
    School(id: 's2', name: 'Green Hills Secondary'),
  ];

  Future<void> pumpHome(
    WidgetTester tester, {
    required List<Membership> memberships,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A router so context.push targets resolve; we only render '/'.
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          networkStatusProvider
              .overrideWith((ref) => Stream.value(NetworkStatus.online)),
          hasOfflinePinProvider.overrideWith((ref) async => true),
          schoolsListProvider.overrideWith((ref) async => schools),
          myMembershipsProvider.overrideWith((ref) async => memberships),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ),
    );
    // Resolve the overridden futures.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('HomeScreen lays out with no memberships', (tester) async {
    await pumpHome(tester, memberships: const []);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Hello'), findsOneWidget);
    expect(find.text('Browse schools'), findsOneWidget);
  });

  testWidgets('HomeScreen lays out with memberships', (tester) async {
    await pumpHome(tester, memberships: const [
      Membership(id: 'm1', userId: 'u1', schoolId: 's1', role: MemberRole.owner),
      Membership(
        id: 'm2',
        userId: 'u1',
        schoolId: 's2',
        classId: 'c9',
        role: MemberRole.student,
      ),
    ]);
    expect(tester.takeException(), isNull);
    // Both memberships resolve to their school names.
    expect(find.text('Kigali Modern Academy'), findsWidgets);
    expect(find.text('Green Hills Secondary'), findsWidgets);
  });
}
