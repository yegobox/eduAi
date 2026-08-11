import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/auth_session.dart';

/// High-level authentication status that drives routing.
enum AuthStatus {
  /// Startup: still resolving whether a session exists.
  unknown,

  /// A live (or offline-unlocked) session is present.
  authenticated,

  /// No session and nothing cached — show the sign-in screen.
  unauthenticated,

  /// No live session, but this device has a cached account with an offline
  /// PIN — show the offline-unlock screen.
  offlineLocked,
}

/// Global, router-facing auth state.
class AuthState extends Equatable {
  const AuthState({
    required this.status,
    this.session,
    this.offlineLabel,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.authenticated(AuthSession session)
      : this(status: AuthStatus.authenticated, session: session);
  const AuthState.offlineLocked(String? label)
      : this(status: AuthStatus.offlineLocked, offlineLabel: label);

  final AuthStatus status;
  final AuthSession? session;
  final String? offlineLabel;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolved => status != AuthStatus.unknown;

  @override
  List<Object?> get props => [status, session, offlineLabel];
}

/// Transient state for a single async auth action (a form submission).
/// Kept separate from [AuthState] so form churn never rebuilds the router.
class AuthActionState extends Equatable {
  const AuthActionState({this.submitting = false, this.failure});

  final bool submitting;
  final Failure? failure;

  const AuthActionState.idle() : this();
  const AuthActionState.loading() : this(submitting: true);
  const AuthActionState.error(Failure failure) : this(failure: failure);

  AuthActionState copyWith({bool? submitting, Failure? failure}) {
    return AuthActionState(
      submitting: submitting ?? this.submitting,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [submitting, failure];
}
