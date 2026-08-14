import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/shell/detail_scaffold.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../auth/application/role_providers.dart';
import '../../../auth/domain/entities/app_role.dart';
import '../../application/linking_providers.dart';
import '../../domain/entities/family_link.dart';

/// Where a family gets connected, from either side.
///
/// A parent lands here to add a child (or to redeem the code their school gave
/// them). A student lands here to redeem the code their parent read out. Both
/// end in the same place — a row in `parent_students` — so both live on one
/// page rather than two that could drift apart.
class FamilyLinksScreen extends ConsumerWidget {
  const FamilyLinksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);
    final isParent = role == AppRole.parent;

    return DetailScaffold(
      title: isParent ? 'My children' : 'My parents',
      child: ListView(
        children: [
          TrustBanner(
            icon: Icons.family_restroom_outlined,
            title: isParent
                ? 'Two ways to link a child'
                : 'Let a parent follow your progress',
            body: isParent
                ? "Enter the code your child's school gave you, or send your "
                      'own code for your child to type in. Either way you see '
                      'their reports — never their private chats.'
                : 'Type the code your parent gives you. They will see your '
                      'weekly progress. You can remove them at any time, and '
                      'they never see your tutor conversations.',
          ),
          const SizedBox(height: 16),
          const _RedeemCard(),
          const SizedBox(height: 20),
          if (isParent) ...[
            const _InviteChildCard(),
            const SizedBox(height: 20),
          ],
          SectionTitle(isParent ? 'Linked children' : 'Linked parents'),
          const SizedBox(height: 10),
          const _LinksList(),
          const SizedBox(height: 20),
          const _PendingInvitesList(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Enter a code somebody else generated. Works for both invite directions —
/// the server decides which side of the link the signed-in account fills in.
class _RedeemCard extends ConsumerStatefulWidget {
  const _RedeemCard();

  @override
  ConsumerState<_RedeemCard> createState() => _RedeemCardState();
}

class _RedeemCardState extends ConsumerState<_RedeemCard> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = await ref
        .read(linkingActionControllerProvider.notifier)
        .redeemCode(_code.text);
    if (!mounted) return;
    result.when(
      success: (_) {
        _code.clear();
        _toast('Linked. Reports will appear within a day of activity.');
      },
      // The server's messages are written to be read ("that invite has
      // expired — ask for a new code"), so they are shown as they are.
      failure: (f) => _toast(f.message),
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
    final busy = ref.watch(linkingActionControllerProvider).busy;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SectionTitle('I have a code'),
          const SizedBox(height: 10),
          TextField(
            key: const Key('redeem-code-field'),
            controller: _code,
            enabled: !busy,
            textCapitalization: TextCapitalization.characters,
            // The codes are generated from this alphabet, so anything else is
            // a typo — reject it at the keyboard rather than at the server.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
              LengthLimitingTextInputFormatter(12),
              TextInputFormatter.withFunction(
                (_, next) => next.copyWith(text: next.text.toUpperCase()),
              ),
            ],
            onSubmitted: (_) => busy ? null : _submit(),
            decoration: const InputDecoration(
              labelText: 'Invite code',
              hintText: 'e.g. K4MPQ7A',
              prefixIcon: Icon(Icons.vpn_key_outlined),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('redeem-code-button'),
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Linking…' : 'Link us'),
          ),
          const SizedBox(height: 8),
          Text(
            'Codes last 30 days and work once.',
            style: TextStyle(fontSize: 12, color: t.ink3),
          ),
        ],
      ),
    );
  }
}

/// Mint a code for this parent's own child.
class _InviteChildCard extends ConsumerStatefulWidget {
  const _InviteChildCard();

  @override
  ConsumerState<_InviteChildCard> createState() => _InviteChildCardState();
}

class _InviteChildCardState extends ConsumerState<_InviteChildCard> {
  final _contact = TextEditingController();
  String? _lastCode;

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = await ref
        .read(linkingActionControllerProvider.notifier)
        .inviteChild(contact: _contact.text);
    if (!mounted) return;
    result.when(
      success: (invite) => setState(() => _lastCode = invite.code),
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final busy = ref.watch(linkingActionControllerProvider).busy;
    final code = _lastCode;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SectionTitle('Invite my child'),
          const SizedBox(height: 6),
          Text(
            'Your child creates their own student account, then types this '
            'code in under "My parents".',
            style: TextStyle(fontSize: 13, color: t.ink2),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('invite-child-contact'),
            controller: _contact,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: "Child's phone or email (optional)",
              hintText: 'Helps you remember who a code was for',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const Key('invite-child-button'),
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Creating…' : 'Create a code'),
          ),
          if (code != null) ...[
            const SizedBox(height: 14),
            _CodeChip(code: code),
          ],
        ],
      ),
    );
  }
}

/// A generated code, big enough to read out loud and tappable to copy.
class _CodeChip extends StatelessWidget {
  const _CodeChip({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return SunkenCard(
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              code,
              key: const Key('generated-invite-code'),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                color: t.ink,
              ),
            ),
          ),
          ToolIconButton(
            icon: Icons.copy_outlined,
            tooltip: 'Copy code',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(content: Text('Code copied.')));
            },
          ),
        ],
      ),
    );
  }
}

class _LinksList extends ConsumerWidget {
  const _LinksList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final links = ref.watch(familyLinksProvider);
    final isParent = ref.watch(activeRoleProvider) == AppRole.parent;

    return AsyncValueView<List<FamilyLink>>(
      value: links,
      onRetry: () => ref.invalidate(familyLinksProvider),
      isEmpty: (list) => list.isEmpty,
      emptyBuilder: () => SunkenCard(
        child: Text(
          isParent
              ? 'No children linked yet. Use a code above to add one.'
              : 'No parents linked. Ask a parent for their code.',
          style: TextStyle(
            fontSize: 13,
            color: AppTokens.read(context).ink3,
          ),
        ),
      ),
      data: (list) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final link in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LinkRow(link: link, canUnlink: isParent),
            ),
        ],
      ),
    );
  }
}

class _LinkRow extends ConsumerWidget {
  const _LinkRow({required this.link, required this.canUnlink});

  final FamilyLink link;
  final bool canUnlink;

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
                  link.displayName ?? 'Account',
                  style: TextStyle(fontWeight: FontWeight.w700, color: t.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  link.createdBySchool
                      ? 'Linked by the school'
                      : 'Linked by you',
                  style: TextStyle(fontSize: 12.5, color: t.ink3),
                ),
              ],
            ),
          ),
          if (canUnlink)
            OutlinedButton(
              onPressed: () => _confirmUnlink(context, ref),
              child: const Text('Remove'),
            ),
        ],
      ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context, WidgetRef ref) async {
    final name = link.displayName ?? 'this account';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove this link?'),
        content: Text(
          "You will stop seeing $name's reports. Their lessons, workbook and "
          'progress are not affected, and you can link again with a new code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final result = await ref
        .read(linkingActionControllerProvider.notifier)
        .unlink(link.id);
    if (!context.mounted) return;
    final failure = result.failureOrNull;
    if (failure != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _PendingInvitesList extends ConsumerWidget {
  const _PendingInvitesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final pending = ref.watch(pendingInvitesProvider).valueOrNull ?? const [];
    final open = pending.where((i) => !i.isExpired()).toList();
    if (open.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Codes waiting to be used'),
        const SizedBox(height: 10),
        for (final invite in open)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          invite.code,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                            color: t.ink,
                          ),
                        ),
                        if (invite.contact != null)
                          Text(
                            invite.contact!,
                            style: TextStyle(fontSize: 12.5, color: t.ink3),
                          ),
                      ],
                    ),
                  ),
                  const AppBadge('Pending', tone: AppTone.warning),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
