import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../application/billing_providers.dart';
import '../../domain/entities/billing_entities.dart';

/// The school's Mobile Money payment history.
///
/// Every row is a real MTN request-to-pay reference, so a bursar can match this
/// against their own statement. It used to be three hardcoded "Paid" invoices,
/// which told a school its licence was settled when nothing had been collected.
class AdminInvoicesScreen extends ConsumerWidget {
  const AdminInvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final invoices = ref.watch(invoicesProvider);

    return ShellContent(
      child: AsyncValueView<List<Invoice>>(
        value: invoices,
        onRetry: () => ref.invalidate(invoicesProvider),
        isEmpty: (list) => list.isEmpty,
        emptyBuilder: () => const TrustBanner(
          icon: Icons.description_outlined,
          title: 'No payments yet',
          body: 'Once you pay the licence on the Licence tab, every Mobile '
              'Money payment appears here with its MTN reference.',
        ),
        data: (list) => ListView(
          children: [
            const SectionTitle('Payment history'),
            const SizedBox(height: 12),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const _HeaderRow(),
                  for (final invoice in list) _InvoiceRow(invoice: invoice),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Paid via MTN Mobile Money. The reference is MTN’s own '
              'transaction id — quote it to support if a payment needs '
              'checking.',
              style: TextStyle(fontSize: 12.5, color: t.ink2),
            ),
            if (list.any((i) => i.state == PaymentState.disputed)) ...[
              const SizedBox(height: 10),
              Text(
                'A row marked “Check” settled for less than the licence cost, '
                'so it did not activate. Support can reconcile it — the money '
                'is not lost.',
                style: TextStyle(fontSize: 12.5, color: t.warning),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: t.ink3,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('REFERENCE', style: style)),
          Expanded(flex: 3, child: Text('DATE', style: style)),
          Expanded(flex: 3, child: Text('AMOUNT', style: style)),
          Expanded(flex: 2, child: Text('STATUS', style: style)),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({required this.invoice});

  final Invoice invoice;

  static AppTone _toneFor(PaymentState state) => switch (state) {
    PaymentState.settled => AppTone.success,
    PaymentState.pending => AppTone.warning,
    PaymentState.disputed => AppTone.warning,
    PaymentState.failed => AppTone.danger,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      // Rule above each row separates it from the header / previous row; the
      // last row needs no rule below it because the card edge does that job.
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  invoice.shortReference,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                if (invoice.seats != null)
                  Text(
                    '${invoice.seats} students'
                    '${invoice.tierName == null ? '' : ' · ${invoice.tierName}'}',
                    style: TextStyle(fontSize: 11.5, color: t.ink3),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              Formatters.shortDate(invoice.issuedOn),
              style: TextStyle(fontSize: 13.5, color: t.ink3),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              Formatters.rwf(invoice.amountRwf),
              style: TextStyle(fontSize: 13.5, color: t.ink),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppBadge(
                invoice.state.label,
                tone: _toneFor(invoice.state),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
