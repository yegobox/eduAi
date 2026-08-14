import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/presentation/widgets/access_gate.dart';
import '../../../schools/presentation/widgets/schools_dialogs.dart';
import '../../application/teacher_providers.dart';
import '../../domain/entities/teacher_class.dart';

/// A teacher's landing surface: their classes and the codes that fill them.
class TeacherClassesScreen extends ConsumerWidget {
  const TeacherClassesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final classes = ref.watch(teacherClassesProvider);
    final schoolId = ref.watch(accessSnapshotProvider).schoolId;

    return ShellContent(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(teacherClassesProvider),
        child: AsyncValueView<List<TeacherClass>>(
          value: classes,
          onRetry: () => ref.invalidate(teacherClassesProvider),
          data: (list) => ListView(
            children: [
              const AccessNotice(),
              SectionTitle(
                'My classes',
                trailing: schoolId == null
                    ? null
                    : TextButton.icon(
                        key: const Key('teacher-add-class'),
                        onPressed: () async {
                          final created =
                              await showCreateClassDialog(context, schoolId);
                          if (created) {
                            ref.invalidate(teacherClassesProvider);
                          }
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add class'),
                      ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap a class to see who is in it and how they are doing.',
                style: TextStyle(fontSize: 13, color: t.ink2),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const TrustBanner(
                  icon: Icons.groups_outlined,
                  title: 'No classes yet',
                  body: 'Add a class to get a join code. Students enter it once '
                      'and appear on your roster.',
                )
              else
                for (final klass in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ClassCard(klass: klass),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.klass});

  final TeacherClass klass;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AppCard(
      onTap: () => context.push(AppRoutes.teacherClass(klass.id)),
      child: Row(
        children: [
          const IconTile(icon: Icons.menu_book_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  klass.name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${klass.studentCount} '
                  '${klass.studentCount == 1 ? 'student' : 'students'}'
                  '${klass.grade == null ? '' : ' · ${klass.grade}'}',
                  style: TextStyle(fontSize: 12.5, color: t.ink3),
                ),
              ],
            ),
          ),
          // A class nobody can join is worth flagging rather than leaving blank.
          if (!klass.isJoinable)
            const AppBadge('No code', tone: AppTone.warning)
          else ...[
            SelectableText(
              klass.joinCode!,
              key: Key('teacher-class-code-${klass.id}'),
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: t.ink,
              ),
            ),
            const SizedBox(width: 4),
            ToolIconButton(
              icon: Icons.copy_outlined,
              tooltip: 'Copy ${klass.name} join code',
              size: 30,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: klass.joinCode!));
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text('${klass.joinCode} copied.')),
                  );
              },
            ),
          ],
        ],
      ),
    );
  }
}
