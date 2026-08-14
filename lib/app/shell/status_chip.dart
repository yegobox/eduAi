import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/connectivity_service.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_widgets.dart';
import '../../features/auth/application/auth_controller.dart';

/// Online / Offline pill shown in every screen header.
///
/// An offline *session* (unlocked with the PIN, no live server session) is
/// called out separately from merely having no transport, because it changes
/// which actions will work.
class StatusChip extends ConsumerWidget {
  const StatusChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offlineSession =
        ref.watch(authControllerProvider.select((s) => s.session?.isOffline)) ??
        false;
    final network = ref.watch(networkStatusProvider).valueOrNull;
    final noTransport = network == NetworkStatus.offline;
    final degraded = offlineSession || noTransport;

    return SoftChip(
      offlineSession ? 'Offline session' : (degraded ? 'Offline' : 'Online'),
      icon: degraded ? Icons.cloud_off : Icons.cloud_done_outlined,
      tone: degraded ? AppTone.warning : AppTone.success,
    );
  }
}

/// Compact desktop variant: a dot + label, sized for a 30px toolbar.
class StatusDot extends ConsumerWidget {
  const StatusDot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.read(context);
    final offlineSession =
        ref.watch(authControllerProvider.select((s) => s.session?.isOffline)) ??
        false;
    final network = ref.watch(networkStatusProvider).valueOrNull;
    final degraded = offlineSession || network == NetworkStatus.offline;
    final color = degraded ? t.warning : t.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          degraded ? 'Offline' : 'Online',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.ink2,
          ),
        ),
      ],
    );
  }
}
