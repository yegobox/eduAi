import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/async_value_view.dart';
import '../../application/schools_action_controller.dart';
import '../../application/schools_providers.dart';
import '../../domain/entities/membership.dart';
import '../../domain/entities/school.dart';
import '../../domain/entities/school_class.dart';
import '../widgets/schools_dialogs.dart';

/// A school's page: join the school, browse and join its classes, add a class.
class SchoolDetailScreen extends ConsumerWidget {
  const SchoolDetailScreen({
    super.key,
    required this.schoolId,
    this.school,
  });

  final String schoolId;
  final School? school;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Prefer the passed school; otherwise resolve from the cached catalog.
    final resolved = school ??
        ref
            .watch(schoolsListProvider)
            .valueOrNull
            ?.where((s) => s.id == schoolId)
            .firstOrNull;

    final classes = ref.watch(classesProvider(schoolId));
    final memberships = ref.watch(myMembershipsProvider).valueOrNull ?? const [];

    final schoolMembership = memberships
        .where((m) => m.schoolId == schoolId && m.classId == null)
        .firstOrNull;
    final joinedClassIds = {
      for (final m in memberships)
        if (m.classId != null) m.classId!,
    };

    return Scaffold(
      appBar: AppBar(title: Text(resolved?.name ?? 'School')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateClassDialog(context, schoolId),
        icon: const Icon(Icons.add),
        label: const Text('Add class'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classesProvider(schoolId));
          ref.invalidate(myMembershipsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (resolved?.description != null) ...[
              Text(resolved!.description!,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
            ],
            _SchoolMembershipCard(
              schoolId: schoolId,
              membership: schoolMembership,
            ),
            const SizedBox(height: 24),
            Text('Classes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 320,
              child: AsyncValueView<List<SchoolClass>>(
                value: classes,
                onRetry: () => ref.invalidate(classesProvider(schoolId)),
                isEmpty: (list) => list.isEmpty,
                emptyBuilder: () => const Center(
                  child: Text('No classes yet. Add the first one.'),
                ),
                data: (list) => ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final klass = list[i];
                    final joinedMembership = memberships
                        .where((m) => m.classId == klass.id)
                        .firstOrNull;
                    return _ClassTile(
                      klass: klass,
                      joined: joinedClassIds.contains(klass.id),
                      membership: joinedMembership,
                    );
                  },
                ),
              ),
            ),
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
    final busy = ref.watch(schoolsActionControllerProvider).busy;
    final joined = membership != null;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: joined ? scheme.secondaryContainer : null,
      child: ListTile(
        leading: Icon(joined ? Icons.verified_user : Icons.group_add),
        title: Text(joined ? 'You are a member' : 'Join this school'),
        subtitle: Text(joined
            ? 'You can now learn under this school.'
            : 'Enrol to access this school and its classes.'),
        trailing: joined
            ? TextButton(
                onPressed: busy
                    ? null
                    : () => _leave(context, ref, membership!.id),
                child: const Text('Leave'),
              )
            : FilledButton(
                onPressed: busy
                    ? null
                    : () => _join(context, ref),
                child: const Text('Join'),
              ),
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
    final result =
        await ref.read(schoolsActionControllerProvider.notifier).leave(id);
    if (context.mounted) _toast(context, result.failureOrNull?.message);
  }
}

class _ClassTile extends ConsumerWidget {
  const _ClassTile({
    required this.klass,
    required this.joined,
    this.membership,
  });

  final SchoolClass klass;
  final bool joined;
  final Membership? membership;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(schoolsActionControllerProvider).busy;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.class_outlined),
        title: Text(klass.name),
        subtitle: klass.grade == null ? null : Text(klass.grade!),
        trailing: joined
            ? TextButton(
                onPressed: busy || membership == null
                    ? null
                    : () async {
                        final result = await ref
                            .read(schoolsActionControllerProvider.notifier)
                            .leave(membership!.id);
                        if (context.mounted) {
                          _toast(context, result.failureOrNull?.message);
                        }
                      },
                child: const Text('Leave'),
              )
            : FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final result = await ref
                            .read(schoolsActionControllerProvider.notifier)
                            .joinClass(
                              schoolId: klass.schoolId,
                              classId: klass.id,
                            );
                        if (context.mounted) {
                          _toast(context, result.failureOrNull?.message);
                        }
                      },
                child: const Text('Join'),
              ),
      ),
    );
  }
}

void _toast(BuildContext context, String? message) {
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
