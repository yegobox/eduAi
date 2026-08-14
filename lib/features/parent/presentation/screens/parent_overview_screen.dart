import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../access/presentation/widgets/access_gate.dart';
import '../../application/parent_providers.dart';
import '../../domain/entities/parent_entities.dart';
import '../widgets/child_switcher.dart';

/// The parent's landing surface: this week at a glance, what needs
/// encouragement, recent activity, and a reassurance that outages are fine.
class ParentOverviewScreen extends ConsumerWidget {
  const ParentOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(parentChildrenProvider);

    return ShellContent(
      child: AsyncValueView<List<Child>>(
        value: children,
        onRetry: () => ref.invalidate(parentChildrenProvider),
        isEmpty: (list) => list.isEmpty,
        // The empty state now offers the fix rather than telling a parent to
        // go and ask somebody: either direction of linking starts here.
        emptyBuilder: () => TrustBanner(
          icon: Icons.family_restroom_outlined,
          title: 'No children linked yet',
          body:
              "Enter the code your child's school gave you, or send your own "
              'code for your child to type in. Their weekly report appears '
              'here once you are linked.',
          action: FilledButton(
            key: const Key('overview-link-child'),
            onPressed: () => context.push(AppRoutes.family),
            child: const Text('Link a child'),
          ),
        ),
        data: (_) {
          final child = ref.watch(selectedChildProvider);
          if (child == null) return const SizedBox.shrink();
          return ListView(
            children: [
              const AccessNotice(),
              const ChildSwitcher(),
              const SizedBox(height: 12),
              _StatRow(child: child),
              const SizedBox(height: 16),
              _AttentionCard(child: child),
              const SizedBox(height: 16),
              const SectionTitle('Recent activity'),
              const SizedBox(height: 8),
              _ActivityCard(entries: child.recentActivity),
              const SizedBox(height: 16),
              TrustBanner(
                icon: Icons.cloud_off,
                title: 'Works without internet',
                body:
                    "${child.firstName}'s lessons keep working through "
                    'outages — progress syncs automatically once back online.',
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(
            value: '${child.minutesThisWeek}',
            label: 'minutes this week',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            value: '${child.questionsAsked}',
            label: 'questions asked',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatTile(
            value: '${child.streakDays}d',
            label: 'current streak',
          ),
        ),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.child});

  final Child child;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: t.ink2),
              const SizedBox(width: 8),
              Text(
                'Needs a little attention',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: t.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (child.attention.isEmpty)
            Text(
              'Nothing is falling behind this week — say well done.',
              style: TextStyle(fontSize: 13, color: t.ink2),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in child.attention)
                  SoftChip(item, tone: AppTone.warning),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.entries});

  final List<ActivityEntry> entries;

  static IconData _iconFor(ActivityKind kind) => switch (kind) {
    ActivityKind.tutor => Icons.auto_awesome_outlined,
    ActivityKind.lesson => Icons.menu_book_outlined,
    ActivityKind.workbook => Icons.edit_outlined,
    ActivityKind.check => Icons.check_circle_outline,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    if (entries.isEmpty) {
      return AppCard(
        child: Text(
          'No activity recorded yet this week.',
          style: TextStyle(fontSize: 13, color: t.ink3),
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: i == entries.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: t.border)),
              ),
              child: Row(
                children: [
                  IconTile(
                    icon: _iconFor(entries[i].kind),
                    tone: AppTone.neutral,
                    size: 34,
                    iconSize: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entries[i].text,
                      style: TextStyle(fontSize: 13.5, color: t.ink),
                    ),
                  ),
                  Text(
                    Formatters.relative(entries[i].at),
                    style: TextStyle(fontSize: 12, color: t.ink3),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
