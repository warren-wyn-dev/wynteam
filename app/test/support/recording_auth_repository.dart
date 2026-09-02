import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/auth/data/auth_repository.dart';
import 'package:wyn/features/auth/data/onboarding_state.dart';

/// An AuthRepository whose auth-state stream/session are fully
/// controlled by the test instead of a real GoTrue backend -- needed to
/// exercise AuthGate's sign-out race (WYN-029) without a live Supabase
/// project. Mirrors RecordingReportRepository/RecordingBlockRepository's
/// "extend the real repository, override the network-touching bits"
/// shape -- see .wyn/learning/PATTERNS.md.
class RecordingAuthRepository extends AuthRepository {
  RecordingAuthRepository({Session? initialSession})
      : _session = initialSession,
        // autoRefreshToken: false -- unlike every other Recording*
        // repository's SupabaseClient (which never touches auth), a
        // *default* SupabaseClient starts GoTrueClient's periodic
        // auto-refresh Timer immediately on construction. Since this
        // repository is built fresh inside individual `testWidgets`
        // bodies (not in `setUpAll`, because each test needs its own
        // independent session/stream state), that Timer would otherwise
        // still be pending when flutter_test tears the test's zone down
        // -- confirmed empirically ("A Timer is still pending" failure)
        // -- disabling it here is the fix, not moving construction
        // out of the test body.
        super(
          SupabaseClient(
            'https://example.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  final _controller = StreamController<AuthState>.broadcast();
  Session? _session;

  /// Returned by [fetchOnboardingState] unless overridden per test --
  /// defaults to "fully onboarded" (completed: true) so every existing
  /// test that only cares about reaching RootShell (not about the
  /// onboarding flow itself) keeps working unchanged. Set
  /// `onboardingStateResult = const OnboardingState(..., completed:
  /// false, ...)` (or use [OnboardingState.notStarted]) to exercise
  /// OnboardingFlow instead.
  OnboardingState onboardingStateResult = const OnboardingState(
    hasDateOfBirth: true,
    username: 'test-user',
    displayName: 'Test User',
    hasPassword: true,
    completed: true,
  );

  int signOutCalls = 0;

  @override
  Stream<AuthState> get authStateChanges => _controller.stream;

  @override
  Session? get currentSession => _session;

  /// Simulates a sign-in from outside this repository (an OTP screen, an
  /// OAuth callback) -- sets the session and emits `signedIn`, exactly
  /// like the real GoTrue client would.
  void emitSignedIn(Session session) {
    _session = session;
    _controller.add(AuthState(AuthChangeEvent.signedIn, session));
  }

  /// A *real* sign-out: clears the session and emits `signedOut` --
  /// this is what makes the sign-out race in AuthGate's own comments
  /// reproducible in a widget test: after this resolves, a naive
  /// `build()` that reads `currentSession` fresh from the stream would
  /// see `null` and render WelcomeScreen.
  @override
  Future<void> signOut() async {
    signOutCalls++;
    _session = null;
    _controller.add(const AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<OnboardingState> fetchOnboardingState(User user) async =>
      onboardingStateResult;

  // --- OnboardingFlow step methods -----------------------------------
  // Each records what it was called with (for assertions) and can be
  // made to throw via the matching *Error field, without ever touching
  // the fake SupabaseClient's placeholder URL over the network.

  final List<DateTime> setDateOfBirthCalls = [];

  @override
  Future<void> setDateOfBirth(String userId, DateTime dateOfBirth) async {
    setDateOfBirthCalls.add(dateOfBirth);
  }

  /// Returned by [isUsernameAvailable] unless overridden per test.
  bool usernameAvailableResult = true;

  @override
  Future<bool> isUsernameAvailable(String username) async =>
      usernameAvailableResult;

  final List<String> setUsernameCalls = [];
  Exception? setUsernameError;

  @override
  Future<void> setUsername(String userId, String username) async {
    if (setUsernameError != null) throw setUsernameError!;
    setUsernameCalls.add(username);
  }

  final List<String> setDisplayNameCalls = [];

  @override
  Future<void> setDisplayName(String userId, String displayName) async {
    setDisplayNameCalls.add(displayName);
  }

  final List<String> setPasswordCalls = [];
  Exception? setPasswordError;

  @override
  Future<void> setPassword(String userId, String password) async {
    if (setPasswordError != null) throw setPasswordError!;
    setPasswordCalls.add(password);
  }

  int saveOptionalProfileCalls = 0;
  String? lastSavedAvatarUrl;
  String? lastSavedBio;

  @override
  Future<void> saveOptionalProfile(
    String userId, {
    String? avatarUrl,
    String? bio,
  }) async {
    saveOptionalProfileCalls++;
    lastSavedAvatarUrl = avatarUrl;
    lastSavedBio = bio;
  }

  int completeOnboardingCalls = 0;

  @override
  Future<void> completeOnboarding(String userId) async {
    completeOnboardingCalls++;
  }

  void dispose() => _controller.close();
}
