import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/login_controller.dart';
import '../widgets/auth_scaffold.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref.read(loginControllerProvider.notifier).signUp(
          email: _email.text,
          password: _password.text,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Check your email to confirm, then sign in.',
            ),
          ),
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
    final busy = ref.watch(loginControllerProvider).submitting;

    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Start building your learning workspace.',
      footer: TextButton(
        onPressed: busy ? null : () => context.pop(),
        child: const Text('Already have an account? Sign in'),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              enabled: !busy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name (optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              enabled: !busy,
              obscureText: _obscure,
              onFieldSubmitted: (_) => busy ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.length < 6) ? 'At least 6 characters' : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}
