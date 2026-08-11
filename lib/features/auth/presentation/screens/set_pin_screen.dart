import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/auth_controller.dart';
import '../widgets/auth_scaffold.dart';

/// Lets a signed-in user set the PIN that will unlock the app offline.
class SetPinScreen extends ConsumerStatefulWidget {
  const SetPinScreen({super.key});

  @override
  ConsumerState<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends ConsumerState<SetPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final result =
        await ref.read(authControllerProvider.notifier).setOfflinePin(_pin.text);
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline PIN saved.')),
        );
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Set an offline PIN',
      subtitle: 'Use this 4–8 digit PIN to open EduAI when you have no '
          'internet connection.',
      footer: TextButton(
        onPressed: _busy ? null : () => context.pop(),
        child: const Text('Not now'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _pin,
              enabled: !_busy,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'New PIN',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              validator: (v) => (v == null || v.length < 4)
                  ? 'PIN must be 4–8 digits'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              enabled: !_busy,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 8,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onFieldSubmitted: (_) => _busy ? null : _save(),
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Confirm PIN',
                prefixIcon: Icon(Icons.pin_outlined),
              ),
              validator: (v) => v != _pin.text ? 'PINs do not match' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
