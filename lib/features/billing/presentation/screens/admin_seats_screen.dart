import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/app_shell.dart';
import '../../../../core/format/formatters.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/presentation/widgets/access_gate.dart';
import '../../../linking/application/linking_providers.dart';
import '../../../linking/domain/entities/family_link.dart';

/// Who occupies the school's seats, and how their parents get connected.
///
/// This replaced a stepper over invented per-class allocations. Seats are not
/// something an admin types in per class — a seat is consumed by an enrolled
/// student, counted server-side from memberships. What an admin *does* control
/// is how many seats the school has bought, which is the one number here that
/// changes the invoice.
class AdminSeatsScreen extends ConsumerWidget {
  const AdminSeatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(accessSnapshotProvider);
    final roster = ref.watch(schoolRosterProvider);

    if (!access.hasSchool) {
      return const ShellContent(
        child: TrustBanner(
          icon: Icons.groups_outlined,
          title: 'No school yet',
          body: 'Create your school on the Licence tab, then enrolled students '
              'appear here.',
        ),
      );
    }

    return ShellContent(
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(schoolRosterProvider),
        child: AsyncValueView<List<RosterEntry>>(
          value: roster,
          onRetry: () => ref.invalidate(schoolRosterProvider),
          data: (list) => ListView(
            children: [
              const AccessNotice(),
              const _SeatsPurchasedCard(),
              const SizedBox(height: 20),
              SectionTitle(
                'Students',
                trailing: AppBadge('${list.length} enrolled'),
              ),
              const SizedBox(height: 6),
              Text(
                'Each enrolled student uses one seat. Invite a parent to give '
                'them read-only access to that child’s weekly report.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTokens.read(context).ink3,
                ),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const _EmptyRoster()
              else
                for (final entry in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RosterRow(entry: entry),
                  ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    return const TrustBanner(
      icon: Icons.person_add_alt_outlined,
      title: 'No students enrolled yet',
      body: 'Create your classes on the school page and share their join codes. '
          'Students who enter a code appear here, and each one takes a seat.',
    );
  }
}

/// The one number on this screen that changes what the school pays.
class _SeatsPurchasedCard extends ConsumerStatefulWidget {
  const _SeatsPurchasedCard();

  @override
  ConsumerState<_SeatsPurchasedCard> createState() =>
      _SeatsPurchasedCardState();
}

class _SeatsPurchasedCardState extends ConsumerState<_SeatsPurchasedCard> {
  bool _busy = false;

  Future<void> _adjust(int delta) async {
    final access = ref.read(accessSnapshotProvider);
    final target = access.seatsPurchased + delta;
    if (target < 0) return;

    setState(() => _busy = true);
    final error = await ref
        .read(accessActionControllerProvider)
        .setSeatsPurchased(target);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) return;
    // The server refuses more seats than the tier allows, in its own words.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final access = ref.watch(accessSnapshotProvider);
    final quote = ref.watch(schoolLicenseQuoteProvider).valueOrNull;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SectionTitle('Seats bought'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Formatters.thousands(access.seatsUsed)} of '
                  '${Formatters.thousands(access.seatsPurchased)} in use',
                  style: TextStyle(fontSize: 13.5, color: t.ink2),
                ),
              ),
              ToolIconButton(
                key: const Key('seats-minus'),
                icon: Icons.remove,
                tooltip: 'Buy ${AccessActionController.seatStep} fewer seats',
                onPressed: _busy || access.seatsPurchased == 0
                    ? null
                    : () => _adjust(-AccessActionController.seatStep),
              ),
              SizedBox(
                width: 56,
                child: Text(
                  '${access.seatsPurchased}',
                  key: const Key('seats-purchased-value'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: t.ink,
                  ),
                ),
              ),
              ToolIconButton(
                key: const Key('seats-plus'),
                icon: Icons.add,
                tooltip: 'Buy ${AccessActionController.seatStep} more seats',
                onPressed: _busy
                    ? null
                    : () => _adjust(AccessActionController.seatStep),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            quote == null
                ? 'Billed on students actually enrolled.'
                : 'Next payment: ${Formatters.rwf(quote.amountRwf)} for '
                      '${Formatters.thousands(quote.seats)} students.',
            style: TextStyle(fontSize: 12.5, color: t.ink3),
          ),
        ],
      ),
    );
  }
}

class _RosterRow extends ConsumerWidget {
  const _RosterRow({required this.entry});

  final RosterEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    return AppCard(
      child: Row(
        children: [
          const IconTile(icon: Icons.person_outline),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.studentName,
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.className ?? 'No class yet',
                  style: TextStyle(fontSize: 12.5, color: t.ink3),
                ),
              ],
            ),
          ),
          if (entry.hasParent)
            const AppBadge('Parent linked', tone: AppTone.success)
          else if (entry.invitePending)
            const AppBadge('Invited', tone: AppTone.warning)
          else
            OutlinedButton(
              key: Key('invite-parent-${entry.studentId}'),
              onPressed: () => _inviteParent(context, ref),
              child: const Text('Invite parent'),
            ),
        ],
      ),
    );
  }

  Future<void> _inviteParent(BuildContext context, WidgetRef ref) async {
    final contact = await showDialog<String?>(
      context: context,
      builder: (_) => _InviteParentDialog(studentName: entry.studentName),
    );
    if (contact == null || !context.mounted) return;

    final result = await ref
        .read(linkingActionControllerProvider.notifier)
        .inviteParent(studentId: entry.studentId, contact: contact);
    if (!context.mounted) return;

    result.when(
      // The code is what the parent needs, so it is shown rather than merely
      // "invite sent" — the school reads it out or texts it themselves.
      success: (invite) => showDialog<void>(
        context: context,
        builder: (_) => _InviteCodeDialog(
          code: invite.code,
          studentName: entry.studentName,
        ),
      ),
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }
}

class _InviteParentDialog extends StatefulWidget {
  const _InviteParentDialog({required this.studentName});

  final String studentName;

  @override
  State<_InviteParentDialog> createState() => _InviteParentDialogState();
}

class _InviteParentDialogState extends State<_InviteParentDialog> {
  final _contact = TextEditingController();

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Invite ${widget.studentName}’s parent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'We generate a code for you to give the parent. They create a '
            'parent account and enter it — no data moves until they do.',
          ),
          const SizedBox(height: 14),
          TextField(
            key: const Key('invite-parent-contact'),
            controller: _contact,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Parent phone or email (optional)',
              hintText: 'Recorded so you can tell the codes apart',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_contact.text),
          child: const Text('Create code'),
        ),
      ],
    );
  }
}

class _InviteCodeDialog extends StatelessWidget {
  const _InviteCodeDialog({required this.code, required this.studentName});

  final String code;
  final String studentName;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return AlertDialog(
      title: const Text('Give this code to the parent'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SunkenCard(
            child: SelectableText(
              code,
              key: const Key('parent-invite-code'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: t.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'They sign up as a parent, open “My children” and enter this code '
            'to follow $studentName. It works once and lasts 30 days.',
            style: TextStyle(fontSize: 13, color: t.ink2),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            Navigator.of(context).pop();
          },
          child: const Text('Copy'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
