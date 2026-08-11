/// Centralised, environment-driven application configuration.
///
/// Values are provided at build/run time via `--dart-define` (or a
/// `--dart-define-from-file=env.json`) so that no secrets are committed to
/// source control. Sensible empty defaults keep the app booting in dev.
///
/// Example:
/// ```
/// flutter run -d windows \
///   --dart-define=SUPABASE_URL=https://xyz.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi... \
///   --dart-define=ENABLE_PHONE_AUTH=true
/// ```
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.enablePhoneAuth,
    required this.flavor,
  });

  /// Builds the config from compile-time environment values.
  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
      supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      enablePhoneAuth:
          bool.fromEnvironment('ENABLE_PHONE_AUTH', defaultValue: true),
      flavor: String.fromEnvironment('APP_FLAVOR', defaultValue: 'dev'),
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Whether the Firebase phone (SMS) auth path is offered in the UI.
  /// Firebase phone auth is only reachable on Android / iOS / Web, so on
  /// desktop this is effectively informational.
  final bool enablePhoneAuth;

  /// Deployment flavor: `dev`, `staging`, `prod`.
  final String flavor;

  /// True when the Supabase credentials are present. When false the app still
  /// boots (so the UI is inspectable) but online auth is disabled.
  bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get isProd => flavor == 'prod';
}
