import 'package:equatable/equatable.dart';

enum LearningEventKind {
  /// The user asked the tutor a question.
  question,

  /// The user answered a concept check.
  check,
}

LearningEventKind _kindFrom(String? raw) => LearningEventKind.values.firstWhere(
      (k) => k.name == raw,
      orElse: () => LearningEventKind.question,
    );

/// One recorded learning action. Append-only: every progress figure the app
/// shows is derived from a list of these, never stored pre-aggregated.
class LearningEvent extends Equatable {
  const LearningEvent({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.subject,
    this.level,
    this.topic,
    this.isCorrect,
  });

  final String id;
  final LearningEventKind kind;
  final DateTime createdAt;
  final String? subject;
  final String? level;
  final String? topic;

  /// Only set for [LearningEventKind.check].
  final bool? isCorrect;

  /// The label to count under "topics covered": the explicit subject when the
  /// user set one, otherwise the shortened question.
  String? get topicLabel {
    final s = subject?.trim();
    if (s != null && s.isNotEmpty) return s;
    final t = topic?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'subject': subject,
        'level': level,
        'topic': topic,
        'is_correct': isCorrect,
        'created_at': createdAt.toIso8601String(),
      };

  factory LearningEvent.fromJson(Map<String, dynamic> json) => LearningEvent(
        id: json['id'] as String,
        kind: _kindFrom(json['kind'] as String?),
        subject: json['subject'] as String?,
        level: json['level'] as String?,
        topic: json['topic'] as String?,
        isCorrect: json['is_correct'] as bool?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  List<Object?> get props => [id, kind, subject, level, topic, isCorrect, createdAt];
}
