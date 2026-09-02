import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Best-effort first-party product analytics (WYN-077). See
/// .wyn/tasks/active/WYN-077-basic-product-analytics.md and
/// .wyn/docs/design/wyn-077-basic-product-analytics.md -- Founder chose
/// this over a third-party tool (PostHog/Firebase Analytics) specifically
/// so no user data leaves this Supabase project at all
/// (.wyn/company/DECISIONS.md, 2026-09-02).
///
/// Every logging method swallows its own errors and never throws --
/// callers invoke these fire-and-forget (no `await`, no try/catch at the
/// call site needed), same shape as `PushNotificationService.initialize()`
/// being called plain in `RootShell.initState` (root_shell.dart). A
/// failed analytics write must never surface as a user-visible error or
/// delay a real product flow (signing up, posting a Drop, ...).
///
/// **No constructor parameter** -- deliberately resolves
/// `Supabase.instance.client` itself, inside `_log`'s own try block,
/// instead of taking a `SupabaseClient` from the caller. A caller doing
/// `AnalyticsRepository(Supabase.instance.client)` would evaluate
/// `Supabase.instance` (which throws synchronously if
/// `Supabase.initialize()` was never called) *before* this class's own
/// error handling ever runs -- exactly what broke
/// `create_drop_screen_test.dart`'s poll-submit and publish-from-draft
/// tests the first time this class existed, since that test file never
/// touches Supabase at all by design (it's built entirely on
/// `RecordingDropRepository`/`RecordingProfileRepository` fakes). See
/// `.wyn/tasks/bugs/WYN-077-analytics-repository-uninitialized-supabase-crash.md`.
///
/// **Known scope limit**: [logSignupStarted] is only wired up from the
/// email/password sign-up flow (`EmailAuthScreen`) -- Google/Apple OAuth
/// sign-in can't cheaply tell a brand-new account from a returning one on
/// the client side without an extra round trip, so this round leaves that
/// path uninstrumented rather than guessing. [logSignupCompleted] has no
/// such gap: it fires from `UsernameSetupScreen`, which is only ever
/// shown to an account that doesn't have a username yet -- true
/// regardless of which sign-in method created it.
class AnalyticsRepository {
  const AnalyticsRepository();

  /// A brand-new account was just created via email/password sign-up.
  /// [source] is the UTM/referral value captured from the current page's
  /// URL on web (see [currentWebSource]) -- null on native or when the
  /// user arrived with no such parameter, both of which the Admin
  /// Dashboard reports as "ไม่ระบุที่มา" (WYN-050's Growth section).
  Future<void> logSignupStarted({String? source}) =>
      _log('signup_started', source: source);

  /// Onboarding just finished (a username was successfully set) -- see
  /// this class's doc comment for why this, not the moment the account
  /// was created, is what "signup completed" means here.
  Future<void> logSignupCompleted() => _log('signup_completed');

  /// The user just did something that counts as real product usage for
  /// the first time this session (this round: publishing a Drop from
  /// CreateDropScreen). Safe to call more than once per user over time --
  /// admin_dashboard_metrics()'s activation calc only cares whether at
  /// least one row exists within 24h of signup, not which one is
  /// literally first.
  Future<void> logFirstCoreAction() => _log('first_core_action');

  /// A real (non-guest) user reached RootShell -- called once per
  /// RootShell.initState, the same "fire once per app session" proxy
  /// [PushNotificationService.initialize] already uses in that same
  /// method. Deliberately excludes Anonymous Sign-In (guest browsing,
  /// WYN-072) -- callers must check `!session.user.isAnonymous`
  /// themselves before calling this (mirrors how every other
  /// guest-vs-real-account gate in this app works, see
  /// guest_gate.dart's requireRealAccount()).
  Future<void> logSessionStart() => _log('session_start');

  Future<void> _log(String eventType, {String? source}) async {
    try {
      // Supabase.instance itself (not just the insert call below) has to
      // be inside this try -- it throws synchronously if
      // Supabase.initialize() was never called, and that must be
      // swallowed exactly like a failed network call. See this class's
      // own doc comment.
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client.from('analytics_events').insert({
        'user_id': userId,
        'event_type': eventType,
        if (source != null) 'source': source,
      });
    } catch (_) {
      // Best-effort -- see class doc comment.
    }
  }

  /// Reads `utm_source` (falling back to `ref`) from the current browser
  /// URL's query string -- e.g. `https://wynos.online/?utm_source=tiktok`.
  /// Web-only: `Uri.base` carries no meaningful query string on native, so
  /// this always returns null there. This app doesn't use URL-based
  /// routing (screens are pushed with Navigator, not named routes), so
  /// the browser address bar -- and therefore `Uri.base` -- stays exactly
  /// what it was when the page first loaded, all the way through
  /// sign-up.
  static String? currentWebSource() {
    if (!kIsWeb) return null;
    final params = Uri.base.queryParameters;
    return params['utm_source'] ?? params['ref'];
  }
}
