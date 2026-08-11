import 'package:equatable/equatable.dart';

import '../error/failure.dart';

/// Transient state for a single async command (join, create, leave…): whether
/// it is running and the last failure, if any. Kept out of feature data state
/// so a button spinner never rebuilds a list.
class ActionState extends Equatable {
  const ActionState({this.busy = false, this.failure});

  final bool busy;
  final Failure? failure;

  const ActionState.idle() : this();
  const ActionState.loading() : this(busy: true);
  const ActionState.error(Failure failure) : this(failure: failure);

  @override
  List<Object?> get props => [busy, failure];
}
