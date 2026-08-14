import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/mastery_ring.dart';
import '../../application/mastery_providers.dart';
import '../../application/progress_providers.dart';
import '../../domain/entities/mastery_view.dart';

/// Mastery over time, framed positively: rings per subject, a 7-day streak
/// row, REB exam readiness, and the parent-sharing switch.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(masteryViewProvider);

    return ShellContent(
      child: AsyncValueView<MasteryView>(
        value: view,
        onRetry: () => ref.invalidate(progressSummaryProvider),
        data: (v) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(progressSummaryProvider),
          child: ListView(
            children: [
              if (v.hasSubjects) ...[
                const SectionTitle('Mastery by subject'),
                const SizedBox(height: 10),
                _MasteryGrid(subjects: v.subjects),
                const SizedBox(height: 16),
              ] else ...[
                const _NoActivityCard(),
                const SizedBox(height: 16),
              ],
              _StreakCard(week: v.week, streak: v.currentStreak),
              const SizedBox(height: 16),
              _ReadinessCard(view: v),
              const SizedBox(height: 16),
              const _ShareCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasteryGrid extends StatelessWidget {
  const _MasteryGrid({required this.subjects});

  final List<SubjectMastery> subjects;

  /// Rings cycle through the semantic palette so neighbouring subjects stay
  /// distinguishable; the colour carries no judgement about the score.
  static const _tones = [
    AppTone.brand,
    AppTone.success,
    AppTone.warning,
    AppTone.danger,
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < subjects.length; i++)
          SizedBox(
            width: 152,
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MasteryRing(
                    value: subjects[i].mastery,
                    color: _tones[i % _tones.length].foreground(t),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subjects[i].name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NoActivityCard extends StatelessWidget {
  const _NoActivityCard();

  @override
  Widget build(BuildContext context) {
    return const TrustBanner(
      icon: Icons.insights_outlined,
      title: 'Your mastery rings start here',
      body:
          'Ask the AI Tutor a question or finish a lesson, and your subjects '
          'will show up on this screen.',
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.week, required this.streak});

  final List<StreakDay> week;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            '7-day streak',
            trailing: Text(
              streak == 0 ? 'Start today' : '$streak in a row',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: t.ink3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final day in week)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: day.active ? t.success : t.surfaceSunken,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      day.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: day.active ? Colors.white : t.ink3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard({required this.view});

  final MasteryView view;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'REB exam readiness',
            trailing: AppBadge('${view.examReadinessPercent}%'),
          ),
          const SizedBox(height: 10),
          BarTrack(value: view.examReadiness),
          const SizedBox(height: 10),
          Text(
            'Based on your concept checks and the lessons you have completed '
            'this term.',
            style: TextStyle(fontSize: 12.5, color: t.ink3),
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends ConsumerWidget {
  const _ShareCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared = ref.watch(progressSharingProvider).valueOrNull ?? true;
    return SwitchRow(
      key: const Key('progress-share-switch'),
      title: 'Share weekly report with parent',
      subtitle: 'Your parent will see mastery, not every mistake.',
      value: shared,
      onChanged: (value) =>
          ref.read(progressSharingProvider.notifier).setShared(value),
    );
  }
}
