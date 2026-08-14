import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import 'progress_summary.dart';

/// How many recorded events count as full exposure to a subject. Below this,
/// mastery is discounted — three lucky answers is not mastery.
const int kFullExposureEvents = 8;

/// A subject's mastery ring on the Progress screen.
class SubjectMastery extends Equatable {
  const SubjectMastery({
    required this.name,
    required this.mastery,
    required this.events,
    required this.accuracy,
  });

  final String name;

  /// 0..1, already blended and clamped.
  final double mastery;

  /// How many questions + checks contributed.
  final int events;

  /// Raw check accuracy, null when no check has been answered yet.
  final double? accuracy;

  int get masteryPercent => (mastery * 100).round();

  @override
  List<Object?> get props => [name, mastery, events, accuracy];
}

/// One dot in the 7-day streak row.
class StreakDay extends Equatable {
  const StreakDay({
    required this.date,
    required this.label,
    required this.active,
  });

  final DateTime date;

  /// Single-letter weekday initial (M T W T F S S).
  final String label;

  final bool active;

  @override
  List<Object?> get props => [date, label, active];
}

/// Everything the redesigned Progress screen renders, derived in one pure
/// pass so it can be unit-tested without Supabase or a widget tree.
class MasteryView extends Equatable {
  const MasteryView({
    required this.subjects,
    required this.week,
    required this.examReadiness,
    required this.currentStreak,
  });

  static const empty = MasteryView(
    subjects: [],
    week: [],
    examReadiness: 0,
    currentStreak: 0,
  );

  final List<SubjectMastery> subjects;

  /// Seven days ending today, Monday-first.
  final List<StreakDay> week;

  /// 0..1 readiness for the REB exam.
  final double examReadiness;

  final int currentStreak;

  int get examReadinessPercent => (examReadiness * 100).round();

  bool get hasSubjects => subjects.isNotEmpty;

  /// Derives the view from recorded activity.
  ///
  /// [completedLessons] / [totalLessons] fold the lesson library into exam
  /// readiness — practice questions alone do not prove coverage.
  factory MasteryView.from(
    ProgressSummary summary, {
    int completedLessons = 0,
    int totalLessons = 0,
    DateTime? today,
  }) {
    final now = _dateOnly(today ?? DateTime.now());

    final subjects =
        summary.topics
            .map(
              (t) => SubjectMastery(
                name: t.name,
                mastery: _masteryFor(
                  accuracy: t.accuracy,
                  events: t.totalEvents,
                ),
                events: t.totalEvents,
                accuracy: t.accuracy,
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => b.events.compareTo(a.events));

    final activeDays = summary.dailyCounts.keys.map(_dateOnly).toSet();
    final week = [
      for (var back = 6; back >= 0; back--)
        () {
          final day = now.subtract(Duration(days: back));
          return StreakDay(
            date: day,
            label: _weekdayInitial(day.weekday),
            active: activeDays.contains(day),
          );
        }(),
    ];

    final masteryAverage = subjects.isEmpty
        ? 0.0
        : subjects.map((s) => s.mastery).reduce((a, b) => a + b) /
              subjects.length;
    final lessonRatio = totalLessons <= 0
        ? 0.0
        : completedLessons / totalLessons;

    return MasteryView(
      subjects: subjects,
      week: week,
      // Weighted toward demonstrated mastery, but curriculum coverage still
      // matters — an exam asks about topics you never opened.
      examReadiness: (0.7 * masteryAverage + 0.3 * lessonRatio).clamp(0.0, 1.0),
      currentStreak: summary.currentStreak,
    );
  }

  /// Blends check accuracy with how much of the subject has been touched.
  static double _masteryFor({required double? accuracy, required int events}) {
    if (events <= 0) return 0;
    final exposure = math.min(1.0, events / kFullExposureEvents);
    // No check answered yet: treat as neutral rather than zero, so asking
    // questions never *lowers* a ring.
    final rate = accuracy ?? 0.5;
    return (rate * (0.4 + 0.6 * exposure)).clamp(0.0, 1.0);
  }

  static String _weekdayInitial(int weekday) =>
      const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][weekday - 1];

  @override
  List<Object?> get props => [subjects, week, examReadiness, currentStreak];
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
