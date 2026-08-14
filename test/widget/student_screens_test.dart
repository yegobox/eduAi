import 'package:eduai/core/ink/ink_canvas.dart';
import 'package:eduai/core/widgets/mastery_ring.dart';
import 'package:eduai/features/auth/domain/entities/app_user.dart';
import 'package:eduai/features/auth/domain/entities/auth_session.dart';
import 'package:eduai/features/progress/application/progress_providers.dart';
import 'package:eduai/features/progress/domain/entities/learning_event.dart';
import 'package:eduai/features/progress/domain/entities/progress_summary.dart';
import 'package:eduai/features/workbook/application/workbook_controller.dart';
import 'package:eduai/features/workbook/domain/entities/workbook_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';
import '../support/harness.dart';

const _session = AuthSession(
  user: AppUser(id: 'u1', displayName: 'Mura'),
  provider: AuthProvider.supabaseEmail,
);

List<LearningEvent> _events() {
  final now = DateTime.now();
  return [
    for (var day = 0; day < 6; day++) ...[
      LearningEvent(
        id: 'q$day',
        kind: LearningEventKind.question,
        subject: day.isEven ? 'Mathematics' : 'English',
        createdAt: now.subtract(Duration(days: day)),
      ),
      LearningEvent(
        id: 'c$day',
        kind: LearningEventKind.check,
        subject: day.isEven ? 'Mathematics' : 'English',
        isCorrect: day % 3 != 0,
        createdAt: now.subtract(Duration(days: day)),
      ),
    ],
  ];
}

Future<AppUnderTest> pumpStudent(
  WidgetTester tester, {
  Size size = desktopSize,
  List<Override> extraOverrides = const [],
}) {
  return pumpApp(
    tester,
    auth: FakeAuthRepository(initialSession: _session),
    size: size,
    extraOverrides: extraOverrides,
  );
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('Home', () {
    testWidgets('greets the student and offers the four feature cards', (
      tester,
    ) async {
      await pumpStudent(tester);
      expect(find.textContaining('Hello, Mura'), findsOneWidget);
      expect(find.text('Continue learning'), findsOneWidget);
      expect(find.text('Solve by hand with a pen or stylus.'), findsOneWidget);
      expect(find.text('My schools & classes'), findsOneWidget);
    });

    testWidgets('nudges the student to set an offline PIN', (tester) async {
      await pumpStudent(tester);
      expect(find.text('Set up offline access'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Set PIN'), findsOneWidget);
    });

    testWidgets('hides the nudge once a PIN exists', (tester) async {
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session, offlinePin: '1234'),
      );
      expect(find.text('Set up offline access'), findsNothing);
    });

    testWidgets('a feature card jumps to that tab', (tester) async {
      await pumpStudent(tester);
      await tester.tap(find.text('Workbook').first);
      await tester.pumpAndSettle();
      expect(find.byType(InkCanvas), findsOneWidget);
    });

    testWidgets('lays out on a phone-sized window', (tester) async {
      await pumpStudent(tester, size: mobileSize);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Hello, Mura'), findsOneWidget);
    });
  });

  group('Lessons', () {
    testWidgets('filters the catalog by grade band', (tester) async {
      await pumpStudent(tester);
      await openTab(tester, 'Lessons');

      expect(find.text('Fractions: adding like denominators'), findsOneWidget);
      expect(find.text('Cell structure & function'), findsNothing);

      await tester.tap(find.text('O-Level'));
      await tester.pumpAndSettle();

      expect(find.text('Cell structure & function'), findsOneWidget);
      expect(find.text('Fractions: adding like denominators'), findsNothing);
    });

    testWidgets('the download toggle flips without opening the lesson', (
      tester,
    ) async {
      await pumpStudent(tester);
      await openTab(tester, 'Lessons');

      expect(find.byIcon(Icons.download_outlined), findsWidgets);
      await tester.tap(find.byIcon(Icons.download_outlined).first);
      await tester.pumpAndSettle();

      // Still on the catalog, and one lesson now reads as downloaded.
      expect(find.text('P1–P6'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsWidgets);
    });

    testWidgets('opening a lesson shows its body and completion action', (
      tester,
    ) async {
      await pumpStudent(tester);
      await openTab(tester, 'Lessons');

      await tester.tap(find.text('The water cycle'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Water moves in a loop'), findsOneWidget);
      expect(find.text('REB ALIGNED'), findsWidgets);
      expect(
        find.widgetWithText(FilledButton, 'Mark as complete'),
        findsOneWidget,
      );
    });

    testWidgets('marking complete disables the action', (tester) async {
      await pumpStudent(tester);
      await openTab(tester, 'Lessons');
      await tester.tap(find.text('The water cycle'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark as complete'));
      await tester.pumpAndSettle();

      expect(find.text('Marked complete — nice work'), findsOneWidget);
    });

    testWidgets('the annotation overlay mounts only while annotating', (
      tester,
    ) async {
      await pumpStudent(tester);
      await openTab(tester, 'Lessons');
      await tester.tap(find.text('The water cycle'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('lesson-annotation-canvas')), findsNothing);

      await tester.tap(find.text('Annotate with pen'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-annotation-canvas')), findsOneWidget);
      expect(find.text('Clear marks'), findsOneWidget);

      await tester.tap(find.text('Annotating — tap to stop'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('lesson-annotation-canvas')), findsNothing);
    });
  });

  group('Workbook', () {
    testWidgets('renders the toolbar, pages and canvas', (tester) async {
      await pumpStudent(tester);
      await openTab(tester, 'Workbook');

      expect(find.byType(InkCanvas), findsOneWidget);
      expect(find.text('Grid'), findsOneWidget);
      expect(find.text('Lines'), findsOneWidget);
      expect(find.text('Plain'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Ask AI to check my work'),
        findsOneWidget,
      );
    });

    testWidgets('drawing lands on the active page only', (tester) async {
      await pumpStudent(tester);
      await openTab(tester, 'Workbook');

      final canvas = find.byType(InkCanvas);
      final gesture = await tester.startGesture(tester.getCenter(canvas));
      await gesture.moveBy(const Offset(40, 30));
      await gesture.up();
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InkCanvas)),
      );
      final controller = container.read(workbookControllerProvider.notifier);
      expect(controller.pageAt(0).strokeCount, 1);
      expect(controller.pageAt(1).isEmpty, isTrue);

      // Switching pages gives a fresh surface.
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(controller.activePage.isEmpty, isTrue);
    });

    testWidgets('undo and clear act on the drawing', (tester) async {
      await pumpStudent(tester);
      await openTab(tester, 'Workbook');

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkCanvas)),
      );
      await gesture.moveBy(const Offset(30, 20));
      await gesture.up();
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InkCanvas)),
      );
      final controller = container.read(workbookControllerProvider.notifier);
      expect(controller.activePage.strokeCount, 1);

      await tester.tap(find.byIcon(Icons.undo));
      await tester.pumpAndSettle();
      expect(controller.activePage.isEmpty, isTrue);

      await tester.tap(find.byIcon(Icons.redo));
      await tester.pumpAndSettle();
      expect(controller.activePage.strokeCount, 1);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(controller.activePage.isEmpty, isTrue);
    });

    testWidgets('checking a blank page asks for working first', (tester) async {
      await pumpStudent(tester);
      await openTab(tester, 'Workbook');

      await tester.tap(find.text('Ask AI to check my work'));
      await tester.pumpAndSettle();

      expect(
        find.text('Write some working on the page first.'),
        findsOneWidget,
      );
    });

    testWidgets('a returned verdict replaces the button with feedback', (
      tester,
    ) async {
      await pumpStudent(
        tester,
        extraOverrides: [
          workbookCheckRepositoryProvider.overrideWithValue(
            FakeWorkbookCheckRepository(),
          ),
        ],
      );
      await openTab(tester, 'Workbook');

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkCanvas)),
      );
      await gesture.moveBy(const Offset(40, 40));
      await gesture.up();
      await tester.pumpAndSettle();

      // Rasterising the page needs the real raster thread, which the
      // fake-async test zone does not run — drive the check outside it.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(InkCanvas)),
      );
      await tester.runAsync(
        () => container
            .read(workbookControllerProvider.notifier)
            .checkWork(const Size(300, 200)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nice work — step 2 has a small slip'), findsOneWidget);
      expect(find.text('Ask AI to check my work'), findsNothing);
    });

    testWidgets('a found mistake is not dressed up as a success', (
      tester,
    ) async {
      await pumpStudent(
        tester,
        extraOverrides: [
          workbookCheckRepositoryProvider.overrideWithValue(
            FakeWorkbookCheckRepository(
              feedback: const WorkbookFeedback(
                verdict: 'Step 2 divides by 2 but keeps the minus sign.',
                tip: 'Redo that line and watch the sign.',
                status: WorkbookVerdictStatus.mistake,
              ),
            ),
          ),
        ],
      );
      await openTab(tester, 'Workbook');

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(InkCanvas)),
      );
      await gesture.moveBy(const Offset(40, 40));
      await gesture.up();
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InkCanvas)),
      );
      await tester.runAsync(
        () => container
            .read(workbookControllerProvider.notifier)
            .checkWork(const Size(300, 200)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
    });

    testWidgets('switching tool and colour updates the toolbar state', (
      tester,
    ) async {
      await pumpStudent(tester);
      await openTab(tester, 'Workbook');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(InkCanvas)),
      );

      await tester.tap(find.byIcon(Icons.auto_fix_normal_outlined));
      await tester.pumpAndSettle();
      expect(container.read(workbookControllerProvider).tool.name, 'eraser');

      await tester.tap(find.text('Lines'));
      await tester.pumpAndSettle();
      expect(container.read(workbookControllerProvider).guide.name, 'lines');
    });
  });

  group('Progress', () {
    testWidgets('shows mastery rings, the streak row and readiness', (
      tester,
    ) async {
      await pumpStudent(
        tester,
        extraOverrides: [
          progressSummaryProvider.overrideWith(
            (ref) async => ProgressSummary.fromEvents(_events()),
          ),
        ],
      );
      await openTab(tester, 'Progress');

      expect(find.text('Mastery by subject'), findsOneWidget);
      expect(find.byType(MasteryRing), findsWidgets);
      expect(find.text('7-day streak'), findsOneWidget);
      expect(find.text('REB exam readiness'), findsOneWidget);
      expect(find.text('Share weekly report with parent'), findsOneWidget);
    });

    testWidgets('invites the student in when nothing is recorded yet', (
      tester,
    ) async {
      await pumpStudent(
        tester,
        extraOverrides: [
          progressSummaryProvider.overrideWith(
            (ref) async => ProgressSummary.empty,
          ),
        ],
      );
      await openTab(tester, 'Progress');

      expect(find.text('Your mastery rings start here'), findsOneWidget);
      expect(find.byType(MasteryRing), findsNothing);
    });

    testWidgets('the share switch persists its new value', (tester) async {
      await pumpStudent(
        tester,
        extraOverrides: [
          progressSummaryProvider.overrideWith(
            (ref) async => ProgressSummary.fromEvents(_events()),
          ),
        ],
      );
      await openTab(tester, 'Progress');

      final switchFinder = find.descendant(
        of: find.byKey(const Key('progress-share-switch')),
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(switchFinder).value, isFalse);
    });
  });

  group('Tutor scratchpad', () {
    testWidgets('the pen button opens a pad that attaches working', (
      tester,
    ) async {
      final tutor = FakeTutorRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        tutor: tutor,
      );
      await openTab(tester, 'Tutor');

      expect(find.byKey(const Key('tutor-scratchpad-canvas')), findsNothing);

      await tester.tap(find.byKey(const Key('tutor-pen-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('tutor-scratchpad-canvas')), findsOneWidget);
      expect(find.text('Show your work'), findsOneWidget);

      await tester.tap(find.byKey(const Key('tutor-attach-button')));
      await tester.pumpAndSettle();

      expect(tutor.askedMessages, ['Can you check my handwritten working?']);
      // The pad closes once the working is sent.
      expect(find.byKey(const Key('tutor-scratchpad-canvas')), findsNothing);
    });

    testWidgets('the subject/level sheet records tutor context', (
      tester,
    ) async {
      final tutor = FakeTutorRepository();
      await pumpApp(
        tester,
        auth: FakeAuthRepository(initialSession: _session),
        tutor: tutor,
      );
      await openTab(tester, 'Tutor');

      await tester.tap(find.text('Set subject & level'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('tutor-subject-field')),
        'Biology',
      );
      await tester.enterText(
        find.byKey(const Key('tutor-level-field')),
        'O-Level',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('O-Level'), findsOneWidget);
    });
  });
}
