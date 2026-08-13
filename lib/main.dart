import 'package:device_preview_plus/device_preview_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/config/config_providers.dart';

/// Device preview is a debug-only tool. On by default in debug builds; turn it
/// off with `--dart-define=DEVICE_PREVIEW=false` when its toolbar and device
/// frame get in the way. Always off in release.
const _devicePreviewEnabled =
    bool.fromEnvironment('DEVICE_PREVIEW', defaultValue: true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Supabase / Firebase before the first frame. Failures here are
  // non-fatal — the app still boots with offline capability.
  final boot = await AppBootstrap.run();

  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(boot.config),
        supabaseClientProvider.overrideWithValue(boot.supabaseClient),
        firebaseReadyProvider.overrideWithValue(boot.firebaseReady),
      ],
      // DevicePreview sits *inside* ProviderScope so that switching device or
      // orientation rebuilds only the app, never the provider graph — app
      // state (session, tutor thread) survives a device change.
      child: DevicePreview(
        enabled: kDebugMode && _devicePreviewEnabled,
        builder: (_) => const EduAiApp(),
      ),
    ),
  );
}
