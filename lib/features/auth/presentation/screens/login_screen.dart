import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../application/auth_controller.dart';
import '../../application/login_controller.dart';
import '../widgets/auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref.read(loginControllerProvider.notifier).signIn(
          email: _email.text,
          password: _password.text,
        );
    if (!mounted) return;
    result.when(
      success: (_) {}, // router redirects to home automatically
      failure: (f) => _showError(f.message),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final action = ref.watch(loginControllerProvider);
    final busy = action.submitting;

    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue learning.',
      footer: _Footer(busy: busy),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
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
              autofillHints: const [AutofillHints.password],
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
                  : const Text('Sign in'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : () => context.push(AppRoutes.phone),
              icon: const Icon(Icons.sms_outlined),
              label: const Text('Sign in with a phone number'),
              style: OutlinedButton.styleFrom(
                // Width comes from the stretch Column; keep min width finite.
                minimumSize: const Size(64, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends ConsumerWidget {
  const _Footer({required this.busy});
  final bool busy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasOffline =
        ref.watch(authControllerProvider).status.name == 'offlineLocked';

    return Column(
      children: [
        // Wrap (not Row) so it flows onto a second line on narrow windows
        // instead of overflowing.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text("New here?", style: theme.textTheme.bodyMedium),
            TextButton(
              onPressed: busy ? null : () => context.push(AppRoutes.signUp),
              child: const Text('Create an account'),
            ),
          ],
        ),
        if (hasOffline)
          TextButton.icon(
            onPressed: () => context.go(AppRoutes.unlock),
            icon: const Icon(Icons.lock_open_outlined, size: 18),
            label: const Text('Unlock offline with PIN'),
          ),
      ],
    );
  }
}
