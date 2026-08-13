import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../progress/application/progress_providers.dart';
import '../domain/entities/tutor_turn.dart';
import 'tutor_providers.dart';
import 'tutor_state.dart';

/// Drives one tutor conversation. History sent to the backend is always the
/// turns *before* the in-flight question — the backend is a stateless
/// completion proxy, so the client is the source of truth for the thread.
class TutorController extends AutoDisposeNotifier<TutorChatState> {
  @override
  TutorChatState build() => const TutorChatState();

  void setContext({String? subject, String? level}) {
    state = state.copyWith(
      subject: subject,
      clearSubject: subject == null,
      level: level,
      clearLevel: level == null,
    );
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.busy) return;

    final historyBefore = state.turns;
    state = state.copyWith(
      turns: [...historyBefore, TutorTurn.user(trimmed)],
      busy: true,
      clearFailure: true,
    );

    // Progress tracking is best-effort and must never delay or break the
    // answer, so it is deliberately not awaited.
    unawaited(
      ref.read(progressRecorderProvider).question(
            question: trimmed,
            subject: state.subject,
            level: state.level,
          ),
    );

    final result = await ref.read(tutorRepositoryProvider).ask(
          message: trimmed,
          history: historyBefore,
          subject: state.subject,
          level: state.level,
        );

    result.when(
      success: (answer) {
        state = state.copyWith(
          turns: [
            ...state.turns,
            TutorTurn.assistant(blocks: answer.blocks, modelUsed: answer.modelUsed),
          ],
          busy: false,
        );
      },
      failure: (f) {
        state = state.copyWith(busy: false, failure: f);
      },
    );
  }

  void dismissError() => state = state.copyWith(clearFailure: true);

  void reset() => state = const TutorChatState();
}

final tutorControllerProvider =
    AutoDisposeNotifierProvider<TutorController, TutorChatState>(
  TutorController.new,
);
