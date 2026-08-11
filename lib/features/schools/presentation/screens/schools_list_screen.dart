import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../application/schools_providers.dart';
import '../../domain/entities/school.dart';
import '../widgets/schools_dialogs.dart';

/// Browse the school catalog, search, join by code, or create a school.
class SchoolsListScreen extends ConsumerWidget {
  const SchoolsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schools = ref.watch(schoolsListProvider);
    final joinedIds = ref.watch(joinedSchoolIdsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schools'),
        actions: [
          TextButton.icon(
            onPressed: () => showJoinByCodeDialog(context),
            icon: const Icon(Icons.vpn_key_outlined),
            label: const Text('Join by code'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateSchoolDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New school'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(schoolsListProvider),
        child: AsyncValueView<List<School>>(
          value: schools,
          onRetry: () => ref.invalidate(schoolsListProvider),
          isEmpty: (list) => list.isEmpty,
          emptyBuilder: () => const _EmptyCatalog(),
          data: (list) => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final school = list[i];
              final joined = joinedIds.contains(school.id);
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.school)),
                  title: Text(school.name),
                  subtitle: school.description == null
                      ? null
                      : Text(
                          school.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: joined
                      ? const Chip(
                          label: Text('Joined'),
                          visualDensity: VisualDensity.compact,
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                    AppRoutes.schoolDetail(school.id),
                    extra: school,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.school_outlined, size: 48),
        SizedBox(height: 12),
        Center(child: Text('No schools yet.')),
        SizedBox(height: 4),
        Center(
          child: Text('Create one, or join with a code from your teacher.'),
        ),
      ],
    );
  }
}
