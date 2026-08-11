import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Offline unlock: verify the local PIN to restore the cached session with no
/// network. Also offers an escape hatch to attempt an online sign-in.
class OfflineUnlockScreen extends ConsumerStatefulWidget {
  const OfflineUnlockScreen({super.key});

  @override
  ConsumerState<OfflineUnlockScreen> createState() =>
      _OfflineUnlockScreenState();
}

class _OfflineUnlockScreenState extends ConsumerState<OfflineUnlockScreen> {
  final _pin = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final result =
        await ref.read(authControllerProvider.notifier).unlockOffline(_pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {}, // router redirects to home
      failure: (f) {
        _pin.clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = ref.watch(authControllerProvider).offlineLabel;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: label == null
          ? 'Enter your offline PIN to continue.'
          : 'Enter the offline PIN for $label.',
      footer: TextButton.icon(
        onPressed: _busy ? null : () => context.go(AppRoutes.login),
        icon: const Icon(Icons.wifi, size: 18),
        label: const Text('Sign in online instead'),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _pin,
            enabled: !_busy,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            onSubmitted: (_) => _busy ? null : _unlock(),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _unlock,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Unlock'),
          ),
        ],
      ),
    );
  }
}
