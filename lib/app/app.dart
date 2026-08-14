import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/platform/app_platform_style.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

/// Root widget. Reads the router from Riverpod so auth-driven redirects work,
/// and the platform style so the theme's radii and type scale match the OS
/// the app is actually running on.
class EduAiApp extends ConsumerWidget {
  const EduAiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final platform = ref.watch(appPlatformStyleProvider);
    return MaterialApp.router(
      title: 'EduAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(platform),
      darkTheme: AppTheme.dark(platform),
      themeMode: ThemeMode.system,
      routerConfig: router,
      // Both no-op when no DevicePreview ancestor exists (release builds and
      // widget tests), so this is safe to wire unconditionally.
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,
    );
  }
}
