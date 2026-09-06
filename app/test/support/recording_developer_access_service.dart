import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/core/developer_access/developer_access_service.dart';

/// A DeveloperAccessService whose [isDeveloperAccount] is fully
/// controlled by the test instead of making a real Supabase RPC call --
/// needed to exercise WYN-126's `_VersionLabel` (both the "developer
/// account" branch and a simulated error/fail-closed branch) without a
/// live Supabase project. Mirrors RecordingDataRightsRepository/
/// RecordingProfileRepository's "extend the real class, override the
/// network-touching method" shape -- see .wyn/learning/PATTERNS.md.
///
/// Deliberately does NOT touch [DeveloperAccessService]'s own static
/// cache (it fully overrides [isDeveloperAccount] rather than calling
/// `super.isDeveloperAccount()`), so tests don't need to worry about
/// that cache leaking a result across `testWidgets` cases the way the
/// real service's own `resetForTest()` doc comment warns about.
class RecordingDeveloperAccessService extends DeveloperAccessService {
  RecordingDeveloperAccessService({
    this.isDeveloperAccountResult = false,
    this.isDeveloperAccountError,
    this.isDeveloperAccountOverride,
  }) : super(
          // autoRefreshToken: false -- unlike RecordingDataRightsRepository
          // (built once in setUpAll), this fake is constructed fresh
          // inside individual `testWidgets` bodies, so a default
          // SupabaseClient's periodic auto-refresh Timer would still be
          // pending when flutter_test tears that test's zone down --
          // same fix RecordingAuthRepository's own doc comment explains.
          SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  /// Returned by [isDeveloperAccount] unless [isDeveloperAccountError]
  /// is set. Mutable (not final) so a single shared instance can be
  /// reused across testWidgets cases that each need a different result.
  bool isDeveloperAccountResult;

  /// When set, [isDeveloperAccount] throws this instead of returning
  /// [isDeveloperAccountResult] -- used to prove `_VersionLabel` falls
  /// back to the stable label on an error/timeout, same as the real
  /// service's own fail-closed behavior (WYN-126 Product spec
  /// Requirement 4), without needing the real RPC to actually fail.
  Object? isDeveloperAccountError;

  int isDeveloperAccountCalls = 0;

  /// When set, [isDeveloperAccount] awaits this instead of
  /// resolving/throwing immediately -- lets a test control exactly when
  /// the check completes (e.g. via a `Completer`) to observe
  /// `_VersionLabel`'s "before the future resolves" first frame, same
  /// "resolves immediately by default, unless a test needs to observe
  /// the in-flight state" shape as
  /// RecordingDataRightsRepository.exportOverride.
  Future<void> Function()? isDeveloperAccountOverride;

  @override
  Future<bool> isDeveloperAccount() async {
    isDeveloperAccountCalls++;
    if (isDeveloperAccountOverride != null) {
      await isDeveloperAccountOverride!();
    }
    final error = isDeveloperAccountError;
    if (error != null) throw error;
    return isDeveloperAccountResult;
  }
}
