import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/config/config_providers.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/domain/entities/access_state.dart';
import '../../../access/domain/entities/payment_quote.dart';
import '../../../access/presentation/widgets/access_gate.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../payments/domain/entities/momo_payment.dart';
import '../../../payments/presentation/widgets/momo_payment_sheet.dart';
import '../../../schools/presentation/widgets/schools_dialogs.dart';
import '../../application/billing_providers.dart';
import '../../domain/entities/billing_entities.dart';

/// The school's licence: what state it is in, what it costs, and how to pay it.
///
/// This screen is the whole B2B revenue line, so it always answers three
/// questions in order — where do I stand, what do I owe, and where do I press.
/// A director who has just signed up sees the school-creation step here instead
/// of an empty dashboard.
class AdminLicenseScreen extends ConsumerWidget {
  const AdminLicenseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessStateProvider);

    return ShellContent(
      child: AsyncValueView<AccessState>(
        value: access,
        onRetry: () => ref.invalidate(accessStateProvider),
        data: (state) => ListView(
          children: [
            if (!state.hasSchool)
              const _CreateSchoolCard()
            else ...[
              const AccessNotice(),
              _StatusCard(access: state),
              const SizedBox(height: 16),
              _SeatsCard(access: state),
              const SizedBox(height: 16),
              const _PayCard(),
            ],
            const SizedBox(height: 20),
            const SectionTitle('Plans'),
            const SizedBox(height: 10),
            _Tiers(currentTierId: state.tierId),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Step one for a brand-new director. Creating the school is what starts the
/// trial clock — there is no state in which a school exists and is not on a
/// licence, because the server creates one by trigger.
class _CreateSchoolCard extends ConsumerWidget {
  const _CreateSchoolCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(icon: Icons.business_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Create your school',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your 30-day trial starts the moment the school exists. '
                      'Add classes, share the join code with your teachers, '
                      'and pay only when the trial ends.',
                      style: TextStyle(fontSize: 13.5, color: t.ink2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('create-school-cta'),
            onPressed: () => showCreateSchoolDialog(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Create school & start trial'),
          ),
        ],
      ),
    );
  }
}

/// Where the licence stands: status, what it costs, when it runs out.
class _StatusCard extends ConsumerWidget {
  const _StatusCard({required this.access});

  final AccessState access;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(schoolLicenseQuoteProvider).valueOrNull;
    final until = access.validUntil;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  access.schoolName ?? 'Your school',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.read(context).ink,
                  ),
                ),
              ),
              AppBadge(
                access.licenseStatus.label,
                tone: switch (access.licenseStatus) {
                  LicenseStatus.active => AppTone.success,
                  LicenseStatus.trialing => AppTone.brand,
                  LicenseStatus.pastDue ||
                  LicenseStatus.expired => AppTone.danger,
                  _ => AppTone.neutral,
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Fact(
                  label: 'Plan',
                  value: quote?.tierName ?? access.tierId ?? '—',
                ),
              ),
              Expanded(
                child: _Fact(
                  label: 'Monthly cost',
                  // An empty roster costs nothing; the quote's one-seat floor
                  // would otherwise read as a real monthly charge.
                  value:
                      quote == null ||
                          (access.seatsUsed == 0 && access.seatsPurchased == 0)
                      ? '—'
                      : Formatters.rwf(quote.amountRwf),
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
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: t.ink,
          ),
        ),
      ],
    );
  }
}

/// Seats bought against seats the roster actually consumes.
///
/// Both numbers come from the server — the used figure is counted from
/// memberships — so this card and the People tab cannot disagree.
class _SeatsCard extends StatelessWidget {
  const _SeatsCard({required this.access});

  final AccessState access;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final purchased = access.seatsPurchased;
    final used = access.seatsUsed;
    final ratio = purchased <= 0
        ? (used > 0 ? 1.0 : 0.0)
        : (used / purchased).clamp(0.0, 1.0);
    final over = used > purchased;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Seats used',
            trailing: Text(
              '${Formatters.thousands(used)} / '
              '${Formatters.thousands(purchased)}',
              style: TextStyle(fontSize: 13, color: t.ink3),
            ),
          ),
          const SizedBox(height: 10),
          BarTrack(value: ratio, color: over ? t.warning : t.brand),
          const SizedBox(height: 10),
          Text(
            switch ((over: over, trial: access.overTrialCap)) {
              (over: _, trial: true) =>
                'Your roster has passed the ${access.trialSeatCap}-student '
                    'trial cap. Pay the licence to keep every student covered.',
              (over: true, trial: false) =>
                'You have enrolled more students than you have bought seats '
                    'for — the next payment is billed on students enrolled.',
              _ =>
                'Billed monthly by Mobile Money, on students actually '
                    'enrolled. Add seats on the People tab.',
            },
            style: TextStyle(
              fontSize: 12.5,
              color: over || access.overTrialCap ? t.warning : t.ink3,
            ),
          ),
        ],
      ),
    );
  }
}

/// The payment itself: a server-priced quote and one button that collects it.
class _PayCard extends ConsumerWidget {
  const _PayCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final quote = ref.watch(schoolLicenseQuoteProvider);
    final access = ref.watch(accessSnapshotProvider);

    // Nothing enrolled and nothing bought means there is genuinely nothing to
    // bill. The server floors a quote at one seat so it never asks for 0 RWF,
    // but showing "1 students × 1,500 RWF" to a school with an empty roster
    // invents a student — so the ask here is to enrol or buy seats first.
    final nothingToBill = access.seatsUsed == 0 && access.seatsPurchased == 0;

    return AsyncValueView<SchoolLicenseQuote>(
      value: quote,
      onRetry: () => ref.invalidate(schoolLicenseQuoteProvider),
      data: (q) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SectionTitle(
              nothingToBill
                  ? 'Nothing to pay yet'
                  : access.isTrialing
                        ? 'Activate now'
                        : 'Pay the licence',
            ),
            const SizedBox(height: 6),
            if (nothingToBill)
              Text(
                'Your roster is empty, so there are no seats to bill. Enrol '
                'students with a class join code, or buy seats up front on the '
                'People tab — the licence is priced from whichever is larger.',
                style: TextStyle(fontSize: 13, color: t.ink2),
              )
            else ...[
              Text(
                '${Formatters.thousands(q.seats)} '
                '${q.seats == 1 ? 'student' : 'students'} × '
                '${Formatters.rwf(q.pricePerSeatRwf)} = '
                '${Formatters.rwf(q.fullAmountRwf ?? q.amountRwf)} '
                'for ${q.periodDays} days.',
                style: TextStyle(fontSize: 13, color: t.ink2),
              ),
              // Test pricing charges real money, just less of it. Saying so on
              // the button's own card is the only thing standing between a
              // discounted project and a school that thinks it paid in full.
              if (q.testMode) ...[
                const SizedBox(height: 6),
                _TestPricingWarning(quote: q),
              ],
              const SizedBox(height: 4),
              Text(
                // Paying early must never cost a school the days it already has.
                access.isTrialing
                    ? 'Paying during the trial adds a full period — you keep '
                          'the trial days you have left.'
                    : 'Adds ${q.periodDays} days from today.',
                style: TextStyle(fontSize: 12, color: t.ink3),
              ),
              const SizedBox(height: 14),
              const _PayButton(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Says, on the card that holds the pay button, that this project is charging a
/// reduced amount.
///
/// Test pricing moves real money — MTN really debits the payer — so the danger
/// is not the charge, it is a project left discounted where somebody could take
/// a school's payment and record a full period for 100 RWF.
class _TestPricingWarning extends StatelessWidget {
  const _TestPricingWarning({required this.quote});

  final SchoolLicenseQuote quote;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final full = quote.fullAmountRwf;
    return Container(
      key: const Key('test-pricing-warning'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.warningSoft,
        borderRadius: t.cardBorderRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.science_outlined, size: 16, color: t.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Test pricing is on for this project: you will be charged '
              '${Formatters.rwf(quote.amountRwf)}'
              '${full == null ? '' : ' instead of ${Formatters.rwf(full)}'}, '
              'and a full period will be granted. Turn it off with '
              'select disable_test_pricing(); before going live.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: t.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayButton extends ConsumerStatefulWidget {
  const _PayButton();

  @override
  ConsumerState<_PayButton> createState() => _PayButtonState();
}

class _PayButtonState extends ConsumerState<_PayButton> {
  bool _busy = false;

  Future<void> _pay() async {
    final quote = ref.read(schoolLicenseQuoteProvider).valueOrNull;
    if (quote == null) return;

    final settlement = await showMomoPaymentSheet(
      context,
      title: '${quote.tierName} licence — ${quote.seats} students',
      amountRwf: quote.amountRwf,
      purpose: MomoPurpose.schoolLicense,
      initialPhoneNumber: ref
          .read(authControllerProvider)
          .session
          ?.user
          .phoneNumber,
    );
    // Only a confirmed settlement activates anything. A closed sheet is not a
    // payment, and a pending one is not either.
    if (settlement == null || !settlement.isSuccessful || !mounted) return;

    setState(() => _busy = true);
    final error = await ref
        .read(accessActionControllerProvider)
        .settleSchoolLicense(
          reference: settlement.reference,
          // MTN's own figure is trusted over the requested one; the server
          // rejects it if it falls short of the quote.
          amountRwf: settlement.settledAmountRwf ?? quote.amountRwf,
          seats: quote.seats,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                'Licence active. Every enrolled student has full access again.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final momoReady = ref.watch(appConfigProvider).hasMomo;
    final t = AppTokens.read(context);

    if (!momoReady) {
      return Text(
        'Mobile Money is not set up on this build, so the licence cannot be '
        'paid here yet.',
        style: TextStyle(fontSize: 12.5, color: t.warning),
      );
    }
    return FilledButton.icon(
      key: const Key('pay-license-button'),
      onPressed: _busy ? null : _pay,
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.phone_iphone, size: 16),
      label: Text(_busy ? 'Recording…' : 'Pay with MoMo'),
    );
  }
}

class _Tiers extends ConsumerWidget {
  const _Tiers({required this.currentTierId});

  final String? currentTierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiers = ref.watch(planTiersProvider);
    final access = ref.watch(accessSnapshotProvider);

    return AsyncValueView<List<PlanTier>>(
      value: tiers,
      onRetry: () => ref.invalidate(planTiersProvider),
      data: (list) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final tier in list)
            SizedBox(
              width: 240,
              child: _TierCard(
                tier: tier,
                current: tier.id == currentTierId,
                // Switching tiers is a licence write, so it needs a school to
                // write against.
                onSwitch: access.hasSchool
                    ? () => _switch(context, ref, tier)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _switch(
    BuildContext context,
    WidgetRef ref,
    PlanTier tier,
  ) async {
    final error = await ref
        .read(accessActionControllerProvider)
        .selectSchoolTier(tier.id);
    if (!context.mounted || error == null) return;
    // The server refuses a tier that cannot hold the current roster, and
    // phrases the reason itself.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.tier,
    required this.current,
    required this.onSwitch,
  });

  final PlanTier tier;
  final bool current;
  final VoidCallback? onSwitch;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AppCard(
      borderColor: current ? t.brand : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tier.name,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
              ),
              if (current) const AppBadge('Current'),
            ],
          ),
          const SizedBox(height: 6),
          // One rich line rather than a Row: a long price plus the unit
          // overflows a 240px card when they are laid out as siblings.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: Formatters.thousands(tier.pricePerSeatRwf),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: t.ink,
                  ),
                ),
                TextSpan(
                  text: ' RWF/student',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: t.ink2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tier.seatsLabel,
            style: TextStyle(fontSize: 12.5, color: t.ink3),
          ),
          const SizedBox(height: 12),
          for (final feature in tier.features)
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
          const SizedBox(height: 8),
          if (current)
            const OutlinedButton(onPressed: null, child: Text('Current plan'))
          else
            FilledButton(
              key: Key('switch-tier-${tier.id}'),
              onPressed: onSwitch,
              child: const Text('Switch plan'),
            ),
        ],
      ),
    );
  }
}
