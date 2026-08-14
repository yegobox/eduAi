import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/detail_scaffold.dart';
import '../../../../core/ink/ink_canvas.dart';
import '../../../../core/ink/ink_controller.dart';
import '../../../../core/ink/ink_stroke.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../application/lessons_providers.dart';
import '../../domain/entities/lesson.dart';

/// Reading view for one lesson, with a highlighter overlay so students can
/// mark up the text with a stylus, and a completion action that feeds
/// Progress.
class LessonReaderScreen extends ConsumerStatefulWidget {
  const LessonReaderScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonReaderScreen> createState() => _LessonReaderScreenState();
}

class _LessonReaderScreenState extends ConsumerState<LessonReaderScreen> {
  /// Annotations live as long as this screen does. Persisting them across
  /// sessions is a data-model decision that has not been taken yet.
  final _ink = InkController();
  bool _annotating = false;

  @override
  void dispose() {
    _ink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final lesson = ref.watch(lessonByIdProvider(widget.lessonId)).valueOrNull;

    if (lesson == null) {
      return const DetailScaffold(
        title: 'Lesson',
        child: Center(child: Text('That lesson is no longer in the library.')),
      );
    }

    return DetailScaffold(
      title: lesson.title,
      bottomBar: _CompleteButton(lesson: lesson),
      child: ListView(
        children: [
          Row(
            children: [
              AppBadge(lesson.subject, tone: AppTone.neutral),
              if (lesson.rebAligned) ...[
                const SizedBox(width: 8),
                const AppBadge('REB aligned'),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Stack(
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final paragraph in lesson.body)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          paragraph,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.7,
                            color: t.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_annotating)
                Positioned.fill(
                  child: InkCanvas(
                    key: const Key('lesson-annotation-canvas'),
                    controller: _ink,
                    tool: InkTool.highlighter,
                    color: InkColor.highlight,
                    background: Colors.transparent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => setState(() => _annotating = !_annotating),
                  style: _annotating
                      ? null
                      : FilledButton.styleFrom(
                          backgroundColor: t.brandSoft,
                          foregroundColor: t.brand,
                        ),
                  icon: const Icon(Icons.brush_outlined, size: 16),
                  label: Text(
                    _annotating
                        ? 'Annotating — tap to stop'
                        : 'Annotate with pen',
                  ),
                ),
                if (_annotating)
                  OutlinedButton.icon(
                    onPressed: _ink.clear,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Clear marks'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompleteButton extends ConsumerWidget {
  const _CompleteButton({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lesson.completed) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle_outline, size: 16),
        label: const Text('Marked complete — nice work'),
      );
    }
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () =>
            ref.read(lessonsActionControllerProvider).markComplete(lesson.id),
        icon: const Icon(Icons.check_circle_outline, size: 16),
        label: const Text('Mark as complete'),
      ),
    );
  }
}
