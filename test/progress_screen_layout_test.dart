import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/features/progress/application/progress_providers.dart';
import 'package:eduai/features/progress/domain/entities/learning_event.dart';
import 'package:eduai/features/progress/domain/entities/progress_summary.dart';
import 'package:eduai/features/progress/presentation/screens/progress_screen.dart';
import 'package:eduai/features/progress/presentation/widgets/activity_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A busy history: 40 days of activity across three subjects, with a live
/// streak running into today.
List<LearningEvent> _sampleEvents() {
  final now = DateTime.now();
  final subjects = ['Algebra', 'Biology', 'History'];
  final events = <LearningEvent>[];

  for (var day = 0; day < 40; day++) {
    // Leave a gap so the current and longest streaks differ.
    if (day > 3 && day < 7) continue;
    final at = now.subtract(Duration(days: day));
    final subject = subjects[day % subjects.length];

    events.add(LearningEvent(
      id: 'q$day',
      kind: LearningEventKind.question,
      createdAt: at,
      subject: subject,
      topic: subject,
    ));
    events.add(LearningEvent(
      id: 'c$day',
      kind: LearningEventKind.check,
      createdAt: at,
      subject: subject,
      topic: subject,
      isCorrect: day.isEven,
    ));
  }
  return events;
}

Future<void> _pumpProgress(
  WidgetTester tester, {
  required ProgressSummary summary,
  required Size size,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        progressSummaryProvider.overrideWith((ref) async => summary),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const ProgressScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final populated = ProgressSummary.fromEvents(_sampleEvents());

  group('ProgressScreen layout', () {
    testWidgets('renders the full dashboard on a desktop window',
        (tester) async {
      await _pumpProgress(
        tester,
        summary: populated,
        size: const Size(1400, 1000),
      );

      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('day streak'), findsOneWidget);
      expect(find.text('Questions asked'), findsOneWidget);
      expect(find.text('Checks answered'), findsOneWidget);
      expect(find.text('Check accuracy'), findsOneWidget);
      expect(find.text('Study activity'), findsOneWidget);
      expect(find.byType(ActivityHeatmap), findsOneWidget);
      expect(find.text('Topics covered'), findsOneWidget);
      // Topics are grouped by subject, newest first.
      expect(find.text('Algebra'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a narrow phone window without overflowing',
        (tester) async {
      await _pumpProgress(
        tester,
        summary: populated,
        size: const Size(360, 800),
      );

      expect(find.byType(ActivityHeatmap), findsOneWidget);
      // The stat tiles stack rather than squeeze at this width.
      expect(find.text('Questions asked'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the empty state before any activity', (tester) async {
      await _pumpProgress(
        tester,
        summary: ProgressSummary.empty,
        size: const Size(900, 800),
      );

      expect(find.text('No progress yet'), findsOneWidget);
      expect(find.text('Open the tutor'), findsOneWidget);
      expect(find.byType(ActivityHeatmap), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('accuracy reads as a dash, not 0%, with no checks answered',
        (tester) async {
      final noChecks = ProgressSummary.fromEvents([
        LearningEvent(
          id: 'q1',
          kind: LearningEventKind.question,
          createdAt: DateTime.now(),
          subject: 'Physics',
          topic: 'Physics',
        ),
      ]);

      await _pumpProgress(
        tester,
        summary: noChecks,
        size: const Size(900, 800),
      );

      expect(find.text('—'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
