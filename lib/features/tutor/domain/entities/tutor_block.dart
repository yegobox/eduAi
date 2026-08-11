import 'package:equatable/equatable.dart';

/// One piece of a tutor answer. The backend (`data-connector`
/// `/api/edu/tutor/chat`) returns an ordered list of these as `blocks`.
///
/// `TutorUnknownBlock` absorbs any type the model invents that the client
/// doesn't know yet, so a prompt drift never crashes the chat — it just
/// renders nothing for that one block.
sealed class TutorBlock extends Equatable {
  const TutorBlock();

  factory TutorBlock.fromJson(Map<String, dynamic> json) {
    switch (json['type'] as String?) {
      case 'text':
        return TutorTextBlock(json['text'] as String? ?? '');
      case 'example':
        return TutorExampleBlock(
          title: json['title'] as String? ?? 'Example',
          body: json['body'] as String? ?? '',
        );
      case 'check':
        final choices = (json['choices'] as List?)
                ?.map((e) => e.toString())
                .toList(growable: false) ??
            const <String>[];
        return TutorCheckBlock(
          question: json['question'] as String? ?? '',
          choices: choices,
          correctIndex: (json['correct_index'] as num?)?.toInt() ?? 0,
          explanation: json['explanation'] as String? ?? '',
        );
      case 'followups':
        final items = (json['items'] as List?)
                ?.map((e) => e.toString())
                .where((s) => s.trim().isNotEmpty)
                .toList(growable: false) ??
            const <String>[];
        return TutorFollowupsBlock(items);
      default:
        return TutorUnknownBlock(json['type']?.toString() ?? 'unknown');
    }
  }

  /// Plain-text flattening, used to build the `history` sent back to the
  /// tutor on the next turn (choices/followups add noise, not context).
  String get asHistoryText;
}

class TutorTextBlock extends TutorBlock {
  const TutorTextBlock(this.text);
  final String text;

  @override
  String get asHistoryText => text;

  @override
  List<Object?> get props => [text];
}

class TutorExampleBlock extends TutorBlock {
  const TutorExampleBlock({required this.title, required this.body});
  final String title;
  final String body;

  @override
  String get asHistoryText => '$title: $body';

  @override
  List<Object?> get props => [title, body];
}

class TutorCheckBlock extends TutorBlock {
  const TutorCheckBlock({
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
  });

  final String question;
  final List<String> choices;
  final int correctIndex;
  final String explanation;

  bool isCorrect(int chosenIndex) => chosenIndex == correctIndex;

  @override
  String get asHistoryText => 'Concept check: $question';

  @override
  List<Object?> get props => [question, choices, correctIndex, explanation];
}

class TutorFollowupsBlock extends TutorBlock {
  const TutorFollowupsBlock(this.items);
  final List<String> items;

  @override
  String get asHistoryText => '';

  @override
  List<Object?> get props => [items];
}

class TutorUnknownBlock extends TutorBlock {
  const TutorUnknownBlock(this.type);
  final String type;

  @override
  String get asHistoryText => '';

  @override
  List<Object?> get props => [type];
}
