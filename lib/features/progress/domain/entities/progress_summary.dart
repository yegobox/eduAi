import 'package:equatable/equatable.dart';

import 'learning_event.dart';

/// Per-topic rollup shown in the "topics covered" list.
class TopicStat extends Equatable {
  const TopicStat({
    required this.name,
    required this.questions,
    required this.checksAnswered,
    required this.checksCorrect,
    required this.lastSeen,
  });

  final String name;
  final int questions;
  final int checksAnswered;
  final int checksCorrect;
  final DateTime lastSeen;

  int get totalEvents => questions + checksAnswered;

  /// Null when no concept check has been answered for this topic yet — an
  /// unanswered topic is not the same as a topic scored 0%.
  double? get accuracy =>
      checksAnswered == 0 ? null : checksCorrect / checksAnswered;

  @override
  List<Object?> get props =>
      [name, questions, checksAnswered, checksCorrect, lastSeen];
}

/// Everything the Progress screen shows, derived in one pass over the raw
/// [LearningEvent] list. Pure and dependency-free so it can be unit-tested
/// without Supabase or Flutter.
class ProgressSummary extends Equatable {
  const ProgressSummary({
    required this.totalQuestions,
    required this.checksAnswered,
    required this.checksCorrect,
    required this.currentStreak,
    required this.longestStreak,
    required this.dailyCounts,
    required this.topics,
    this.lastActivity,
  });

  static const empty = ProgressSummary(
    totalQuestions: 0,
    checksAnswered: 0,
    checksCorrect: 0,
    currentStreak: 0,
    longestStreak: 0,
    dailyCounts: {},
    topics: [],
  );

  final int totalQuestions;
  final int checksAnswered;
  final int checksCorrect;

  /// Consecutive active days ending today (or yesterday — a streak isn't
  /// broken until a full day has been missed).
  final int currentStreak;
  final int longestStreak;

  /// Date (midnight, local) → number of events that day. Drives the heatmap.
  final Map<DateTime, int> dailyCounts;

  /// Topics sorted by most-recently-studied.
  final List<TopicStat> topics;

  final DateTime? lastActivity;

  bool get hasActivity => totalQuestions > 0 || checksAnswered > 0;

  int get activeDays => dailyCounts.length;

  /// Null until at least one concept check has been answered.
  double? get accuracy =>
      checksAnswered == 0 ? null : checksCorrect / checksAnswered;

  /// Collapses [events] into a summary. [today] is injectable so streak
  /// behaviour can be tested at a fixed date.
  factory ProgressSummary.fromEvents(
    List<LearningEvent> events, {
    DateTime? today,
  }) {
    if (events.isEmpty) return empty;

    var questions = 0;
    var checks = 0;
    var correct = 0;
    DateTime? last;

    final daily = <DateTime, int>{};
    final byTopic = <String, _TopicAccumulator>{};

    for (final e in events) {
      switch (e.kind) {
        case LearningEventKind.question:
          questions++;
        case LearningEventKind.check:
          checks++;
          if (e.isCorrect ?? false) correct++;
      }

      final day = _dateOnly(e.createdAt);
      daily[day] = (daily[day] ?? 0) + 1;

      if (last == null || e.createdAt.isAfter(last)) last = e.createdAt;

      final topic = e.topicLabel;
      if (topic != null) {
        (byTopic[topic.toLowerCase()] ??= _TopicAccumulator(topic)).add(e);
      }
    }

    final streaks = _streaks(daily.keys.toSet(), _dateOnly(today ?? DateTime.now()));
    final topics = byTopic.values.map((a) => a.build()).toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

    return ProgressSummary(
      totalQuestions: questions,
      checksAnswered: checks,
      checksCorrect: correct,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
      dailyCounts: Map.unmodifiable(daily),
      topics: List.unmodifiable(topics),
      lastActivity: last,
    );
  }

  @override
  List<Object?> get props => [
        totalQuestions,
        checksAnswered,
        checksCorrect,
        currentStreak,
        longestStreak,
        dailyCounts,
        topics,
        lastActivity,
      ];
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

typedef _Streaks = ({int current, int longest});

/// Walks the active days to find the run ending today/yesterday and the
/// longest run anywhere in the set.
_Streaks _streaks(Set<DateTime> activeDays, DateTime today) {
  if (activeDays.isEmpty) return (current: 0, longest: 0);

  final sorted = activeDays.toList()..sort();

  var longest = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].difference(sorted[i - 1]).inDays;
    run = gap == 1 ? run + 1 : 1;
    if (run > longest) longest = run;
  }

  // Count back from today. A streak survives one missed day only if that day
  // is today — i.e. yesterday still counts until today ends.
  var cursor = today;
  if (!activeDays.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!activeDays.contains(cursor)) return (current: 0, longest: longest);
  }

  var current = 0;
  while (activeDays.contains(cursor)) {
    current++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return (current: current, longest: longest);
}

class _TopicAccumulator {
  _TopicAccumulator(this.name);

  final String name;
  int questions = 0;
  int checksAnswered = 0;
  int checksCorrect = 0;
  DateTime lastSeen = DateTime.fromMillisecondsSinceEpoch(0);

  void add(LearningEvent e) {
    switch (e.kind) {
      case LearningEventKind.question:
        questions++;
      case LearningEventKind.check:
        checksAnswered++;
        if (e.isCorrect ?? false) checksCorrect++;
    }
    if (e.createdAt.isAfter(lastSeen)) lastSeen = e.createdAt;
  }

  TopicStat build() => TopicStat(
        name: name,
        questions: questions,
        checksAnswered: checksAnswered,
        checksCorrect: checksCorrect,
        lastSeen: lastSeen,
      );
}
