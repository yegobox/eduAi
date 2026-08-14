import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/detail_scaffold.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../auth/application/role_providers.dart';
import '../../../auth/domain/entities/app_role.dart';
import '../../application/schools_action_controller.dart';
import '../../application/schools_providers.dart';
import '../../domain/entities/membership.dart';
import '../../domain/entities/school.dart';
import '../../domain/entities/school_class.dart';
import '../widgets/schools_dialogs.dart';

/// A school's page: join the school, browse and join its classes, add a class.
class SchoolDetailScreen extends ConsumerWidget {
  const SchoolDetailScreen({super.key, required this.schoolId, this.school});

  final String schoolId;
  final School? school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);

    // Prefer the passed school; otherwise resolve from the cached catalog.
    final resolved =
        school ??
        ref
            .watch(schoolsListProvider)
            .valueOrNull
            ?.firstWhereOrNull((s) => s.id == schoolId);

    final classes = ref.watch(classesProvider(schoolId));
    final memberships =
        ref.watch(myMembershipsProvider).valueOrNull ?? const [];

    final schoolMembership = memberships.firstWhereOrNull(
      (m) => m.schoolId == schoolId && m.classId == null,
    );

    return DetailScaffold(
      title: resolved?.name ?? 'School',
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classesProvider(schoolId));
          ref.invalidate(myMembershipsProvider);
        },
        child: ListView(
          children: [
            if (resolved?.description != null) ...[
              Text(
                resolved!.description!,
                style: TextStyle(fontSize: 14, color: t.ink2),
              ),
              const SizedBox(height: 16),
            ],
            _SchoolMembershipCard(
              schoolId: schoolId,
              membership: schoolMembership,
            ),
            const SizedBox(height: 20),
            const SectionTitle('Classes'),
            const SizedBox(height: 8),
            AsyncValueView<List<SchoolClass>>(
              value: classes,
              onRetry: () => ref.invalidate(classesProvider(schoolId)),
              isEmpty: (list) => list.isEmpty,
              emptyBuilder: () => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No classes yet. Add the first one.',
                    style: TextStyle(color: t.ink3),
                  ),
                ),
              ),
              data: (list) => Column(
                children: [
                  for (final klass in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ClassTile(
                        klass: klass,
                        membership: memberships.firstWhereOrNull(
                          (m) => m.classId == klass.id,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () => showCreateClassDialog(context, schoolId),
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Add class'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SchoolMembershipCard extends ConsumerWidget {
  const _SchoolMembershipCard({required this.schoolId, this.membership});

  final String schoolId;
  final Membership? membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final busy = ref.watch(schoolsActionControllerProvider).busy;
    final joined = membership != null;
    // Only students occupy seats, so only students are offered enrolment. The
    // server refuses the insert either way (`may_enrol`); this keeps the screen
    // from advertising an action that would be rejected.
    final canEnrol = ref.watch(activeRoleProvider) == AppRole.student;

    return AppCard(
      child: Row(
        children: [
          IconTile(
            icon: joined
                ? Icons.verified_user_outlined
                : Icons.group_add_outlined,
            tone: joined ? AppTone.success : AppTone.brand,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  joined
                      ? 'You are a member'
                      : canEnrol
                            ? 'Join this school'
                            : 'Browsing only',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  joined
                      ? 'You can now learn under this school.'
                      : canEnrol
                            ? 'Enrol to access this school and its classes.'
                            : 'Only student accounts enrol in a school.',
                  style: TextStyle(fontSize: 13, color: t.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (joined)
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _leave(context, ref, membership!.id),
              child: const Text('Leave'),
            )
          else if (canEnrol)
            FilledButton(
              onPressed: busy ? null : () => _join(context, ref),
              child: const Text('Join'),
            ),
        ],
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(schoolsActionControllerProvider.notifier)
        .joinSchool(schoolId);
    if (context.mounted) _toast(context, result.failureOrNull?.message);
  }

  Future<void> _leave(BuildContext context, WidgetRef ref, String id) async {
    final result = await ref
        .read(schoolsActionControllerProvider.notifier)
        .leave(id);
    if (context.mounted) _toast(context, result.failureOrNull?.message);
  }
}

class _ClassTile extends ConsumerWidget {
  const _ClassTile({required this.klass, this.membership});

  final SchoolClass klass;
  final Membership? membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final busy = ref.watch(schoolsActionControllerProvider).busy;
    final joined = membership != null;
    final canEnrol = ref.watch(activeRoleProvider) == AppRole.student;

    return AppCard(
      child: Row(
        children: [
          const IconTile(icon: Icons.menu_book_outlined, tone: AppTone.neutral),
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
                if (klass.grade != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    klass.grade!,
                    style: TextStyle(fontSize: 13, color: t.ink3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (joined)
            OutlinedButton(
              onPressed: busy ? null : () => _leave(context, ref),
              child: const Text('Leave'),
            )
          else if (canEnrol)
            FilledButton(
              onPressed: busy ? null : () => _join(context, ref),
              child: const Text('Join'),
            ),
        ],
      ),
    );
  }

  Future<void> _join(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(schoolsActionControllerProvider.notifier)
        .joinClass(schoolId: klass.schoolId, classId: klass.id);
    if (context.mounted) _toast(context, result.failureOrNull?.message);
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final id = membership?.id;
    if (id == null) return;
    final result = await ref
        .read(schoolsActionControllerProvider.notifier)
        .leave(id);
    if (context.mounted) _toast(context, result.failureOrNull?.message);
  }
}

void _toast(BuildContext context, String? message) {
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
