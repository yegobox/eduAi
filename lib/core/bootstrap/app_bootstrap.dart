import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../logging/app_logger.dart';

/// The result of the async startup sequence, handed to `ProviderScope` as
/// overrides so the widget tree starts fully wired.
class BootstrapResult {
  const BootstrapResult({
    required this.config,
    required this.supabaseClient,
    required this.firebaseReady,
  });

  final AppConfig config;
  final SupabaseClient? supabaseClient;
  final bool firebaseReady;
}

/// Initialises external SDKs before the first frame.
///
/// Everything here is defensive: a missing Supabase key or an unconfigured
/// Firebase project must not crash the app — those paths simply become
/// unavailable while offline login continues to work.
class AppBootstrap {
  static const _log = AppLogger('Bootstrap');

  static Future<BootstrapResult> run() async {
    final config = AppConfig.fromEnvironment();

    final client = await _initSupabase(config);
    final firebaseReady = await _initFirebase(config);

    return BootstrapResult(
      config: config,
      supabaseClient: client,
      firebaseReady: firebaseReady,
    );
  }

  static Future<SupabaseClient?> _initSupabase(AppConfig config) async {
    if (!config.hasSupabase) {
      _log.warn(
        'SUPABASE_URL / SUPABASE_ANON_KEY not set — online auth disabled. '
        'Pass them with --dart-define.',
      );
      return null;
    }
    try {
      await Supabase.initialize(
        url: config.supabaseUrl,
        // Supabase renamed the anon key to "publishable key"; it's the same
        // value you copy from Project Settings → API.
        publishableKey: config.supabaseAnonKey,
        // Persist + auto-refresh sessions locally; this is what makes a
        // previously-authenticated user resolvable while briefly offline.
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _log.info('Supabase initialised.');
      return Supabase.instance.client;
    } catch (e, s) {
      _log.error('Supabase.initialize failed', e, s);
      return null;
    }
  }

  static Future<bool> _initFirebase(AppConfig config) async {
    if (!config.enablePhoneAuth) return false;
    // Firebase phone auth is only reachable on Android / iOS / Web. On desktop
    // there is no point initialising, and doing so without options throws.
    final supported = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!supported) {
      _log.info('Firebase phone auth not supported on this platform.');
      return false;
    }
    try {
      // Requires platform config (google-services.json / firebase_options.dart
      // via `flutterfire configure`). Guarded so a missing config is non-fatal.
      await Firebase.initializeApp();
      _log.info('Firebase initialised.');
      return true;
    } catch (e, s) {
      _log.warn('Firebase.initializeApp skipped/failed: $e');
      _log.debug(s);
      return false;
    }
  }
}
