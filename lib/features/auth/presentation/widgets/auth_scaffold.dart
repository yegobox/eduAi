import 'package:flutter/material.dart';

/// Responsive shell for every auth screen: a branded panel beside a centred
/// content card on wide (desktop) windows; a single scrollable column on
/// narrow ones.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _wideBreakpoint;
          final form = _FormColumn(
            title: title,
            subtitle: subtitle,
            footer: footer,
            child: child,
          );
          if (!isWide) {
            return SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: form,
                  ),
                ),
              ),
            );
          }
          return Row(
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(
                flex: 6,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(48),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: form,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.textTheme.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(subtitle, style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 32),
        child,
        if (footer != null) ...[
          const SizedBox(height: 24),
          footer!,
        ],
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_rounded, size: 64, color: scheme.onPrimary),
            const SizedBox(height: 24),
            Text(
              'EduAI',
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'The foundation for learning with AI —\nonline, offline, everywhere.',
              style: TextStyle(
                color: scheme.onPrimary.withValues(alpha: 0.85),
                fontSize: 18,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
