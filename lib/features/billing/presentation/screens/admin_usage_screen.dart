import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../application/billing_providers.dart';
import '../../domain/entities/billing_entities.dart';

/// The numbers a head teacher takes into a renewal conversation.
class AdminUsageScreen extends ConsumerWidget {
  const AdminUsageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final usage = ref.watch(usageStatsProvider);

    return ShellContent(
      child: AsyncValueView<UsageStats>(
        value: usage,
        onRetry: () => ref.invalidate(usageStatsProvider),
        data: (u) => ListView(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 180,
                  child: StatTile(
                    value: Formatters.percent(u.activeStudentRatio),
                    label: 'students active this week',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: StatTile(
                    value: u.sessionsPerStudentPerWeek.toStringAsFixed(1),
                    label: 'tutor sessions / student / week',
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: StatTile(
                    value: '+${Formatters.percent(u.masteryLiftRatio)}',
                    label: 'mastery lift this term',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Row(
                children: [
                  Icon(Icons.star_outline, size: 18, color: t.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(fontSize: 13.5, color: t.ink),
                        children: [
                          const TextSpan(
                            text: 'Most-practised subject this month: ',
                          ),
                          TextSpan(
                            text: u.topSubject,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Usage like this is what your renewal conversation is built on — '
              'share it with your school board each term.',
              style: TextStyle(fontSize: 13, color: t.ink2),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
