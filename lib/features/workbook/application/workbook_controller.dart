import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/config_providers.dart';
import '../../../core/error/failure.dart';
import '../../../core/ink/ink_controller.dart';
import '../../../core/ink/ink_raster.dart';
import '../../../core/ink/ink_stroke.dart';
import '../../../core/network/http_client_provider.dart';
import '../data/datasources/workbook_check_remote_data_source.dart';
import '../data/repositories/workbook_check_repository_impl.dart';
import '../domain/entities/workbook_feedback.dart';
import '../domain/repositories/workbook_check_repository.dart';

/// How many independent pages the notebook holds.
const int kWorkbookPageCount = 3;

/// The pen colours offered in the toolbar. Identities, not hexes — each one
/// resolves against the canvas' brightness so the default reads as graphite on
/// paper-white and as chalk on the dark surface.
const List<InkColor> kWorkbookColors = [
  InkColor.graphite,
  InkColor.blue,
  InkColor.red,
  InkColor.green,
  InkColor.amber,
];

/// Toolbar selection + AI-check status. The strokes themselves live in the
/// per-page [InkController]s, which are mutable by design.
class WorkbookState extends Equatable {
  const WorkbookState({
    this.tool = InkTool.pen,
    this.color = InkColor.graphite,
    this.guide = InkGuide.grid,
    this.page = 0,
    this.checking = false,
    this.feedback,
    this.failure,
  });

  final InkTool tool;
  final InkColor color;
  final InkGuide guide;
  final int page;
  final bool checking;
  final WorkbookFeedback? feedback;
  final Failure? failure;

  WorkbookState copyWith({
    InkTool? tool,
    InkColor? color,
    InkGuide? guide,
    int? page,
    bool? checking,
    WorkbookFeedback? feedback,
    bool clearFeedback = false,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return WorkbookState(
      tool: tool ?? this.tool,
      color: color ?? this.color,
      guide: guide ?? this.guide,
      page: page ?? this.page,
      checking: checking ?? this.checking,
      feedback: clearFeedback ? null : (feedback ?? this.feedback),
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [
    tool,
    color,
    guide,
    page,
    checking,
    feedback,
    failure,
  ];
}

/// Holds the notebook: one [InkController] per page plus the toolbar state.
///
/// Not auto-disposed — a student who flips to the Tutor to ask a question and
/// comes back must find their working exactly where they left it.
class WorkbookController extends Notifier<WorkbookState> {
  final List<InkController> _pages = List.generate(
    kWorkbookPageCount,
    (_) => InkController(),
  );

  @override
  WorkbookState build() {
    ref.onDispose(() {
      for (final page in _pages) {
        page.dispose();
      }
    });
    return const WorkbookState();
  }

  /// The ink surface for the currently selected page.
  InkController get activePage => _pages[state.page];

  InkController pageAt(int index) => _pages[index];

  void selectTool(InkTool tool) => state = state.copyWith(tool: tool);

  /// Picking a colour implies you want to write with it, so it also switches
  /// back to the pen (the eraser and highlighter ignore colour otherwise).
  void selectColor(InkColor color) =>
      state = state.copyWith(color: color, tool: InkTool.pen);

  void selectGuide(InkGuide guide) => state = state.copyWith(guide: guide);

  void selectPage(int page) {
    if (page < 0 || page >= kWorkbookPageCount || page == state.page) return;
    // Feedback belongs to the page it was written about.
    state = state.copyWith(page: page, clearFeedback: true, clearFailure: true);
  }

  void undo() => activePage.undo();

  void redo() => activePage.redo();

  void clear() {
    activePage.clear();
    state = state.copyWith(clearFeedback: true, clearFailure: true);
  }

  void dismissFeedback() =>
      state = state.copyWith(clearFeedback: true, clearFailure: true);

  /// Rasterises the current page and asks the AI to check the working.
  Future<void> checkWork(Size canvasSize) async {
    if (state.checking) return;
    if (activePage.isEmpty) {
      state = state.copyWith(
        failure: const ValidationFailure(
          'Write some working on the page first.',
        ),
        clearFeedback: true,
      );
      return;
    }

    state = state.copyWith(
      checking: true,
      clearFeedback: true,
      clearFailure: true,
    );

    final Uint8List? png = await rasterizeStrokes(
      activePage.strokes,
      canvasSize,
    );
    if (png == null) {
      state = state.copyWith(
        checking: false,
        failure: const ValidationFailure('Could not read that page.'),
      );
      return;
    }

    final result = await ref.read(workbookCheckRepositoryProvider).check(png);
    result.when(
      success: (feedback) =>
          state = state.copyWith(checking: false, feedback: feedback),
      failure: (f) => state = state.copyWith(checking: false, failure: f),
    );
  }
}

final workbookControllerProvider =
    NotifierProvider<WorkbookController, WorkbookState>(WorkbookController.new);

final _workbookCheckRemoteProvider = Provider<WorkbookCheckRemoteDataSource>((
  ref,
) {
  return WorkbookCheckRemoteDataSource(
    ref.watch(httpClientProvider),
    ref.watch(appConfigProvider).dataConnectorUrl,
  );
});

final workbookCheckRepositoryProvider = Provider<WorkbookCheckRepository>((
  ref,
) {
  return WorkbookCheckRepositoryImpl(
    remoteSource: ref.watch(_workbookCheckRemoteProvider),
  );
});
