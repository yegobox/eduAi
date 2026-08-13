import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/connectivity_service.dart';
import '../../../core/router/app_routes.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../schools/application/schools_providers.dart';
import '../../schools/domain/entities/membership.dart';

/// Placeholder landing surface — the seam where the "education with AI"
/// features will grow. It demonstrates reading the session, online/offline
/// status, and the offline-PIN nudge.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.session?.user;
    final isOffline = auth.session?.isOffline ?? false;
    final network = ref.watch(networkStatusProvider).valueOrNull;
    final hasPin = ref.watch(hasOfflinePinProvider).valueOrNull ?? true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduAI'),
        actions: [
          _StatusChip(
            offlineSession: isOffline,
            network: network,
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'pin':
                  context.push(AppRoutes.setPin);
                case 'signout':
                  await ref.read(authControllerProvider.notifier).signOut();
                case 'forget':
                  await ref
                      .read(authControllerProvider.notifier)
                      .signOut(forgetDevice: true);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'pin', child: Text('Set/change offline PIN')),
              PopupMenuItem(value: 'signout', child: Text('Sign out')),
              PopupMenuItem(
                value: 'forget',
                child: Text('Sign out & forget this device'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Hello, ${user?.label ?? 'there'} 👋',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'This is your foundation. Auth, offline access and state '
                'management are wired — build the learning experience here.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              if (!hasPin) _OfflinePinNudge(),
              const SizedBox(height: 16),
              const _MyLearningSection(),
              const SizedBox(height: 24),
              const _FeatureGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.offlineSession, required this.network});

  final bool offlineSession;
  final NetworkStatus? network;

  @override
  Widget build(BuildContext context) {
    final online = network != NetworkStatus.offline;
    final label = offlineSession
        ? 'Offline session'
        : (online ? 'Online' : 'Offline');
    final color = (offlineSession || !online) ? Colors.orange : Colors.green;
    return Chip(
      avatar: Icon(
        (offlineSession || !online) ? Icons.cloud_off : Icons.cloud_done,
        size: 18,
        color: color,
      ),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _OfflinePinNudge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: ListTile(
        leading: Icon(Icons.lock_outline, color: scheme.onPrimaryContainer),
        title: Text(
          'Set up offline access',
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Create a PIN so you can open EduAI without internet.',
          style: TextStyle(color: scheme.onPrimaryContainer),
        ),
        trailing: FilledButton(
          onPressed: () => context.push(AppRoutes.setPin),
          child: const Text('Set PIN'),
        ),
      ),
    );
  }
}

/// The user's schools/classes, with a CTA to browse and join more.
class _MyLearningSection extends ConsumerWidget {
  const _MyLearningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(myMembershipsProvider);
    final schools = ref.watch(schoolsListProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);

    String schoolName(String id) => schools
            .where((s) => s.id == id)
            .map((s) => s.name)
            .firstOrNull ??
        'School';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'My schools & classes',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => context.push(AppRoutes.schools),
              icon: const Icon(Icons.search),
              label: const Text('Browse schools'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        memberships.when(
          loading: () => const SizedBox(
            height: 88,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_off),
              title: const Text('Could not load your memberships'),
              trailing: TextButton(
                onPressed: () => ref.invalidate(myMembershipsProvider),
                child: const Text('Retry'),
              ),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.group_add_outlined),
                  title: const Text("You haven't joined anywhere yet"),
                  subtitle:
                      const Text('Browse schools or use a join code to start.'),
                  onTap: () => context.push(AppRoutes.schools),
                ),
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final m in list)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        m.isClassMember ? Icons.class_outlined : Icons.school,
                      ),
                      title: Text(schoolName(m.schoolId)),
                      subtitle: Text(_membershipLabel(m)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          context.push(AppRoutes.schoolDetail(m.schoolId)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _membershipLabel(Membership m) {
    final role = m.role.name;
    return m.isClassMember
        ? 'Class member • $role'
        : 'School member • $role';
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    const features = [
      (
        Icons.chat_bubble_outline,
        'AI Tutor',
        'Ask questions, get explanations.',
        AppRoutes.tutor,
      ),
      (
        Icons.menu_book_outlined,
        'Lessons',
        'Structured, offline-ready content.',
        null,
      ),
      (
        Icons.insights_outlined,
        'Progress',
        'Track mastery over time.',
        AppRoutes.progress,
      ),
      (
        Icons.groups_outlined,
        'Classrooms',
        'Learn together, sync when online.',
        null,
      ),
    ];
    return GridView.count(
      crossAxisCount:
          MediaQuery.of(context).size.width > 700 ? 2 : 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 3.2,
      children: [
        for (final (icon, title, subtitle, route) in features)
          Card(
            child: ListTile(
              leading: Icon(icon),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(subtitle),
              trailing: route == null
                  ? const Chip(
                      label: Text('Soon'),
                      visualDensity: VisualDensity.compact,
                    )
                  : const Icon(Icons.chevron_right),
              onTap: route == null ? null : () => context.push(route),
            ),
          ),
      ],
    );
  }
}
