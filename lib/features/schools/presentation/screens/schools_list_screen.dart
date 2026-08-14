import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/detail_scaffold.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../auth/application/role_providers.dart';
import '../../../auth/domain/entities/app_role.dart';
import '../../application/schools_providers.dart';
import '../../domain/entities/school.dart';
import '../widgets/schools_dialogs.dart';

/// Browse the school catalog and join by code — or, for a school-admin
/// identity, create a school.
///
/// Creating a school is a school-admin action. It used to be an unguarded
/// button on this page for every signed-in account, which is how anybody could
/// stand up a school for free; the server now refuses the insert as well, so
/// hiding the button keeps the UI honest rather than doing the enforcing.
class SchoolsListScreen extends ConsumerWidget {
  const SchoolsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schools = ref.watch(schoolsListProvider);
    final joinedIds = ref.watch(joinedSchoolIdsProvider);
    final canCreate = ref.watch(activeRoleProvider) == AppRole.schoolAdmin;

    return DetailScaffold(
      title: 'Schools',
      actions: [
        // Enrolling is a student action. A director browsing the catalog is
        // looking, not joining.
        if (ref.watch(activeRoleProvider) == AppRole.student)
          TextButton.icon(
            onPressed: () => showJoinByCodeDialog(context),
            icon: const Icon(Icons.vpn_key_outlined, size: 16),
            label: const Text('Join by code'),
          ),
      ],
      bottomBar: canCreate
          ? SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => showCreateSchoolDialog(context),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New school'),
              ),
            )
          : null,
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(schoolsListProvider),
        child: AsyncValueView<List<School>>(
          value: schools,
          onRetry: () => ref.invalidate(schoolsListProvider),
          isEmpty: (list) => list.isEmpty,
          emptyBuilder: () => const _EmptyCatalog(),
          data: (list) => ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SchoolCard(
              school: list[i],
              joined: joinedIds.contains(list[i].id),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school, required this.joined});

  final School school;
  final bool joined;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AppCard(
      onTap: () =>
          context.push(AppRoutes.schoolDetail(school.id), extra: school),
      child: Row(
        children: [
          const IconTile(icon: Icons.school_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  school.name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                if (school.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    school.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: t.ink3),
                  ),
                ],
              ],
            ),
          ),
          if (joined)
            const AppBadge('Joined', tone: AppTone.success)
          else
            Icon(Icons.chevron_right, color: t.ink3),
        ],
      ),
    );
  }
}

class _EmptyCatalog extends ConsumerWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCreate = ref.watch(activeRoleProvider) == AppRole.schoolAdmin;
    return ListView(
      children: [
        const SizedBox(height: 80),
        TrustBanner(
          icon: Icons.school_outlined,
          title: 'No schools yet',
          body: canCreate
              ? 'Create yours below to start a 30-day trial.'
              : 'Join with the code your teacher gave you. If your school does '
                    'not use EduAI yet, a parent can subscribe for you instead.',
        ),
      ],
    );
  }
}
