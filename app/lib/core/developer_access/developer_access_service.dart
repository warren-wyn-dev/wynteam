import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generic, cross-feature "is the current user a developer/internal
/// test account" check for WYN-125's staged-rollout mechanism. See:
/// .wyn/tasks/active/WYN-125-staged-rollout-developer-first.md
/// .wyn/docs/design/wyn-125-staged-rollout-developer-accounts.md
///
/// Deliberately lives in `core/`, not inside any single feature's
/// `data/` folder (unlike WYN-122's `ChatRepository.isChatAllowed()`,
/// which only ever needed to answer for chat) -- any future feature
/// that wants a staged rollout imports this one class and decides for
/// itself which of its own code paths to gate with the boolean it
/// returns, with no new table/function needed each time. See
/// supabase/schema.sql's "WYN-125" section for the
/// `is_developer_account()` RPC and RLS this wraps.
///
/// As of this class landing, no feature calls [isDeveloperAccount] yet
/// -- this ships the mechanism only, exactly as the design spec's
/// "States" section describes (a developer account seeing `true` here
/// has no observable effect until some future feature's own code
/// branches on it).
///
/// Fail-closed on every error path (network failure, timeout, no
/// session, RPC error) -- returns `false`, exactly the same as a
/// regular, non-allowlisted user, and never throws. This mirrors
/// `ChatRepository.isChatAllowed()`'s posture of enforcing the real
/// rule server-side (RLS/RPC) and only ever using the client-side
/// result to decide what to render -- a failure here can only ever
/// make a developer account look like a regular user, never the
/// reverse.
class DeveloperAccessService {
  DeveloperAccessService([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client {
    _ensureAuthListener();
  }

  final SupabaseClient _client;

  // Cached per current auth session, not per instance -- callers across
  // different features/screens are each expected to construct their own
  // DeveloperAccessService (matching this codebase's usual repository
  // convention, e.g. ChatRepository), so the cache and its invalidation
  // listener are static: otherwise every new instance would start with
  // a cold cache and re-issue the RPC call regardless.
  static bool? _cachedIsDeveloper;
  static StreamSubscription<AuthState>? _authSubscription;

  /// Whether the currently signed-in user is a developer/internal test
  /// account. Always `false` for a null/anonymous-with-no-row auth.uid(),
  /// for a user not present in `developer_accounts`, for an empty
  /// allowlist, and for any error contacting Supabase -- see class doc
  /// comment.
  Future<bool> isDeveloperAccount() async {
    final cached = _cachedIsDeveloper;
    if (cached != null) return cached;
    try {
      final result = await _client.rpc('is_developer_account');
      // `== true` rather than an `as bool` cast: an unexpected response
      // shape must also fail closed to `false`, not throw a
      // CastError that skips the catch block below.
      final value = result == true;
      _cachedIsDeveloper = value;
      return value;
    } catch (_) {
      // Fail-closed: a transient failure is deliberately never cached
      // as `true`, and never allowed to propagate as an exception --
      // see class doc comment.
      return false;
    }
  }

  /// Subscribed once per process (not per instance, guarded by the
  /// static field itself): clears the cache on every auth state change
  /// (sign-out, a fresh anonymous session, switching accounts via WYN's
  /// account switcher) so a stale result from a previous
  /// session/account can never leak into the next one.
  void _ensureAuthListener() {
    _authSubscription ??= _client.auth.onAuthStateChange.listen((_) {
      _cachedIsDeveloper = null;
    });
  }

  /// Test-only: the cache and its auth listener are static (see field
  /// doc comments above), so they leak across tests in the same
  /// isolate unless a test resets them first.
  @visibleForTesting
  static void resetForTest() {
    _cachedIsDeveloper = null;
    unawaited(_authSubscription?.cancel());
    _authSubscription = null;
  }
}
