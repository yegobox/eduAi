import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../application/progress_providers.dart';
import '../../domain/entities/progress_summary.dart';
import '../widgets/activity_heatmap.dart';

/// Mastery over time, derived entirely from recorded learning events.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  static const _maxContentWidth = 760.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(progressSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(progressSummaryProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: AsyncValueView<ProgressSummary>(
              value: summary,
              onRetry: () => ref.invalidate(progressSummaryProvider),
              isEmpty: (s) => !s.hasActivity,
              emptyBuilder: () => const _EmptyState(),
              data: (s) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(progressSummaryProvider),
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _StreakHero(summary: s),
                    const SizedBox(height: 20),
                    _StatTileRow(summary: s),
                    const SizedBox(height: 28),
                    _Section(
                      title: 'Study activity',
                      subtitle: '${s.activeDays} '
                          '${s.activeDays == 1 ? 'day' : 'days'} studied',
                      child: ActivityHeatmap(dailyCounts: s.dailyCounts),
                    ),
                    const SizedBox(height: 28),
                    _Section(
                      title: 'Topics covered',
                      subtitle: '${s.topics.length} '
                          '${s.topics.length == 1 ? 'topic' : 'topics'}',
                      child: _TopicList(topics: s.topics),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The headline figure. A streak is a single number about right now, so it
/// gets a hero treatment rather than a chart.
class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final streak = summary.currentStreak;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.local_fire_department,
              size: 40,
              color: scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$streak',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onPrimaryContainer,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'day streak',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    streak == 0
                        ? 'Ask the tutor something today to start a new streak.'
                        : 'Longest so far: ${summary.longestStreak} '
                            '${summary.longestStreak == 1 ? 'day' : 'days'}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTileRow extends StatelessWidget {
  const _StatTileRow({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final accuracy = summary.accuracy;
    final tiles = [
      (
        Icons.help_outline,
        '${summary.totalQuestions}',
        summary.totalQuestions == 1 ? 'Question asked' : 'Questions asked',
      ),
      (
        Icons.quiz_outlined,
        '${summary.checksAnswered}',
        summary.checksAnswered == 1 ? 'Check answered' : 'Checks answered',
      ),
      (
        Icons.track_changes_outlined,
        // An unanswered check is not the same as scoring zero.
        accuracy == null ? '—' : '${(accuracy * 100).round()}%',
        'Check accuracy',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 420;
        final children = [
          for (final (icon, value, label) in tiles)
            _StatTile(icon: icon, value: value, label: label),
        ];
        return stacked
            ? Column(
                children: [
                  for (final child in children)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: child,
                    ),
                ],
              )
            // IntrinsicHeight bounds the row before `stretch` is applied —
            // stretching inside the unbounded ListView would otherwise force
            // an infinite height on the tiles.
            : IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: children[i]),
                    ],
                  ],
                ),
              );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Both flexible so a long title or count ellipsises instead of
            // overflowing on a narrow window.
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ],
    );
  }
}

class _TopicList extends StatelessWidget {
  const _TopicList({required this.topics});

  final List<TopicStat> topics;

  /// Keeps the card scannable; the count in the section header still reports
  /// the true total, so nothing is silently hidden.
  static const _maxShown = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (topics.isEmpty) {
      return Text(
        'Topics appear here once you start asking questions.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    final shown = topics.take(_maxShown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _TopicRow(topic: shown[i]),
        ],
        if (topics.length > shown.length) ...[
          const SizedBox(height: 16),
          Text(
            '+ ${topics.length - shown.length} more',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic});

  final TopicStat topic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accuracy = topic.accuracy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                topic.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            // Values wear ink tokens, never the mark colour.
            Text(
              accuracy == null
                  ? '${topic.totalEvents}×'
                  : '${(accuracy * 100).round()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _MasteryMeter(accuracy: accuracy),
        const SizedBox(height: 4),
        Text(
          accuracy == null
              ? '${topic.questions} asked · no checks answered yet'
              : '${topic.checksCorrect}/${topic.checksAnswered} checks correct · '
                  '${topic.questions} asked',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// A thin single-series meter with rounded data-ends anchored to the track.
class _MasteryMeter extends StatelessWidget {
  const _MasteryMeter({required this.accuracy});

  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: scheme.surfaceContainerHighest),
            ),
            if (accuracy != null)
              FractionallySizedBox(
                widthFactor: accuracy!.clamp(0.0, 1.0),
                child: ColoredBox(color: scheme.primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No progress yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the tutor a question or answer a quick check, and your '
              'streak, accuracy and topics will show up here.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.push(AppRoutes.tutor),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Open the tutor'),
            ),
          ],
        ),
      ),
    );
  }
}
