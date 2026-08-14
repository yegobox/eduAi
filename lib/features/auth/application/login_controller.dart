import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../domain/entities/app_role.dart';
import '../domain/entities/app_user.dart';
import '../domain/entities/auth_session.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

/// Drives the email sign-in / sign-up form. On success the global
/// [AuthController] updates automatically via the repository stream, so this
/// controller only owns the button's loading + error state.
class LoginController extends AutoDisposeNotifier<AuthActionState> {
  @override
  AuthActionState build() => const AuthActionState.idle();

  Future<Result<AuthSession>> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthActionState.loading();
    final result = await ref
        .read(authRepositoryProvider)
        .signInWithEmail(email: email, password: password);
    _settle(result.failureOrNull);
    return result;
  }

  Future<Result<AppUser>> signUp({
    required String email,
    required String password,
    required AppRole role,
    String? displayName,
  }) async {
    state = const AuthActionState.loading();
    final result = await ref.read(authRepositoryProvider).signUpWithEmail(
          email: email,
          password: password,
          role: role,
          displayName: displayName,
        );
    _settle(result.failureOrNull);
    return result;
  }

  Future<Result<void>> sendPasswordReset(String email) async {
    state = const AuthActionState.loading();
    final result =
        await ref.read(authRepositoryProvider).sendPasswordReset(email);
    _settle(result.failureOrNull);
    return result;
  }

  void _settle(Failure? failure) {
    state = failure == null
        ? const AuthActionState.idle()
        : AuthActionState.error(failure);
  }
}

final loginControllerProvider =
    AutoDisposeNotifierProvider<LoginController, AuthActionState>(
  LoginController.new,
);
