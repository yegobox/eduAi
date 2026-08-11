import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/offline_unlock_screen.dart';
import '../../features/auth/presentation/screens/phone_login_screen.dart';
import '../../features/auth/presentation/screens/set_pin_screen.dart';
import '../../features/auth/presentation/screens/sign_up_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/schools/domain/entities/school.dart';
import '../../features/schools/presentation/screens/school_detail_screen.dart';
import '../../features/schools/presentation/screens/schools_list_screen.dart';
import 'app_routes.dart';

/// The app router. Auth status is read from [authControllerProvider] and drives
/// redirects; a [ValueNotifier] bridge refreshes routing on status changes
/// without rebuilding the router (which would lose navigation state).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthStatus>(AuthStatus.unknown);
  ref.listen<AuthStatus>(
    authControllerProvider.select((s) => s.status),
    (_, next) => refresh.value = next,
    fireImmediately: true,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
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
          final onGate = loc == AppRoutes.splash ||
              loc == AppRoutes.unlock ||
              AppRoutes.unauthenticated.contains(loc);
          return onGate ? AppRoutes.home : null;

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
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        builder: (_, _) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.phone,
        builder: (_, _) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.unlock,
        builder: (_, _) => const OfflineUnlockScreen(),
      ),
      GoRoute(
        path: AppRoutes.setPin,
        builder: (_, _) => const SetPinScreen(),
      ),
      GoRoute(
        path: AppRoutes.schools,
        builder: (_, _) => const SchoolsListScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, state) => SchoolDetailScreen(
              schoolId: state.pathParameters['id']!,
              school: state.extra is School ? state.extra as School : null,
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, _) => const HomeScreen(),
      ),
    ],
  );
});
