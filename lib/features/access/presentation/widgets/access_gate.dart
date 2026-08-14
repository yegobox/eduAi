import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/format/formatters.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/domain/entities/app_role.dart';
import '../../application/access_providers.dart';
import '../../domain/entities/access_state.dart';

/// What an unentitled account is told, and where it is sent, per role.
///
/// Every branch has exactly one next action. "Your access has lapsed" with no
/// button is how a paying customer becomes a former customer.
class _Prompt {
  const _Prompt({
    required this.title,
    required this.body,
    this.actionLabel,
    this.route,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final String? route;
}

_Prompt _promptFor(AccessState access) {
  final school = access.schoolName ?? 'your school';

  if (access.needsSetup) {
    return switch (access.role) {
      AppRole.schoolAdmin => const _Prompt(
        title: 'Set your school up first',
        body:
            'Create your school to start a 30-day trial. You can invite '
            'teachers and enrol students straight away, and only pay when the '
            'trial ends.',
        actionLabel: 'Create your school',
        route: AppRoutes.adminLicense,
      ),
      AppRole.parent => const _Prompt(
        title: 'Link your child first',
        body:
            "Add your child's account — or enter the code their school gave "
            'you — and their reports appear here.',
        actionLabel: 'Link a child',
        route: AppRoutes.family,
      ),
      AppRole.student => const _Prompt(
        title: 'Join your school to unlock this',
        body:
            'Enter the code your teacher gave you. If you are not at a school '
            'using EduAI, a parent can subscribe for you instead.',
        actionLabel: 'Enter a join code',
        route: AppRoutes.schools,
      ),
      // A teacher with no school has not redeemed their code yet. There is
      // nothing for them to buy — only a code to enter.
      AppRole.teacher => const _Prompt(
        title: 'Enter your teacher code',
        body:
            'Your school adds you with a code from its People tab. Once you '
            'redeem it, your classes appear here.',
        actionLabel: 'Enter a code',
        route: AppRoutes.family,
      ),
    };
  }

  return switch (access.role) {
    AppRole.schoolAdmin => _Prompt(
      title: access.licenseStatus == LicenseStatus.trialing
          ? 'Your trial has ended'
          : 'The licence needs paying',
      body:
          'Students keep their work and their progress. Pay the licence to '
          'switch the AI Tutor and Workbook back on for everyone.',
      actionLabel: 'Pay the licence',
      route: AppRoutes.adminLicense,
    ),
    AppRole.parent => const _Prompt(
      title: 'Choose a plan to continue',
      body:
          'No school is covering your child yet. A family plan unlocks the AI '
          'Tutor, the Workbook and weekly reports.',
      actionLabel: 'See the plans',
      route: AppRoutes.parentPlan,
    ),
    AppRole.student => _Prompt(
      title: 'This is paused for now',
      body:
          "$school's EduAI licence has lapsed, so the AI Tutor is paused. "
          'Your lessons, workbook pages and progress are all still here. Ask '
          'your teacher when it will be back.',
    ),
    // A teacher cannot pay their school's invoice either, so they get the
    // situation and no button pretending otherwise.
    AppRole.teacher => _Prompt(
      title: 'Paused until the licence is paid',
      body:
          "$school's EduAI licence has lapsed. Your classes and rosters are "
          'unchanged, but the AI features are off for your students until the '
          'school settles it.',
    ),
  };
}

/// Hides a paid feature behind the entitlement state, with a way out.
///
/// Wrapped around the *costly* surfaces only — the AI Tutor and AI handwriting
/// checking. Lessons, the workbook itself and a student's own progress stay
/// readable when a licence lapses: taking a child's completed work hostage
/// over their school's invoice is not a collections strategy.
class AccessGate extends ConsumerWidget {
  const AccessGate({super.key, required this.child, this.featureName});

  final Widget child;

  /// Named in the lock panel's heading ("The AI Tutor is paused").
  final String? featureName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(hasPaidAccessProvider)) return child;
    return AccessLockPanel(featureName: featureName);
  }
}

/// The lock panel itself, split out so it can be laid out and tested without
/// standing up an entitlement state.
class AccessLockPanel extends ConsumerWidget {
  const AccessLockPanel({super.key, this.featureName});

  final String? featureName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final access = ref.watch(accessSnapshotProvider);
    final prompt = _promptFor(access);
    final feature = featureName;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconTile(
                      icon: Icons.lock_outline,
                      tone: AppTone.warning,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            feature == null
                                ? prompt.title
                                : '$feature — ${prompt.title.toLowerCase()}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: t.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            prompt.body,
                            style: TextStyle(fontSize: 13.5, color: t.ink2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (prompt.actionLabel != null && prompt.route != null) ...[
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const Key('access-gate-action'),
                    onPressed: () => context.go(prompt.route!),
                    child: Text(prompt.actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The slim strip that sits above a screen's content while something needs
/// attention: a trial counting down, or a payment that has not happened.
///
/// Renders nothing when access is paid and current, and nothing at all on
/// builds with no billing backend, where any claim about a plan would be made
/// up. Every other state gets one line and one action.
class AccessNotice extends ConsumerWidget {
  const AccessNotice({super.key, this.padding = const EdgeInsets.only(bottom: 12)});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessSnapshotProvider);

    // The one case that must never be silent: Supabase is live, the billing
    // schema is not, so every account looks like an unpaid student and nobody
    // is being charged. Said plainly, with the fix, in every build.
    if (access.schemaMissing) {
      return Padding(
        padding: padding,
        child: _NoticeStrip(
          key: const Key('access-schema-missing'),
          tone: AppTone.danger,
          icon: Icons.warning_amber_outlined,
          message:
              'Billing is not installed on this Supabase project, so roles and '
              'payments are switched off. Run migration 0003, then 0004.',
        ),
      );
    }

    if (!access.enforced) return const SizedBox.shrink();

    final message = _messageFor(access);
    if (message == null) return const SizedBox.shrink();

    final prompt = _promptFor(access);
    final showAction =
        !access.isTrialing && prompt.actionLabel != null && prompt.route != null;

    return Padding(
      padding: padding,
      child: _NoticeStrip(
        key: const Key('access-notice'),
        tone: access.isTrialing ? AppTone.brand : AppTone.warning,
        icon: access.isTrialing ? Icons.schedule : Icons.error_outline,
        message: message,
        action: showAction
            ? TextButton(
                onPressed: () => context.go(prompt.route!),
                child: Text(prompt.actionLabel!),
              )
            : null,
      ),
    );
  }

  String? _messageFor(AccessState access) {
    switch (access.status) {
      case AccessStatus.unknown:
      case AccessStatus.entitled:
        return null;

      case AccessStatus.trialing:
        final days = access.daysLeft() ?? 0;
        final left = switch (days) {
          0 => 'ends today',
          1 => 'ends tomorrow',
          _ => '$days days left',
        };
        if (access.overTrialCap) {
          return 'Trial — $left, and your roster is past the '
              '${access.trialSeatCap}-student trial cap.';
        }
        return access.role == AppRole.schoolAdmin
            ? 'Trial — $left. Pay the licence any time to keep going.'
            : 'Trial — $left.';

      case AccessStatus.needsPayment:
        final until = access.validUntil;
        final ended = until == null
            ? ''
            : ' Cover ended ${Formatters.shortDate(until)}.';
        return switch (access.role) {
          AppRole.schoolAdmin => 'The licence is unpaid, so AI features are '
              'off for your students.$ended',
          AppRole.parent =>
            'No plan is covering your children yet.$ended',
          AppRole.teacher =>
            "Your school's licence is unpaid, so AI features are off for your "
                'students.$ended',
          AppRole.student => 'AI features are paused.$ended',
        };

      case AccessStatus.needsSetup:
        return switch (access.role) {
          AppRole.schoolAdmin => 'Create your school to start your 30-day trial.',
          AppRole.parent => 'Link a child to see their progress.',
          AppRole.teacher => 'Enter the teacher code your school gave you.',
          AppRole.student => 'Join your school, or ask a parent to subscribe.',
        };
    }
  }
}

class _NoticeStrip extends StatelessWidget {
  const _NoticeStrip({
    super.key,
    required this.tone,
    required this.icon,
    required this.message,
    this.action,
  });

  final AppTone tone;
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, action == null ? 12 : 4, 10),
      decoration: BoxDecoration(
        color: tone.background(t),
        borderRadius: t.cardBorderRadius,
      ),
      // Wrap rather than Row: the message plus a button overflows a phone
      // width, and this notice must never be the thing that breaks a layout.
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Icon(icon, size: 16, color: tone.foreground(t)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: tone.foreground(t),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
