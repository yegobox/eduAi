import 'package:flutter/material.dart';

/// Shown while the app resolves the initial auth status. The router moves off
/// this screen as soon as [AuthController] reports a resolved status.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 72, color: scheme.primary),
            const SizedBox(height: 24),
            Text(
              'EduAI',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}
