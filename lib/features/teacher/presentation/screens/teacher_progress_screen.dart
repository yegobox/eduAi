import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../access/presentation/widgets/access_gate.dart';
import '../../application/teacher_providers.dart';
import '../../domain/entities/teacher_class.dart';

/// Who needs help, across every class this teacher runs.
///
/// Ordered by [StudentProgress.attentionRank] rather than alphabetically: the
/// point of this screen is to answer "who do I sit with on Monday", and that
/// answer should be the first row, not something to scroll for.
class TeacherProgressScreen extends ConsumerWidget {
  const TeacherProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final rows = ref.watch(teacherAttentionListProvider);

    return ShellContent(
      child: AsyncValueView<List<({TeacherClass klass, StudentProgress student})>>(
        value: rows,
        onRetry: () => ref.invalidate(teacherAttentionListProvider),
        isEmpty: (list) => list.isEmpty,
        emptyBuilder: () => const TrustBanner(
          icon: Icons.insights_outlined,
          title: 'Nothing to show yet',
          body: 'Once students in your classes start using the tutor, their '
              'activity appears here — newest concerns first.',
        ),
        data: (list) {
          final struggling =
              list.where((r) => r.student.attentionRank == 0).toList();
          final quiet = list.where((r) => r.student.attentionRank == 1).toList();
          final fine = list.where((r) => r.student.attentionRank == 2).toList();

          return ListView(
            children: [
              const AccessNotice(),
              _Summary(
                struggling: struggling.length,
                quiet: quiet.length,
                fine: fine.length,
              ),
              const SizedBox(height: 20),
              if (struggling.isNotEmpty) ...[
                const SectionTitle('Getting things wrong'),
                const SizedBox(height: 4),
                Text(
                  'More than 4 in 10 checks missed. Worth a conversation.',
                  style: TextStyle(fontSize: 12.5, color: t.ink3),
                ),
                const SizedBox(height: 10),
                for (final row in struggling) _Row(row: row),
                const SizedBox(height: 20),
              ],
              if (quiet.isNotEmpty) ...[
                const SectionTitle('Not started yet'),
                const SizedBox(height: 4),
                Text(
                  // Absent and struggling need different responses, so they are
                  // never mixed into one "needs attention" bucket.
                  'No activity in the last 30 days — absent, not struggling.',
                  style: TextStyle(fontSize: 12.5, color: t.ink3),
                ),
                const SizedBox(height: 10),
                for (final row in quiet) _Row(row: row),
                const SizedBox(height: 20),
              ],
              if (fine.isNotEmpty) ...[
                const SectionTitle('Doing fine'),
                const SizedBox(height: 10),
                for (final row in fine) _Row(row: row),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.struggling,
    required this.quiet,
    required this.fine,
  });

  final int struggling;
  final int quiet;
  final int fine;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatTile(value: '$struggling', label: 'need a hand'),
        ),
        const SizedBox(width: 12),
        Expanded(child: StatTile(value: '$quiet', label: 'not started')),
        const SizedBox(width: 12),
        Expanded(child: StatTile(value: '$fine', label: 'doing fine')),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final ({TeacherClass klass, StudentProgress student}) row;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final s = row.student;
    final accuracy = s.accuracy;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.studentName,
                    style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.klass.name,
                    style: TextStyle(fontSize: 12.5, color: t.ink3),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.isActive
                        ? '${s.questions} questions · ${s.checks} checks'
                              '${s.lastActive == null ? '' : ' · '
                                  '${Formatters.relative(s.lastActive!)}'}'
                        : 'No activity yet',
                    style: TextStyle(fontSize: 12, color: t.ink3),
                  ),
                ],
              ),
            ),
            // "0%" and "no checks yet" are different facts, so an untested
            // student never shows a score.
            if (accuracy == null)
              Text(
                '—',
                style: TextStyle(fontSize: 18, color: t.ink3),
              )
            else
              Text(
                Formatters.percent(accuracy),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accuracy < 0.6 ? t.warning : t.success,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
