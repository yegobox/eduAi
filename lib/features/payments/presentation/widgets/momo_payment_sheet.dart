import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../application/momo_payment_controller.dart';
import '../../domain/entities/momo_payment.dart';
import '../../domain/momo_msisdn.dart';

/// Opens the Mobile Money flow for [amountRwf].
///
/// Resolves to the settled payment when MTN confirms it, and to null when the
/// user backs out or the payment does not complete — so callers only grant
/// what was actually paid for.
Future<MomoSettlement?> showMomoPaymentSheet(
  BuildContext context, {
  required String title,
  required int amountRwf,
  required MomoPurpose purpose,
  String? initialPhoneNumber,
}) {
  return showModalBottomSheet<MomoSettlement>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: MomoPaymentSheet(
        title: title,
        amountRwf: amountRwf,
        purpose: purpose,
        initialPhoneNumber: initialPhoneNumber,
      ),
    ),
  );
}

/// Phone entry → PIN prompt → confirmation, for one Mobile Money collection.
class MomoPaymentSheet extends ConsumerStatefulWidget {
  const MomoPaymentSheet({
    super.key,
    required this.title,
    required this.amountRwf,
    required this.purpose,
    this.initialPhoneNumber,
  });

  final String title;
  final int amountRwf;
  final MomoPurpose purpose;
  final String? initialPhoneNumber;

  @override
  ConsumerState<MomoPaymentSheet> createState() => _MomoPaymentSheetState();
}

class _MomoPaymentSheetState extends ConsumerState<MomoPaymentSheet> {
  late final TextEditingController _phone = TextEditingController(
    text: widget.initialPhoneNumber == null
        ? ''
        : MomoMsisdn.toLocal(widget.initialPhoneNumber!),
  );

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final state = ref.watch(momoPaymentControllerProvider);

    // Hand the settlement back as soon as MTN confirms it.
    ref.listen(momoPaymentControllerProvider, (_, next) {
      if (next.stage == MomoStage.confirmed && mounted) {
        Navigator.of(context).pop(next.settlement);
      }
    });

    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const IconTile(icon: Icons.account_balance_wallet_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: t.ink,
                        ),
                      ),
                      Text(
                        '${widget.amountRwf} RWF',
                        style: TextStyle(fontSize: 13, color: t.ink2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Body(
              state: state,
              phone: _phone,
              onPay: () => ref
                  .read(momoPaymentControllerProvider.notifier)
                  .pay(
                    phoneNumber: _phone.text,
                    amountRwf: widget.amountRwf,
                    purpose: widget.purpose,
                  ),
              onRetry: () =>
                  ref.read(momoPaymentControllerProvider.notifier).reset(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.phone,
    required this.onPay,
    required this.onRetry,
  });

  final MomoPaymentState state;
  final TextEditingController phone;
  final VoidCallback onPay;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);

    switch (state.stage) {
      case MomoStage.awaitingApproval:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Check your phone',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Enter your Mobile Money PIN on the prompt we just sent. '
              'This screen updates by itself once you approve.',
              style: TextStyle(fontSize: 13, color: t.ink2),
            ),
            // The gateway sometimes explains, while still reporting PENDING,
            // why the push has not landed — a token or transport failure on its
            // side means no prompt is coming at all. Showing it beats a silent
            // five-minute wait that looks identical to a slow payer.
            if (state.settlement?.reason?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('momo-pending-reason'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.warningSoft,
                  borderRadius: t.cardBorderRadius,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 15, color: t.warning),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SelectableText(
                        'The gateway reports: ${state.settlement!.reason!.trim()}',
                        style: TextStyle(fontSize: 11.5, color: t.warning),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (state.reference != null) ...[
              const SizedBox(height: 10),
              SelectableText(
                'Reference: ${state.reference}',
                style: TextStyle(fontSize: 11.5, color: t.ink3),
              ),
            ],
          ],
        );

      case MomoStage.timedOut:
        return _Outcome(
          icon: Icons.schedule,
          tone: AppTone.warning,
          title: 'Still waiting for your approval',
          // Never claim the payment failed: MTN may settle it minutes later.
          body:
              'We stopped checking after a few minutes. If you approved it, '
              'the sessions will appear shortly — do not pay twice.',
          actionLabel: 'Close',
          onAction: () => Navigator.of(context).pop(),
        );

      case MomoStage.failed:
        return _Outcome(
          icon: Icons.error_outline,
          tone: AppTone.danger,
          title: 'Payment not completed',
          body:
              state.failure?.message ??
              'The payment was not completed on your phone.',
          actionLabel: 'Try again',
          onAction: onRetry,
        );

      case MomoStage.confirmed:
      case MomoStage.idle:
      case MomoStage.initiating:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const Key('momo-phone-field'),
              controller: phone,
              keyboardType: TextInputType.phone,
              enabled: !state.isBusy,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Mobile Money number',
                hintText: '0788123456',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will get a PIN prompt on this number. EduAI never sees '
              'your PIN.',
              style: TextStyle(fontSize: 12.5, color: t.ink3),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('momo-pay-button'),
              onPressed: state.isBusy ? null : onPay,
              icon: state.isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.phone_iphone, size: 16),
              label: Text(state.isBusy ? 'Sending…' : 'Pay with MoMo'),
            ),
          ],
        );
    }
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final AppTone tone;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconTile(icon: icon, tone: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(body, style: TextStyle(fontSize: 13, color: t.ink2)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}
