/// Reads Supabase configuration from compile-time environment variables.
///
/// Same dart-define pattern as `app/lib/core/env.dart` (WYN Social) --
/// this app talks to the *same* Supabase project (see
/// .wyn/company/DECISIONS.md, 2026-08-15 "Phase 4 (ZOKY Sellers by WYN)"),
/// so pass the same values at build/run time, e.g.:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_PUBLISHABLE_KEY=xxxx
///
/// Never hardcode real credentials in source files.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
}
