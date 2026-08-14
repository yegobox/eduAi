import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/detail_scaffold.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../linking/application/linking_providers.dart';
import '../../application/teacher_providers.dart';
import '../../domain/entities/teacher_class.dart';

/// One class: its join code, its roster, and the parent invites for it.
///
/// A teacher can invite the parent of any student in their own school — the
/// server checks that, so this screen offers it without needing to know the
/// rule.
class TeacherClassScreen extends ConsumerWidget {
  const TeacherClassScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final klass = ref
        .watch(teacherClassesProvider)
        .valueOrNull
        ?.where((c) => c.id == classId)
        .firstOrNull;
    final progress = ref.watch(classProgressProvider(classId));

    return DetailScaffold(
      title: klass?.name ?? 'Class',
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(classProgressProvider(classId)),
        child: AsyncValueView<List<StudentProgress>>(
          value: progress,
          onRetry: () => ref.invalidate(classProgressProvider(classId)),
          data: (students) => ListView(
            children: [
              if (klass != null) _JoinCodeCard(klass: klass),
              const SizedBox(height: 16),
              SectionTitle(
                'Roster',
                trailing: AppBadge('${students.length} enrolled'),
              ),
              const SizedBox(height: 10),
              if (students.isEmpty)
                const TrustBanner(
                  icon: Icons.person_add_alt_outlined,
                  title: 'Nobody has joined yet',
                  body: 'Share the join code above. Each student enters it once.',
                )
              else
                for (final student in students)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StudentRow(student: student),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.klass});

  final TeacherClass klass;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    if (!klass.isJoinable) {
      return const TrustBanner(
        icon: Icons.vpn_key_outlined,
        title: 'This class has no join code',
        body: 'Nobody can enrol without one. Ask your school admin to add a '
            'code to this class.',
      );
    }
    return AppCard(
      child: Row(
        children: [
          const IconTile(icon: Icons.vpn_key_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Join code',
                  style: TextStyle(fontSize: 12, color: t.ink3),
                ),
                SelectableText(
                  klass.joinCode!,
                  key: const Key('class-detail-join-code'),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3,
                    color: t.ink,
                  ),
                ),
              ],
            ),
          ),
          ToolIconButton(
            icon: Icons.copy_outlined,
            tooltip: 'Copy join code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: klass.joinCode!));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Code copied.')));
            },
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends ConsumerWidget {
  const _StudentRow({required this.student});

  final StudentProgress student;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final accuracy = student.accuracy;

    return AppCard(
      child: Row(
        children: [
          const IconTile(icon: Icons.person_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  student.studentName,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  student.isActive
                      ? '${student.questions} questions · '
                            '${student.checks} checks'
                            '${accuracy == null ? '' : ' · '
                                '${Formatters.percent(accuracy)} right'}'
                      : 'No activity in the last 30 days',
                  style: TextStyle(fontSize: 12.5, color: t.ink3),
                ),
              ],
            ),
          ),
          if (student.hasParent)
            const AppBadge('Parent linked', tone: AppTone.success)
          else
            OutlinedButton(
              key: Key('teacher-invite-parent-${student.studentId}'),
              onPressed: () => _inviteParent(context, ref),
              child: const Text('Invite parent'),
            ),
        ],
      ),
    );
  }

  Future<void> _inviteParent(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(linkingActionControllerProvider.notifier)
        .inviteParent(studentId: student.studentId);
    if (!context.mounted) return;

    result.when(
      // The code is what the parent needs, so it is shown rather than a vague
      // "invite sent" — the teacher reads it out or texts it themselves.
      success: (invite) => showDialog<void>(
        context: context,
        builder: (ctx) {
          final t = AppTokens.read(ctx);
          return AlertDialog(
            title: Text('Code for ${student.studentName}’s parent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SunkenCard(
                  child: SelectableText(
                    invite.code,
                    key: const Key('teacher-parent-invite-code'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                      color: t.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'They sign up as a parent and enter this code under '
                  '“My children”. It works once and lasts 30 days.',
                  style: TextStyle(fontSize: 13, color: t.ink2),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: invite.code));
                  Navigator.of(ctx).pop();
                },
                child: const Text('Copy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ],
          );
        },
      ),
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }
}
