import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell/app_shell.dart';
import '../../app/shell/shell_tab.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/application/role_providers.dart';
import '../../features/auth/domain/entities/app_role.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/offline_unlock_screen.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';
import '../../features/auth/presentation/screens/set_pin_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/billing/presentation/screens/admin_invoices_screen.dart';
import '../../features/billing/presentation/screens/admin_license_screen.dart';
import '../../features/billing/presentation/screens/admin_seats_screen.dart';
import '../../features/billing/presentation/screens/admin_usage_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/lessons/presentation/screens/lesson_reader_screen.dart';
import '../../features/lessons/presentation/screens/lessons_screen.dart';
import '../../features/linking/presentation/screens/family_links_screen.dart';
import '../../features/parent/presentation/screens/parent_messages_screen.dart';
import '../../features/parent/presentation/screens/parent_overview_screen.dart';
import '../../features/parent/presentation/screens/parent_plan_screen.dart';
import '../../features/parent/presentation/screens/parent_reports_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/schools/domain/entities/school.dart';
import '../../features/schools/presentation/screens/school_detail_screen.dart';
import '../../features/schools/presentation/screens/schools_list_screen.dart';
import '../../features/teacher/presentation/screens/teacher_class_screen.dart';
import '../../features/teacher/presentation/screens/teacher_classes_screen.dart';
import '../../features/teacher/presentation/screens/teacher_progress_screen.dart';
import '../../features/tutor/presentation/screens/tutor_screen.dart';
import '../../features/workbook/presentation/screens/workbook_screen.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app router.
///
/// Three tabbed shells, one per role, plus the signed-out gate and the pushed
/// detail pages. Auth status *and* role drive redirects; a `ValueNotifier`
/// bridge refreshes routing without rebuilding the router (which would lose
/// navigation state).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<Object?>(null);
  ref.listen<AuthStatus>(
    authControllerProvider.select((s) => s.status),
    (_, next) => refresh.value = next,
    fireImmediately: true,
  );
  ref.listen<AppRole>(activeRoleProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;

      switch (status) {
        case AuthStatus.unknown:
          return loc == AppRoutes.splash ? null : AppRoutes.splash;

        case AuthStatus.authenticated:
          final role = ref.read(activeRoleProvider);
          final onGate =
              loc == AppRoutes.splash ||
              loc == AppRoutes.unlock ||
              AppRoutes.unauthenticated.contains(loc);
          if (onGate) return AppRoutes.homeFor(role);
          // Deep link into another role's shell: bounce to this identity's own
          // home rather than rendering tabs it has no account for.
          if (AppRoutes.isForeignShell(loc, role)) {
            return AppRoutes.homeFor(role);
          }
          return null;

        case AuthStatus.offlineLocked:
          // Allow trying an online sign-in, otherwise force the unlock screen.
          if (AppRoutes.unauthenticated.contains(loc)) return null;
          return loc == AppRoutes.unlock ? null : AppRoutes.unlock;

        case AuthStatus.unauthenticated:
          if (AppRoutes.unauthenticated.contains(loc)) return null;
          return AppRoutes.login;
      }
    },
    routes: [
      // ---- gate ----------------------------------------------------------
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.signUp, builder: (_, _) => const SignUpScreen()),
      GoRoute(
        path: AppRoutes.phone,
        builder: (_, _) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.unlock,
        builder: (_, _) => const OfflineUnlockScreen(),
      ),

      // ---- tabbed shells, one per role -----------------------------------
      _shell(ShellTabs.student, const [
        HomeScreen(),
        TutorScreen(),
        WorkbookScreen(),
        LessonsScreen(),
        ProgressScreen(),
      ]),
      _shell(ShellTabs.parent, const [
        ParentOverviewScreen(),
        ParentReportsScreen(),
        ParentMessagesScreen(),
        ParentPlanScreen(),
      ]),
      _shell(ShellTabs.teacher, const [
        TeacherClassesScreen(),
        TeacherProgressScreen(),
      ]),
      _shell(ShellTabs.schoolAdmin, const [
        AdminLicenseScreen(),
        AdminSeatsScreen(),
        AdminInvoicesScreen(),
        AdminUsageScreen(),
      ]),

      // ---- pushed detail pages (cover the tab bar) -----------------------
      GoRoute(
        path: AppRoutes.setPin,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SetPinScreen(),
      ),
      GoRoute(
        path: AppRoutes.schools,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const SchoolsListScreen(),
      ),
      GoRoute(
        path: AppRoutes.family,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, _) => const FamilyLinksScreen(),
      ),
      GoRoute(
        path: '/school/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) => SchoolDetailScreen(
          schoolId: state.pathParameters['id']!,
          school: state.extra is School ? state.extra as School : null,
        ),
      ),
      GoRoute(
        path: '/teacher/class/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            TeacherClassScreen(classId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lesson/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (_, state) =>
            LessonReaderScreen(lessonId: state.pathParameters['id']!),
      ),
    ],
  );
});

/// Builds one role's `StatefulShellRoute`: one branch per tab, in tab order.
StatefulShellRoute _shell(List<ShellTab> tabs, List<Widget> screens) {
  assert(
    tabs.length == screens.length,
    'Every tab needs exactly one screen, in the same order.',
  );
  return StatefulShellRoute.indexedStack(
    builder: (_, _, navigationShell) =>
        AppShell(navigationShell: navigationShell, tabs: tabs),
    branches: [
      for (var i = 0; i < tabs.length; i++)
        StatefulShellBranch(
          routes: [GoRoute(path: tabs[i].route, builder: (_, _) => screens[i])],
        ),
    ],
  );
}
