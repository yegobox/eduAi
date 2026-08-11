import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/config/config_providers.dart';

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
      child: const EduAiApp(),
    ),
  );
}
