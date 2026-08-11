import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_config.dart';

/// Application configuration, resolved from the environment.
///
/// Overridden in `main()` after the async bootstrap so the rest of the tree
/// reads a single source of truth.
final appConfigProvider = Provider<AppConfig>((ref) {
  throw UnimplementedError(
    'appConfigProvider must be overridden in ProviderScope with '
    'AppConfig.fromEnvironment().',
  );
});

/// Whether Firebase initialised successfully (phone auth is usable).
/// Overridden in `main()` from the bootstrap result.
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// The initialised Supabase client, or `null` when Supabase credentials were
/// not supplied (the app still boots so the UI is inspectable and offline
/// login keeps working).
///
/// Overridden in `main()` with `Supabase.instance.client` once
/// `Supabase.initialize` has completed.
final supabaseClientProvider = Provider<SupabaseClient?>((ref) => null);
