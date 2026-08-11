import 'package:equatable/equatable.dart';

import 'tutor_block.dart';

/// One message in the tutor conversation, from either side.
sealed class TutorTurn extends Equatable {
  const TutorTurn();

  const factory TutorTurn.user(String text) = TutorUserTurn;

  const factory TutorTurn.assistant({
    required List<TutorBlock> blocks,
    required String modelUsed,
  }) = TutorAssistantTurn;

  /// `role`/`content` pair sent as one entry of the `history` array on the
  /// *next* request — mirrors the data-connector chat history contract.
  String get role;
  String get historyContent;
}

class TutorUserTurn extends TutorTurn {
  const TutorUserTurn(this.text);
  final String text;

  @override
  String get role => 'user';

  @override
  String get historyContent => text;

  @override
  List<Object?> get props => [text];
}

class TutorAssistantTurn extends TutorTurn {
  const TutorAssistantTurn({required this.blocks, required this.modelUsed});
  final List<TutorBlock> blocks;
  final String modelUsed;

  @override
  String get role => 'assistant';

  @override
  String get historyContent => blocks
      .map((b) => b.asHistoryText)
      .where((s) => s.isNotEmpty)
      .join(' ');

  @override
  List<Object?> get props => [blocks, modelUsed];
}
