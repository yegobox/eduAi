import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/config/config_providers.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/domain/entities/access_state.dart';
import '../../../access/domain/entities/payment_quote.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../payments/domain/entities/momo_payment.dart';
import '../../../payments/presentation/widgets/momo_payment_sheet.dart';
import '../../application/parent_providers.dart';
import '../../domain/entities/parent_entities.dart';

/// Billing for parents — and the direct-to-parent revenue line.
///
/// The screen has two faces, chosen by who is actually paying:
///
/// * **A school covers this family.** Then the first thing it says is that
///   access is already paid for, and top-ups sit below as clearly optional.
///   This must never read as a paywall — the school bought it already.
/// * **Nobody covers this family.** Then it is a real paywall, because there is
///   no other way for this parent to have access. It is still phrased as an
///   offer rather than a threat, and their child's existing work is never held
///   hostage.
class ParentPlanScreen extends ConsumerWidget {
  const ParentPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessStateProvider);

    return ShellContent(
      child: AsyncValueView<AccessState>(
        value: access,
        onRetry: () => ref.invalidate(accessStateProvider),
        data: (state) => ListView(
          children: [
            // A build with no billing backend cannot know who pays for this
            // family, and must not guess. It shows the demo plan rather than a
            // paywall: inventing a charge for a design review or a test would
            // be the same lie as inventing a paid invoice.
            if (!state.enforced)
              const _DemoPlan()
            else if (state.source == AccessSource.schoolLicense)
              _SchoolCoversYou(access: state)
            else if (state.needsSetup)
              const _LinkFirst()
            else
              _FamilyPlans(access: state),
            const SizedBox(height: 20),
            // Top-ups are extra AI sessions on top of access. Offering them to
            // a family that has no access at all would be selling a second
            // helping to somebody with no plate.
            if (state.grantsAccess) ...[
              const _TopupSection(),
              const SizedBox(height: 20),
            ],
            Text(
              "Your child's data stays private — never sold or used for "
              'advertising.',
              style: TextStyle(
                fontSize: 12,
                color: AppTokens.read(context).ink3,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// The no-backend case: the seeded school plan, presented exactly as the
/// school-paid case is. Only reachable when entitlement is unenforceable.
class _DemoPlan extends ConsumerWidget {
  const _DemoPlan();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(parentPlanProvider);
    return AsyncValueView<ParentPlan>(
      value: plan,
      onRetry: () => ref.invalidate(parentPlanProvider),
      data: (p) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TrustBanner(
            icon: Icons.shield_outlined,
            title: "Included in ${p.schoolName}'s EduAI plan",
            body:
                'No extra cost to you — the school covers full access for '
                'every enrolled student. Renews '
                '${Formatters.shortDate(p.renewsOn)}.',
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                Expanded(child: _Fact(label: 'Plan', value: p.tier)),
                Expanded(
                  child: _Fact(
                    label: 'Students covered',
                    value: Formatters.thousands(p.seats),
                  ),
                ),
                Expanded(
                  child: _Fact(
                    label: 'Renews',
                    value: Formatters.shortDate(p.renewsOn),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The school-paid case, unchanged in spirit: reassurance first.
class _SchoolCoversYou extends StatelessWidget {
  const _SchoolCoversYou({required this.access});

  final AccessState access;

  @override
  Widget build(BuildContext context) {
    final school = access.schoolName ?? 'your school';
    final until = access.validUntil;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrustBanner(
          icon: Icons.shield_outlined,
          title: "Included in $school's EduAI plan",
          body:
              'No extra cost to you — the school covers full access for every '
              'enrolled student.'
              '${until == null ? '' : ' Renews ${Formatters.shortDate(until)}.'}',
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Row(
            children: [
              Expanded(child: _Fact(label: 'Paid by', value: school)),
              Expanded(
                child: _Fact(
                  label: 'Children linked',
                  value: '${access.childrenLinked}',
                ),
              ),
              Expanded(
                child: _Fact(
                  label: access.isTrialing ? 'Trial ends' : 'Renews',
                  value: until == null ? '—' : Formatters.shortDate(until),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A parent with no children linked cannot be quoted a price yet — the plan is
/// priced per child. So the first ask is the link, not the card.
class _LinkFirst extends StatelessWidget {
  const _LinkFirst();

  @override
  Widget build(BuildContext context) {
    return TrustBanner(
      icon: Icons.family_restroom_outlined,
      title: 'Link a child first',
      body:
          'Plans are priced per child, so add yours before choosing one. If '
          'their school already uses EduAI, you may not need to pay at all.',
      action: FilledButton(
        key: const Key('plan-link-child'),
        onPressed: () => context.push(AppRoutes.family),
        child: const Text('Link a child'),
      ),
    );
  }
}

/// The direct-pay case: the family price list, priced by the server.
class _FamilyPlans extends ConsumerWidget {
  const _FamilyPlans({required this.access});

  final AccessState access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final plans = ref.watch(parentPlansProvider);
    final lapsedOn = access.validUntil;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrustBanner(
          icon: Icons.auto_awesome_outlined,
          title: lapsedOn == null
              ? 'Choose a family plan'
              : 'Your plan ended ${Formatters.shortDate(lapsedOn)}',
          body:
              'No school is covering your '
              '${access.childrenLinked == 1 ? 'child' : 'children'} yet. A '
              'family plan unlocks the AI Tutor, the stylus Workbook and '
              'weekly reports. Everything already written stays where it is.',
        ),
        const SizedBox(height: 16),
        Text(
          'Priced per child — you have ${access.childrenLinked} linked.',
          style: TextStyle(fontSize: 13, color: t.ink2),
        ),
        // These cards price from the static list, so a project on test pricing
        // would advertise the full amount and then charge the reduced one. Said
        // once above the grid rather than on every card.
        if (ref.watch(billingTestModeProvider).valueOrNull == true) ...[
          const SizedBox(height: 10),
          Container(
            key: const Key('parent-test-pricing-warning'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: t.warningSoft,
              borderRadius: t.cardBorderRadius,
            ),
            child: Text(
              'Test pricing is on for this project — the amount actually '
              'charged will be lower than the prices below, and a full period '
              'is still granted.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.warning,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        AsyncValueView<List<ParentPlanOption>>(
          value: plans,
          onRetry: () => ref.invalidate(parentPlansProvider),
          data: (list) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final plan in list)
                SizedBox(
                  width: 240,
                  child: _PlanCard(
                    plan: plan,
                    children: access.childrenLinked,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  const _PlanCard({required this.plan, required this.children});

  final ParentPlanOption plan;
  final int children;

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _busy = false;

  Future<void> _subscribe() async {
    // Ask the server what this costs rather than multiplying on the client;
    // the same figure is recomputed at settlement, so a mismatch would only
    // ever surface as a confusing rejection.
    final quoteResult = await ref
        .read(accessRepositoryProvider)
        .parentPlanQuote(planId: widget.plan.id);
    if (!mounted) return;

    final quote = quoteResult.valueOrNull;
    if (quote == null) {
      _toast(quoteResult.failureOrNull?.message ?? 'Could not price that plan.');
      return;
    }

    final settlement = await showMomoPaymentSheet(
      context,
      title: '${quote.planName} — ${quote.children} '
          '${quote.children == 1 ? 'child' : 'children'}',
      amountRwf: quote.amountRwf,
      purpose: MomoPurpose.parentSubscription,
      initialPhoneNumber: ref
          .read(authControllerProvider)
          .session
          ?.user
          .phoneNumber,
    );
    if (settlement == null || !settlement.isSuccessful || !mounted) return;

    setState(() => _busy = true);
    final error = await ref
        .read(accessActionControllerProvider)
        .settleParentSubscription(
          reference: settlement.reference,
          planId: widget.plan.id,
          amountRwf: settlement.settledAmountRwf ?? quote.amountRwf,
          children: quote.children,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      error ??
          'You are all set for ${quote.periodDays} days. '
          'The AI Tutor is unlocked.',
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final momoReady = ref.watch(appConfigProvider).hasMomo;
    final plan = widget.plan;
    final total = plan.pricePerChildRwf * (widget.children < 1 ? 1 : widget.children);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plan.name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.rwf(plan.pricePerChildRwf),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          Text(
            plan.periodLabel,
            style: TextStyle(fontSize: 12.5, color: t.ink3),
          ),
          const SizedBox(height: 10),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, size: 14, color: t.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(fontSize: 12.5, color: t.ink2),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'You pay ${Formatters.rwf(total)} today.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: t.ink2,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            key: Key('subscribe-${plan.id}'),
            onPressed: !momoReady || _busy ? null : _subscribe,
            child: Text(_busy ? 'Confirming…' : 'Pay with MoMo'),
          ),
          if (!momoReady) ...[
            const SizedBox(height: 8),
            Text(
              'Mobile Money is not set up on this build.',
              style: TextStyle(fontSize: 11.5, color: t.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: t.ink3)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
        ),
      ],
    );
  }
}

class _TopupSection extends ConsumerWidget {
  const _TopupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Want more AI Tutor sessions?'),
        const SizedBox(height: 6),
        Text(
          'Optional top-ups, paid by Mobile Money — never required to keep '
          'learning.',
          style: TextStyle(fontSize: 13, color: t.ink2),
        ),
        const SizedBox(height: 12),
        const _TopupPacks(),
      ],
    );
  }
}

class _TopupPacks extends ConsumerStatefulWidget {
  const _TopupPacks();

  @override
  ConsumerState<_TopupPacks> createState() => _TopupPacksState();
}

class _TopupPacksState extends ConsumerState<_TopupPacks> {
  /// Pack ids credited during this session, so the card can confirm.
  final Set<String> _purchased = {};

  Future<void> _buy(TopupPack pack) async {
    final settlement = await showMomoPaymentSheet(
      context,
      title: pack.label,
      amountRwf: pack.priceRwf,
      purpose: MomoPurpose.tutorTopUp,
      initialPhoneNumber: ref
          .read(authControllerProvider)
          .session
          ?.user
          .phoneNumber,
    );
    if (settlement == null || !settlement.isSuccessful) return;

    // Only credit against a confirmed settlement — never on "sheet closed".
    final credited = await ref
        .read(parentActionControllerProvider)
        .creditTopup(pack: pack, paymentReference: settlement.reference);
    if (!mounted) return;
    if (credited) {
      setState(() => _purchased.add(pack.id));
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${pack.sessions} sessions added — thank you.'),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Payment ${settlement.reference} went through but the sessions '
              'have not been added yet. Support can apply it.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final packs = ref.watch(topupPacksProvider);
    final momoConfigured = ref.watch(appConfigProvider).hasMomo;

    return AsyncValueView<List<TopupPack>>(
      value: packs,
      onRetry: () => ref.invalidate(topupPacksProvider),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!momoConfigured)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Mobile Money is not set up on this build, so top-ups cannot '
                'be bought here yet.',
                style: TextStyle(fontSize: 12.5, color: t.warning),
              ),
            ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final pack in list)
                SizedBox(
                  width: 180,
                  child: _PackCard(
                    pack: pack,
                    purchased: _purchased.contains(pack.id),
                    onBuy: momoConfigured ? () => _buy(pack) : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  const _PackCard({
    required this.pack,
    required this.purchased,
    required this.onBuy,
  });

  final TopupPack pack;
  final bool purchased;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AppCard(
      borderColor: purchased ? t.brand : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            pack.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            Formatters.rwf(pack.priceRwf),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${pack.sessions} extra sessions',
            style: TextStyle(fontSize: 12.5, color: t.ink3),
          ),
          const SizedBox(height: 12),
          if (purchased)
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Added'),
            )
          else
            FilledButton(
              key: Key('topup-${pack.id}'),
              onPressed: onBuy,
              child: const Text('Pay with MoMo'),
            ),
        ],
      ),
    );
  }
}
