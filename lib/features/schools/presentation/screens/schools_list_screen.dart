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

/// The schools this account belongs to.
///
/// It used to list the whole catalog — every school in the country — with a
/// "Join" on each. That was wrong twice over: a student has no business browsing
/// other people's schools, and enrolling into one consumed a seat on *its*
/// licence, so anybody could raise a stranger's invoice. Enrolment now needs the
/// code a teacher hands out (`enrol_by_code`), and this screen shows only what
/// the code got you.
class SchoolsListScreen extends ConsumerWidget {
  const SchoolsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(mySchoolsProvider);
    final canEnrol = ref.watch(activeRoleProvider) == AppRole.student;

    // A back chevron, a title and a labelled action do not fit an app bar at
    // phone width — the label is dropped for a tooltip rather than letting the
    // row overflow.
    final compact = MediaQuery.sizeOf(context).width < 500;

    return DetailScaffold(
      title: 'My school',
      actions: [
        if (canEnrol)
          compact
              ? IconButton(
                  onPressed: () => showJoinByCodeDialog(context),
                  icon: const Icon(Icons.vpn_key_outlined, size: 18),
                  tooltip: 'Join by code',
                )
              : TextButton.icon(
                  onPressed: () => showJoinByCodeDialog(context),
                  icon: const Icon(Icons.vpn_key_outlined, size: 16),
                  label: const Text('Join by code'),
                ),
      ],
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mySchoolsProvider),
        child: AsyncValueView<List<School>>(
          value: mine,
          onRetry: () => ref.invalidate(mySchoolsProvider),
          isEmpty: (list) => list.isEmpty,
          emptyBuilder: () => _NotEnrolled(canEnrol: canEnrol),
          data: (list) => ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _SchoolCard(school: list[i]),
          ),
        ),
      ),
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({required this.school});

  final School school;

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
          Icon(Icons.chevron_right, color: t.ink3),
        ],
      ),
    );
  }
}

/// Not enrolled anywhere yet. The only way in is a code, so the placeholder
/// offers exactly that rather than a list to pick from.
class _NotEnrolled extends StatelessWidget {
  const _NotEnrolled({required this.canEnrol});

  final bool canEnrol;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return ListView(
      children: [
        const SizedBox(height: 60),
        // The action sits *below* the banner rather than inside it: TrustBanner
        // lays its action out beside the text, which squeezes a long body into
        // a very tall column at phone width. A full-width button is the right
        // shape for an empty state anyway.
        TrustBanner(
          icon: Icons.school_outlined,
          title: canEnrol
              ? 'You have not joined a school yet'
              : 'No school linked to this account',
          body: canEnrol
              ? 'Enter the code your teacher gave you. It enrols you in their '
                    'class, and everything they share shows up here.'
              : 'Only student accounts enrol in a school.',
        ),
        if (canEnrol) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('not-enrolled-join'),
            onPressed: () => showJoinByCodeDialog(context),
            icon: const Icon(Icons.vpn_key_outlined, size: 16),
            label: const Text('Enter a join code'),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'No code? A parent can subscribe for you instead.',
              style: TextStyle(fontSize: 12.5, color: t.ink3),
            ),
          ),
        ],
      ],
    );
  }
}
