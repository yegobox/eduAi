import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../domain/entities/auth_session.dart';
import '../domain/repositories/auth_repository.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

/// Owns the global [AuthState] and the operations that change it
/// (offline unlock, sign-out). Sign-in/verify live in per-form controllers,
/// but their success flows back here via the repository's auth stream.
class AuthController extends Notifier<AuthState> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    // Any session change from any source (Supabase refresh, phone verify,
    // offline unlock, sign-out) re-derives the global status.
    ref.listen(authSessionStreamProvider, (_, next) {
      next.whenData(_applySession);
    });
    _resolveInitial();
    return const AuthState.unknown();
  }

  Future<void> _resolveInitial() async {
    final session = await _repo.restoreSession();
    if (session != null) {
      state = AuthState.authenticated(session);
      return;
    }
    state = await _lockedOrUnauthenticated();
  }

  Future<void> _applySession(AuthSession? session) async {
    if (session != null) {
      state = AuthState.authenticated(session);
      return;
    }
    state = await _lockedOrUnauthenticated();
  }

  Future<AuthState> _lockedOrUnauthenticated() async {
    if (await _repo.hasOfflineCredential() && await _repo.hasOfflinePin()) {
      return AuthState.offlineLocked(await _repo.offlineAccountLabel());
    }
    return const AuthState.unauthenticated();
  }

  /// Verifies the offline PIN and, on success, transitions to authenticated
  /// (via the repository stream). Returns the [Result] for inline UI errors.
  Future<Result<AuthSession>> unlockOffline(String pin) {
    return _repo.unlockOffline(pin);
  }

  Future<Result<void>> setOfflinePin(String pin) => _repo.setOfflinePin(pin);

  Future<void> signOut({bool forgetDevice = false}) async {
    await _repo.signOut(forgetDevice: forgetDevice);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
