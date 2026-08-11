import 'package:equatable/equatable.dart';

import '../../../core/error/failure.dart';
import '../domain/entities/tutor_turn.dart';

/// The whole tutor conversation: turns so far, whether an answer is in
/// flight, the last failure (if any), and the optional subject/level context
/// sent with every question.
class TutorChatState extends Equatable {
  const TutorChatState({
    this.turns = const [],
    this.busy = false,
    this.failure,
    this.subject,
    this.level,
  });

  final List<TutorTurn> turns;
  final bool busy;
  final Failure? failure;
  final String? subject;
  final String? level;

  TutorChatState copyWith({
    List<TutorTurn>? turns,
    bool? busy,
    Failure? failure,
    bool clearFailure = false,
    String? subject,
    bool clearSubject = false,
    String? level,
    bool clearLevel = false,
  }) {
    return TutorChatState(
      turns: turns ?? this.turns,
      busy: busy ?? this.busy,
      failure: clearFailure ? null : (failure ?? this.failure),
      subject: clearSubject ? null : (subject ?? this.subject),
      level: clearLevel ? null : (level ?? this.level),
    );
  }

  @override
  List<Object?> get props => [turns, busy, failure, subject, level];
}
