import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/app_shell.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../access/presentation/widgets/access_gate.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_providers.dart';
import '../../progress/application/mastery_providers.dart';
import '../../schools/application/schools_providers.dart';
import '../../schools/domain/entities/membership.dart';

/// The student's landing surface: greeting and streak, the offline-PIN nudge,
/// their schools and classes, and quick links into the other four tabs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final user = ref.watch(authControllerProvider).session?.user;
    final hasPin = ref.watch(hasOfflinePinProvider).valueOrNull ?? true;
    final streak =
        ref.watch(masteryViewProvider).valueOrNull?.currentStreak ?? 0;

    return ShellContent(
      child: ListView(
        children: [
          Text(
            'Hello, ${user?.label ?? 'there'} 👋',
            style: TextStyle(
              fontSize: t.h1,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            streak > 0
                ? '$streak-day streak — a little practice each day builds real '
                      'mastery.'
                : 'A little practice each day builds real mastery. Start today.',
            style: TextStyle(fontSize: 15, color: t.ink2),
          ),
          const SizedBox(height: 16),
          // Entitlement first: a student whose school licence has lapsed, or
          // who has joined nothing at all, should learn that here rather than
          // by finding the Tutor tab locked.
          const AccessNotice(),
          if (!hasPin) ...[
            const _OfflinePinNudge(),
            const SizedBox(height: 16),
          ],
          const _SchoolsSection(),
          const SizedBox(height: 20),
          const SectionTitle('Continue learning'),
          const SizedBox(height: 8),
          const _ContinueLearningGrid(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _OfflinePinNudge extends StatelessWidget {
  const _OfflinePinNudge();

  @override
  Widget build(BuildContext context) {
    return TrustBanner(
      icon: Icons.lock_outline,
      title: 'Set up offline access',
      body:
          "Create a PIN so you can open EduAI without internet — school "
          "power cuts won't stop a lesson.",
      action: FilledButton(
        onPressed: () => context.push(AppRoutes.setPin),
        child: const Text('Set PIN'),
      ),
    );
  }
}

class _SchoolsSection extends ConsumerWidget {
  const _SchoolsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberships = ref.watch(myMembershipsProvider);
    final schools = ref.watch(schoolsListProvider).valueOrNull ?? const [];

    String schoolName(String id) =>
        schools.firstWhereOrNull((s) => s.id == id)?.name ?? 'School';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'My schools & classes',
          trailing: FilledButton.tonalIcon(
            onPressed: () => context.push(AppRoutes.schools),
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Browse'),
          ),
        ),
        const SizedBox(height: 8),
        memberships.when(
          loading: () => const SizedBox(
            height: 88,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => AppCard(
            child: Row(
              children: [
                const IconTile(icon: Icons.cloud_off, tone: AppTone.warning),
                const SizedBox(width: 12),
                const Expanded(child: Text('Could not load your memberships')),
                TextButton(
                  onPressed: () => ref.invalidate(myMembershipsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return AppCard(
                onTap: () => context.push(AppRoutes.schools),
                child: Row(
                  children: [
                    const IconTile(icon: Icons.group_add_outlined),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "You haven't joined anywhere yet",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 2),
                          Text('Browse schools or use a join code to start.'),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final m in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SchoolRow(
                      name: schoolName(m.schoolId),
                      membership: m,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SchoolRow extends StatelessWidget {
  const _SchoolRow({required this.name, required this.membership});

  final String name;
  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final role = membership.role.name;
    return AppCard(
      onTap: () => context.push(AppRoutes.schoolDetail(membership.schoolId)),
      child: Row(
        children: [
          IconTile(
            icon: membership.isClassMember
                ? Icons.class_outlined
                : Icons.school_outlined,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  membership.isClassMember
                      ? 'Class member • $role'
                      : 'School member • $role',
                  style: TextStyle(fontSize: 13, color: t.ink3),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: t.ink3),
        ],
      ),
    );
  }
}

class _ContinueLearningGrid extends ConsumerWidget {
  const _ContinueLearningGrid();

  static const _features = [
    (
      Icons.auto_awesome_outlined,
      'AI Tutor',
      'Ask questions, get step-by-step help.',
      AppRoutes.tutor,
    ),
    (
      Icons.edit_outlined,
      'Workbook',
      'Solve by hand with a pen or stylus.',
      AppRoutes.workbook,
    ),
    (
      Icons.menu_book_outlined,
      'Lessons',
      'REB-aligned, offline-ready content.',
      AppRoutes.lessons,
    ),
    (
      Icons.insights_outlined,
      'Progress',
      'Track mastery over time.',
      AppRoutes.progress,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final wide = MediaQuery.of(context).size.width > 560;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // A fixed row height, not an aspect ratio: the card holds a fixed stack
      // of icon plus two text lines, so tying its height to the column width
      // overflows as soon as the window narrows.
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 2 : 1,
        mainAxisExtent: 144,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: _features.length,
      itemBuilder: (_, i) {
        final (icon, title, subtitle, route) = _features[i];
        return AppCard(
          // These jump straight to the tab, not a nested push — the tab is
          // where that feature lives.
          onTap: () => context.go(route),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconTile(icon: icon),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: t.ink3),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
