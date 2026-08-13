/// Reads Supabase configuration from compile-time environment variables.
///
/// Pass real values at build/run time, e.g.:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=xxxx
///
/// Never hardcode real credentials in source files.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
