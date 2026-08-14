import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../application/lessons_providers.dart';
import '../../domain/entities/lesson.dart';

/// The REB-aligned curriculum library: a grade-band filter row over a
/// responsive card grid, each card downloadable for offline reading.
class LessonsScreen extends ConsumerWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final band = ref.watch(gradeFilterProvider);
    final lessons = ref.watch(filteredLessonsProvider);

    return ShellContent(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: GradeBand.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final value = GradeBand.values[i];
                return Center(
                  child: SoftChip(
                    value.label,
                    selected: value == band,
                    onTap: () =>
                        ref.read(gradeFilterProvider.notifier).state = value,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncValueView<List<Lesson>>(
              value: lessons,
              onRetry: () => ref.invalidate(lessonsCatalogProvider),
              isEmpty: (list) => list.isEmpty,
              emptyBuilder: () => Center(
                child: Text(
                  'No lessons in ${band.label} yet.',
                  style: TextStyle(color: AppTokens.read(context).ink3),
                ),
              ),
              data: (list) => GridView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 224,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: list.length,
                itemBuilder: (_, i) => LessonCard(lesson: list[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One catalog tile: cover, subject, title, REB badge and a download toggle
/// that does not open the lesson.
class LessonCard extends ConsumerWidget {
  const LessonCard({super.key, required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push(AppRoutes.lessonReader(lesson.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder cover art — swap for real subject illustrations.
          Container(
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [t.brandSoft, t.surfaceSunken],
              ),
            ),
            child: Icon(Icons.menu_book_outlined, size: 26, color: t.brand),
          ),
          const SizedBox(height: 10),
          Text(
            lesson.subject.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: t.ink3,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(
              lesson.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: t.ink,
              ),
            ),
          ),
          Row(
            children: [
              if (lesson.rebAligned) const AppBadge('REB aligned'),
              if (lesson.completed) ...[
                const SizedBox(width: 6),
                const AppBadge('Done', tone: AppTone.success),
              ],
              const Spacer(),
              ToolIconButton(
                icon: lesson.downloaded
                    ? Icons.check_circle_outline
                    : Icons.download_outlined,
                active: lesson.downloaded,
                tone: AppTone.success,
                size: 32,
                tooltip: lesson.downloaded
                    ? 'Remove download'
                    : 'Download for offline',
                onPressed: () => ref
                    .read(lessonsActionControllerProvider)
                    .toggleDownload(lesson),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
