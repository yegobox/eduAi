import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../application/login_controller.dart';
import '../../domain/entities/app_role.dart';
import '../widgets/auth_scaffold.dart';

/// Account creation — and the one place the three product surfaces fork.
///
/// The role picker is not a convenience. A parent account, a student account
/// and a school-admin account are different identities with different shells
/// and different billing, and nothing downstream can guess which one somebody
/// meant. Asking here, once, is what replaced "everybody is a student".
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

  /// Students are the overwhelming majority of accounts, so they are the
  /// default — the two paying roles are the deliberate choice.
  AppRole _role = AppRole.student;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref
        .read(loginControllerProvider.notifier)
        .signUp(
          email: _email.text,
          password: _password.text,
          role: _role,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_confirmationFor(_role))),
        );
        context.pop();
      },
      failure: (f) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  /// Says what happens next, per role, so nobody signs in expecting the wrong
  /// screen. A director in particular needs to know a school comes next.
  String _confirmationFor(AppRole role) => switch (role) {
    AppRole.student =>
      'Account created. Confirm your email, sign in, then join your school '
          'with the code your teacher gave you.',
    AppRole.parent =>
      'Account created. Confirm your email, sign in, then link your child '
          'with a code.',
    AppRole.schoolAdmin =>
      'Account created. Confirm your email, sign in, then create your school '
          'to start a 30-day trial.',
    // Not reachable: the picker does not offer it, because a teacher is made by
    // redeeming a code their school minted. Handled so the switch stays
    // exhaustive rather than falling through to a wildcard.
    AppRole.teacher =>
      'Account created. Sign in, then enter the teacher code your school gave '
          'you.',
  };

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
            _RolePicker(
              selected: _role,
              enabled: !busy,
              onChanged: (role) => setState(() => _role = role),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              enabled: !busy,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _role == AppRole.schoolAdmin
                    ? 'Your name (optional)'
                    : 'Name (optional)',
                prefixIcon: const Icon(Icons.person_outline),
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
              validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
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
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
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
                  : Text(_role == AppRole.schoolAdmin
                      ? 'Create account & start trial'
                      : 'Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One card per role, each stating plainly what that account does and who
/// pays. Cards rather than a dropdown: this choice decides which app somebody
/// gets, and it is not recoverable from the client afterwards.
class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final AppRole selected;
  final bool enabled;
  final ValueChanged<AppRole> onChanged;

  /// The roles somebody may choose for themselves. Teacher is absent on
  /// purpose: it is granted by redeeming a code the school minted, because a
  /// self-declared teacher is a stranger asking to read children's progress.
  static const _offered = [
    AppRole.student,
    AppRole.parent,
    AppRole.schoolAdmin,
  ];

  static const _copy = {
    AppRole.student: (
      icon: Icons.school_outlined,
      title: 'I am a student',
      body: 'Learn with the AI Tutor. Free when your school or a parent pays.',
    ),
    AppRole.parent: (
      icon: Icons.family_restroom_outlined,
      title: 'I am a parent',
      body:
          "Follow your child's progress. Free if their school has EduAI, or "
              'subscribe yourself.',
    ),
    AppRole.schoolAdmin: (
      icon: Icons.business_outlined,
      title: 'I run a school',
      body: 'Enrol students and buy seats. 30-day trial, then pay by MoMo.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What will you use EduAI for?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: t.ink2,
          ),
        ),
        const SizedBox(height: 10),
        for (final role in _offered)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RoleCard(
              role: role,
              icon: _copy[role]!.icon,
              title: _copy[role]!.title,
              body: _copy[role]!.body,
              selected: role == selected,
              onTap: enabled ? () => onChanged(role) : null,
            ),
          ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final AppRole role;
  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.read(context);
    return Semantics(
      selected: selected,
      button: true,
      child: AppCard(
        key: Key('signup-role-${role.wireName}'),
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        borderColor: selected ? t.brand : t.border,
        child: Row(
          children: [
            IconTile(icon: icon, filled: selected, size: 34, iconSize: 16),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(body, style: TextStyle(fontSize: 12, color: t.ink3)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? t.brand : t.ink3,
            ),
          ],
        ),
      ),
    );
  }
}
