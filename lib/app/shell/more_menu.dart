import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/app_platform_style.dart';
import '../../core/router/app_routes.dart';
import '../../core/state/app_language.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/role_providers.dart';
import '../../features/auth/domain/entities/app_role.dart';

/// The kebab menu present on every screen: offline PIN, language, sign out.
///
/// Presented as a bottom sheet on mobile (and in any phone-width window) and a
/// small dialog on desktop, which is what each platform's users expect from an
/// overflow menu.
///
/// Everything an item does — navigate, open a follow-up dialog, write state —
/// runs against the *host* screen's `context` and `ref`, never the sheet's.
/// The sheet is unmounted the moment an item pops it, and a disposed
/// `WidgetRef` throws on use.
Future<void> showMoreMenu(BuildContext context, WidgetRef ref) {
  final platform = ref.read(appPlatformStyleProvider);
  // A phone-width window gets the sheet even on a desktop platform: a 320px
  // dialog centred in a 390px window is a worse target than a bottom sheet.
  final asSheet = platform.isMobile || isCompactChrome(context);
  final sheet = _MoreSheet(asSheet: asSheet, host: context, hostRef: ref);
  if (asSheet) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(child: SizedBox(width: 320, child: sheet)),
  );
}

class _MoreSheet extends ConsumerWidget {
  const _MoreSheet({
    required this.asSheet,
    required this.host,
    required this.hostRef,
  });

  /// Drawn as a bottom sheet (rounded top, drag handle) rather than a dialog.
  final bool asSheet;

  /// The screen that opened this menu — the anchor for follow-up navigation.
  final BuildContext host;

  /// The host's ref, which outlives this sheet.
  final WidgetRef hostRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final language =
        ref.watch(appLanguageProvider).valueOrNull ?? AppLanguage.english;
    final role = ref.watch(activeRoleProvider);

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: asSheet
            ? const BorderRadius.vertical(top: Radius.circular(20))
            : BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(6, 10, 6, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (asSheet)
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: t.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          // Linking is reachable from both shells that can own one side of a
          // family link. A school admin has no side to own — they invite the
          // parent from the People tab instead.
          if (role != AppRole.schoolAdmin)
            _MoreItem(
              icon: Icons.family_restroom_outlined,
              label: switch (role) {
                AppRole.parent => 'My children',
                // A teacher reaches the same page to redeem the code that makes
                // them a teacher in the first place.
                AppRole.teacher => 'Enter a code',
                _ => 'My parents',
              },
              onTap: () {
                Navigator.of(context).pop();
                host.push(AppRoutes.family);
              },
            ),
          _MoreItem(
            icon: Icons.lock_outline,
            label: 'Set / change offline PIN',
            onTap: () {
              Navigator.of(context).pop();
              host.push(AppRoutes.setPin);
            },
          ),
          _MoreItem(
            icon: Icons.language_outlined,
            label: 'Language: ${language.label}',
            onTap: () {
              Navigator.of(context).pop();
              _pickLanguage(language);
            },
          ),
          // Role is a property of the signed-in identity in production. This
          // switcher exists only so the parent / school-admin shells are
          // reachable on a debug build without three real accounts.
          if (kDebugMode)
            _MoreItem(
              icon: Icons.switch_account_outlined,
              label: 'View as (debug)',
              onTap: () {
                Navigator.of(context).pop();
                _pickRole();
              },
            ),
          _MoreItem(
            icon: Icons.logout,
            label: 'Sign out',
            danger: true,
            onTap: () {
              Navigator.of(context).pop();
              hostRef.read(roleOverrideProvider.notifier).state = null;
              hostRef.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(AppLanguage current) async {
    final picked = await showDialog<AppLanguage>(
      context: host,
      builder: (ctx) => SimpleDialog(
        title: const Text('Language'),
        children: [
          for (final l in AppLanguage.values)
            ListTile(
              title: Text(l.label),
              trailing: l == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(ctx).pop(l),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await hostRef.read(appLanguageProvider.notifier).select(picked);
  }

  Future<void> _pickRole() async {
    final current = hostRef.read(activeRoleProvider);
    final picked = await showDialog<AppRole>(
      context: host,
      builder: (ctx) => SimpleDialog(
        title: const Text('View as'),
        children: [
          for (final r in AppRole.values)
            ListTile(
              title: Text(r.label),
              trailing: r == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(ctx).pop(r),
            ),
        ],
      ),
    );
    if (picked == null || !host.mounted) return;
    hostRef.read(roleOverrideProvider.notifier).state = picked;
    host.go(AppRoutes.homeFor(picked));
  }
}

class _MoreItem extends StatelessWidget {
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    final color = danger ? t.danger : t.ink;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            // Expanded, not a bare Text: the desktop menu is only 320px wide
            // and these labels are long.
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
