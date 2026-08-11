import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/phone_login_controller.dart';
import '../widgets/auth_scaffold.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController(text: '+250');
  final _code = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneLoginControllerProvider);
    final controller = ref.read(phoneLoginControllerProvider.notifier);
    final busy = state.submitting;

    // Surface failures as they arrive.
    ref.listen(phoneLoginControllerProvider.select((s) => s.failure),
        (prev, next) {
      if (next != null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.message)));
      }
    });

    final isCodeStep = state.phase == PhonePhase.enterCode;

    return AuthScaffold(
      title: isCodeStep ? 'Enter the code' : 'Sign in with SMS',
      subtitle: isCodeStep
          ? 'We sent a 6-digit code to ${state.challenge?.phoneNumber ?? ''}.'
          : 'We’ll text you a one-time code.',
      footer: TextButton(
        onPressed: busy
            ? null
            : () {
                if (isCodeStep) {
                  controller.reset();
                } else {
                  context.pop();
                }
              },
        child: Text(isCodeStep ? 'Use a different number' : 'Back to sign in'),
      ),
      child: isCodeStep
          ? _CodeStep(
              controller: _code,
              busy: busy,
              onVerify: () async {
                final result = await controller.verifyCode(_code.text);
                if (!mounted) return;
                result.when(success: (_) {}, failure: (_) {});
              },
            )
          : _PhoneStep(
              controller: _phone,
              busy: busy,
              onSend: () => controller.sendCode(_phone.text),
            ),
    );
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: !busy,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Phone number',
            hintText: '+250 7xx xxx xxx',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onSend,
          child: busy
              ? const _Spinner()
              : const Text('Send code'),
        ),
      ],
    );
  }
}

class _CodeStep extends StatelessWidget {
  const _CodeStep({
    required this.controller,
    required this.busy,
    required this.onVerify,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          enabled: !busy,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
          decoration: const InputDecoration(
            counterText: '',
            hintText: '••••••',
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: busy ? null : onVerify,
          child: busy ? const _Spinner() : const Text('Verify & continue'),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
}
