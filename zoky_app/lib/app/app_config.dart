/// Build-time configuration from `--dart-define` (never hardcode real keys):
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=PUBLISHABLE_OR_ANON_KEY \
///     --dart-define=ZOKY_DEMO_MODE=false
///
/// Only the publishable/anon key may ever be passed here -- never a
/// service-role key (ZOKY-100 AC 12). Authorization stays in RLS/RPC.
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.forceDemoMode,
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    forceDemoMode: bool.fromEnvironment('ZOKY_DEMO_MODE'),
  );

  /// Demo config for tests and the iPad web preview.
  static const AppConfig demo = AppConfig(
    supabaseUrl: '',
    supabaseAnonKey: '',
    forceDemoMode: true,
  );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool forceDemoMode;

  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// True when the app must use synthetic demo repositories. In this
  /// scaffold (ZOKY-104) there are no Supabase repositories yet, so the app
  /// always runs in demo mode; ZOKY-105 switches on this getter.
  bool get isDemoMode => forceDemoMode || !hasSupabaseConfig;
}
