import 'dart:ui';

import 'package:eduai/core/error/failure.dart';
import 'package:eduai/core/ink/ink_stroke.dart';
import 'package:eduai/features/workbook/application/workbook_controller.dart';
import 'package:eduai/features/workbook/domain/entities/workbook_feedback.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeWorkbookCheckRepository checker;

  ProviderContainer boot() {
    final container = ProviderContainer(
      overrides: [workbookCheckRepositoryProvider.overrideWithValue(checker)],
    );
    addTearDown(container.dispose);
    // Keep the notifier alive across reads.
    container.listen(workbookControllerProvider, (_, _) {});
    return container;
  }

  setUp(() => checker = FakeWorkbookCheckRepository());

  void scribble(WorkbookController controller) {
    controller.activePage.begin(
      InkTool.pen,
      InkColor.graphite,
      const InkPoint(Offset(10, 10), 0.5),
    );
    controller.activePage.extend(const InkPoint(Offset(60, 40), 0.6));
    controller.activePage.extend(const InkPoint(Offset(90, 70), 0.7));
    controller.activePage.end();
  }

  test('starts on page 1 with the pen, grid guide and no feedback', () {
    final container = boot();
    final state = container.read(workbookControllerProvider);
    expect(state.tool, InkTool.pen);
    expect(state.guide, InkGuide.grid);
    expect(state.page, 0);
    expect(state.feedback, isNull);
    expect(state.checking, isFalse);
  });

  test('picking a colour switches back to the pen', () {
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);
    controller.selectTool(InkTool.eraser);
    expect(container.read(workbookControllerProvider).tool, InkTool.eraser);

    controller.selectColor(kWorkbookColors[1]);
    final state = container.read(workbookControllerProvider);
    expect(state.color, kWorkbookColors[1]);
    expect(state.tool, InkTool.pen);
  });

  test('each page keeps its own ink', () {
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);

    scribble(controller);
    expect(controller.activePage.strokeCount, 1);

    controller.selectPage(1);
    expect(controller.activePage.isEmpty, isTrue);

    controller.selectPage(0);
    expect(controller.activePage.strokeCount, 1);
  });

  test('page selection ignores out-of-range and no-op indices', () {
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);
    controller.selectPage(-1);
    controller.selectPage(kWorkbookPageCount);
    controller.selectPage(0);
    expect(container.read(workbookControllerProvider).page, 0);
  });

  test('undo, redo and clear act on the active page', () {
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);

    scribble(controller);
    controller.undo();
    expect(controller.activePage.isEmpty, isTrue);
    controller.redo();
    expect(controller.activePage.strokeCount, 1);
    controller.clear();
    expect(controller.activePage.isEmpty, isTrue);
  });

  test('guide switching sticks', () {
    final container = boot();
    container
        .read(workbookControllerProvider.notifier)
        .selectGuide(InkGuide.lines);
    expect(container.read(workbookControllerProvider).guide, InkGuide.lines);
  });

  test('refuses to check a blank page and never calls the checker', () async {
    final container = boot();
    await container
        .read(workbookControllerProvider.notifier)
        .checkWork(const Size(300, 200));

    final state = container.read(workbookControllerProvider);
    expect(state.failure, isA<ValidationFailure>());
    expect(state.checking, isFalse);
    expect(checker.calls, 0);
  });

  test('rasterises the page and shows the returned feedback', () async {
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);
    scribble(controller);

    await controller.checkWork(const Size(300, 200));

    final state = container.read(workbookControllerProvider);
    expect(state.checking, isFalse);
    expect(state.feedback?.verdict, contains('Nice work'));
    expect(state.failure, isNull);
    expect(checker.calls, 1);
    // A real PNG of the working was sent, not an empty buffer.
    expect(checker.lastImageBytes, greaterThan(100));
  });

  test('surfaces "not available yet" when the endpoint is missing', () async {
    checker = FakeWorkbookCheckRepository(
      failure: const OfflineUnsupportedFailure(
        message: 'Handwriting check is not available yet.',
      ),
    );
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);
    scribble(controller);

    await controller.checkWork(const Size(300, 200));

    final state = container.read(workbookControllerProvider);
    expect(state.feedback, isNull);
    expect(state.failure?.message, contains('not available yet'));
  });

  test('feedback belongs to the page it was written about', () async {
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);
    scribble(controller);
    await controller.checkWork(const Size(300, 200));
    expect(container.read(workbookControllerProvider).feedback, isNotNull);

    controller.selectPage(1);
    expect(container.read(workbookControllerProvider).feedback, isNull);
  });

  test('clearing a page drops its feedback', () async {
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);
    scribble(controller);
    await controller.checkWork(const Size(300, 200));

    controller.clear();
    expect(container.read(workbookControllerProvider).feedback, isNull);

    // …and dismissing works from any state.
    controller.dismissFeedback();
    expect(container.read(workbookControllerProvider).failure, isNull);
  });

  test('a second check while one is in flight is ignored', () async {
    final container = boot();
    final controller = container.read(workbookControllerProvider.notifier);
    scribble(controller);

    final first = controller.checkWork(const Size(300, 200));
    final second = controller.checkWork(const Size(300, 200));
    await Future.wait([first, second]);

    expect(checker.calls, 1);
  });

  test('WorkbookFeedback tolerates a partial payload', () {
    final parsed = WorkbookFeedback.fromJson(const {'tip': 'Watch the sign.'});
    expect(parsed.tip, 'Watch the sign.');
    expect(parsed.verdict, isNotEmpty);
  });
}
