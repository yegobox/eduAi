import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../progress/application/mastery_providers.dart';
import '../../application/parent_providers.dart';
import '../widgets/child_switcher.dart';

/// Per-subject mastery trends. Deliberately not a list of wrong answers — the
/// student's share switch gates this whole screen.
class ParentReportsScreen extends ConsumerWidget {
  const ParentReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final child = ref.watch(selectedChildProvider);
    final shared = ref.watch(progressSharingProvider).valueOrNull ?? true;

    if (child == null) {
      return const ShellContent(
        child: TrustBanner(
          icon: Icons.insights_outlined,
          title: 'No reports yet',
          body: 'Reports appear once your child is linked to your account.',
        ),
      );
    }

    return ShellContent(
      child: ListView(
        children: [
          const ChildSwitcher(),
          const SizedBox(height: 12),
          if (!shared)
            const TrustBanner(
              icon: Icons.visibility_off_outlined,
              title: 'Sharing is turned off',
              body:
                  'Your child has paused weekly report sharing from their '
                  'Progress screen. Nothing else is hidden from you.',
            )
          else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle("This week's report"),
                  const SizedBox(height: 12),
                  for (final entry in child.subjectMastery.entries) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: t.ink,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.percent(entry.value),
                          style: TextStyle(fontSize: 13.5, color: t.ink3),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    BarTrack(value: entry.value),
                    const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Reports show mastery trends, not every wrong answer — so you '
              'can encourage without piling on pressure.',
              style: TextStyle(fontSize: 13, color: t.ink2),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
