import 'package:eduai/features/progress/domain/entities/learning_event.dart';
import 'package:eduai/features/progress/domain/entities/progress_summary.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fixed "today" so streak assertions never depend on when the suite runs.
final _today = DateTime(2026, 8, 11);

DateTime _daysAgo(int n) => _today.subtract(Duration(days: n));

var _seq = 0;

LearningEvent _question({
  required DateTime at,
  String? subject,
  String? topic,
}) {
  return LearningEvent(
    id: 'q${_seq++}',
    kind: LearningEventKind.question,
    createdAt: at,
    subject: subject,
    topic: topic,
  );
}

LearningEvent _check({
  required DateTime at,
  required bool correct,
  String? subject,
  String? topic,
}) {
  return LearningEvent(
    id: 'c${_seq++}',
    kind: LearningEventKind.check,
    createdAt: at,
    subject: subject,
    topic: topic,
    isCorrect: correct,
  );
}

void main() {
  setUp(() => _seq = 0);

  group('ProgressSummary counts', () {
    test('empty event list yields the empty summary', () {
      expect(ProgressSummary.fromEvents(const [], today: _today),
          ProgressSummary.empty);
      expect(ProgressSummary.empty.hasActivity, isFalse);
    });

    test('separates questions from checks and scores accuracy', () {
      final summary = ProgressSummary.fromEvents(
        [
          _question(at: _today),
          _question(at: _today),
          _check(at: _today, correct: true),
          _check(at: _today, correct: true),
          _check(at: _today, correct: false),
        ],
        today: _today,
      );

      expect(summary.totalQuestions, 2);
      expect(summary.checksAnswered, 3);
      expect(summary.checksCorrect, 2);
      expect(summary.accuracy, closeTo(2 / 3, 1e-9));
      expect(summary.hasActivity, isTrue);
    });

    test('accuracy is null — not zero — before any check is answered', () {
      final summary = ProgressSummary.fromEvents(
        [_question(at: _today)],
        today: _today,
      );
      expect(summary.checksAnswered, 0);
      expect(summary.accuracy, isNull);
    });

    test('dailyCounts buckets events by local calendar day', () {
      final summary = ProgressSummary.fromEvents(
        [
          _question(at: DateTime(2026, 8, 11, 9)),
          _question(at: DateTime(2026, 8, 11, 22)),
          _question(at: DateTime(2026, 8, 10, 7)),
        ],
        today: _today,
      );

      expect(summary.dailyCounts[DateTime(2026, 8, 11)], 2);
      expect(summary.dailyCounts[DateTime(2026, 8, 10)], 1);
      expect(summary.activeDays, 2);
    });
  });

  group('ProgressSummary streaks', () {
    test('counts consecutive days ending today', () {
      final summary = ProgressSummary.fromEvents(
        [
          _question(at: _daysAgo(0)),
          _question(at: _daysAgo(1)),
          _question(at: _daysAgo(2)),
        ],
        today: _today,
      );
      expect(summary.currentStreak, 3);
    });

    test('survives an empty today when yesterday was active', () {
      final summary = ProgressSummary.fromEvents(
        [_question(at: _daysAgo(1)), _question(at: _daysAgo(2))],
        today: _today,
      );
      // The day isn't over, so the streak is not broken yet.
      expect(summary.currentStreak, 2);
    });

    test('breaks once a full day has been missed', () {
      final summary = ProgressSummary.fromEvents(
        [_question(at: _daysAgo(2)), _question(at: _daysAgo(3))],
        today: _today,
      );
      expect(summary.currentStreak, 0);
      // …but the run still counts toward the record.
      expect(summary.longestStreak, 2);
    });

    test('longest streak spans gaps and can exceed the current one', () {
      final summary = ProgressSummary.fromEvents(
        [
          for (final d in [20, 19, 18, 17, 16]) _question(at: _daysAgo(d)),
          _question(at: _daysAgo(1)),
          _question(at: _daysAgo(0)),
        ],
        today: _today,
      );
      expect(summary.longestStreak, 5);
      expect(summary.currentStreak, 2);
    });

    test('several events on one day count as a single streak day', () {
      final summary = ProgressSummary.fromEvents(
        [
          _question(at: DateTime(2026, 8, 11, 8)),
          _question(at: DateTime(2026, 8, 11, 12)),
          _check(at: DateTime(2026, 8, 11, 18), correct: true),
        ],
        today: _today,
      );
      expect(summary.currentStreak, 1);
      expect(summary.longestStreak, 1);
    });
  });

  group('ProgressSummary topics', () {
    test('prefers the subject over the derived question topic', () {
      final summary = ProgressSummary.fromEvents(
        [
          _question(at: _today, subject: 'Biology', topic: 'Biology'),
          _question(at: _today, topic: 'why is the sky blue'),
        ],
        today: _today,
      );

      expect(
        summary.topics.map((t) => t.name),
        containsAll(['Biology', 'why is the sky blue']),
      );
    });

    test('groups case-insensitively and rolls up per-topic accuracy', () {
      final summary = ProgressSummary.fromEvents(
        [
          _question(at: _daysAgo(1), subject: 'Algebra'),
          _question(at: _daysAgo(1), subject: 'algebra'),
          _check(at: _daysAgo(1), correct: true, subject: 'ALGEBRA'),
          _check(at: _daysAgo(1), correct: false, subject: 'Algebra'),
        ],
        today: _today,
      );

      expect(summary.topics, hasLength(1));
      final algebra = summary.topics.single;
      expect(algebra.questions, 2);
      expect(algebra.checksAnswered, 2);
      expect(algebra.checksCorrect, 1);
      expect(algebra.accuracy, 0.5);
      expect(algebra.totalEvents, 4);
    });

    test('per-topic accuracy is null until a check is answered', () {
      final summary = ProgressSummary.fromEvents(
        [_question(at: _today, subject: 'History')],
        today: _today,
      );
      expect(summary.topics.single.accuracy, isNull);
    });

    test('sorts most-recently-studied first', () {
      final summary = ProgressSummary.fromEvents(
        [
          _question(at: _daysAgo(9), subject: 'Old'),
          _question(at: _daysAgo(1), subject: 'Recent'),
          _question(at: _daysAgo(5), subject: 'Middle'),
        ],
        today: _today,
      );

      expect(
        summary.topics.map((t) => t.name).toList(),
        ['Recent', 'Middle', 'Old'],
      );
    });

    test('events with no subject and no topic are not counted as a topic', () {
      final summary = ProgressSummary.fromEvents(
        [_question(at: _today)],
        today: _today,
      );
      expect(summary.topics, isEmpty);
      expect(summary.totalQuestions, 1);
    });
  });
}
