import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:eduai/core/theme/app_theme.dart';
import 'package:eduai/features/progress/application/progress_providers.dart';
import 'package:eduai/features/progress/domain/entities/learning_event.dart';
import 'package:eduai/features/progress/domain/entities/progress_summary.dart';
import 'package:eduai/features/progress/presentation/screens/progress_screen.dart';
import 'package:eduai/features/progress/presentation/widgets/activity_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// DevicePreview renders the whole app inside a `LayoutBuilder`, so a subtree
/// that first mounts during that layout pass is built *during* `performLayout`.
/// Mounting an `OverlayPortal` there — which is what `Tooltip` and
/// `IconButton(tooltip:)` are — can trip
/// `_RenderTheater._addDeferredChild: '!_skipMarkNeedsLayout'`.
///
/// The Progress screen is this app's worst case: the heatmap mounts a grid of
/// 100+ tooltipped cells at once once async data arrives. This test pins that
/// combination so a regression surfaces here rather than as a screenful of red
/// in the previewer.
List<LearningEvent> _events() {
  final now = DateTime.now();
  return [
    for (var day = 0; day < 30; day++)
      LearningEvent(
        id: 'q$day',
        kind: LearningEventKind.question,
        createdAt: now.subtract(Duration(days: day)),
        subject: 'Algebra',
        topic: 'Algebra',
      ),
  ];
}

void main() {
  testWidgets('Progress screen mounts inside DevicePreview without asserting',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final summary = ProgressSummary.fromEvents(_events());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressSummaryProvider.overrideWith((ref) async => summary),
        ],
        child: DevicePreview(
          enabled: true,
          // Mirrors lib/app/app.dart so the test exercises the real wiring.
          builder: (context) => MaterialApp(
            theme: AppTheme.light(),
            locale: DevicePreview.locale(context),
            builder: DevicePreview.appBuilder,
            home: const ProgressScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActivityHeatmap), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
