import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'onboarding_state.dart';

/// Thrown by [AuthRepository.setUsername] when the chosen username is
/// already taken by another profile.
class UsernameTakenException implements Exception {}

/// Thrown by [AuthRepository.setUsername] when the chosen username is on
/// the reserved list (see [AuthRepository.reservedUsernames]) -- kept
/// distinct from [UsernameTakenException] internally, but
/// UsernameStep folds both into the same "ชื่อผู้ใช้นี้ถูกใช้แล้ว"-shaped UI
/// state per the design spec (no separate "reserved" status is called
/// for).
class UsernameReservedException implements Exception {}

/// Thrown by [AuthRepository.signUpWithEmail] when the email is already
/// registered -- surfaced separately from a generic sign-up failure so
/// EmailAuthScreen can show "already registered, try logging in instead"
/// rather than a generic error.
class EmailAlreadyRegisteredException implements Exception {}

/// Wraps all Supabase Auth + profile calls needed for WYN-002
/// (Authentication & Onboarding). See:
/// .wyn/tasks/active/WYN-002-authentication-onboarding.md
/// .wyn/docs/design/wyn-002-authentication-onboarding.md
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// platforms (iOS/Android) -- must be registered in the Supabase
  /// project's Auth settings and in the native app's URL scheme
  /// configuration. **Native only**: passing this custom `io.wyn.app://`
  /// scheme as `redirectTo` on Flutter Web breaks Google/Apple sign-in
  /// entirely -- Safari/Chrome refuse to navigate to a non-http(s) scheme
  /// with no registered handler ("Safari ไม่สามารถเปิดหน้าเว็บได้เนื่องจาก
  /// ที่อยู่ของหน้าเว็บไม่ถูกต้อง"), so the OAuth flow never even reaches
  /// Google's consent screen. On web, omit `redirectTo` entirely so
  /// supabase_flutter falls back to the current page's own origin (already
  /// in the Supabase project's redirect allow-list) as the callback --
  /// see .wyn/company/DECISIONS.md, 2026-08-24 ("Google Sign-In พังบน Web
  /// production").
  static const _mobileOauthRedirect = 'io.wyn.app://login-callback';

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  /// `prompt: select_account` forces Google's own account-chooser screen
  /// every time, regardless of whether the browser/webview already has an
  /// active Google session cookie -- without it, Google silently signs
  /// straight into whichever account is already logged in there, with no
  /// way to pick a different one. Critical specifically for multi-account
  /// switching's "เพิ่มบัญชี" (Add Account) flow, whose entire point is
  /// letting the user choose a *different* Google account than the one
  /// they're currently using in WYNOS -- confirmed broken without this
  /// (Founder, 2026-09-03: "กดเข้าตรงนี้มันจะเด้งไปบัญชีเดิมที่เคยล็อกอินตลอด").
  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : _mobileOauthRedirect,
      queryParams: const {'prompt': 'select_account'},
    );
  }

  Future<void> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: kIsWeb ? null : _mobileOauthRedirect,
    );
  }

  /// Creates a new account with any email + password -- unlike Google/
  /// Apple/Phone OTP, not tied to a specific provider account, so a
  /// tester can sign up with any address and as many accounts as they
  /// want. The Supabase project has email confirmation switched off
  /// (Founder, 2026-08-24, for frictionless beta testing -- see
  /// .wyn/company/DECISIONS.md), so this returns a real session
  /// immediately rather than requiring a confirmation-link click first.
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    try {
      return await _client.auth.signUp(email: email, password: password);
    } on AuthApiException catch (e) {
      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('already exists')) {
        throw EmailAlreadyRegisteredException();
      }
      rethrow;
    }
  }

  Future<AuthResponse> signInWithEmail(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendPhoneOtp(String phone) {
    return _client.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String otp,
  }) {
    return _client.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: otp,
    );
  }

  /// Signs in without any identity provider (no Google/Apple/Phone OTP
  /// setup needed) via Supabase's built-in anonymous auth -- a real,
  /// valid session (`auth.uid()` works, RLS policies apply normally,
  /// the onboarding flow is unaffected) just not tied to any verified
  /// identity yet. Requires "Allow anonymous sign-ins" enabled
  /// in the Supabase project's Authentication settings (a free toggle,
  /// no third-party account) -- see .wyn/company/DECISIONS.md, 2026-08-16
  /// ("ข้ามหน้าล็อกอินชั่วคราวสำหรับ Internal Testing"). Temporary/testing
  /// path only -- an anonymous user can later call `linkIdentity` to
  /// upgrade to Google/Apple/Phone without losing their profile/data, but
  /// that upgrade path isn't wired into the UI yet.
  Future<AuthResponse> signInAnonymously() {
    return _client.auth.signInAnonymously();
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  /// Names no account may take -- checked client-side here as the first
  /// line of defense (fast, no round trip) and mirrored verbatim as a
  /// `check` constraint on `profiles.username` in supabase/schema.sql
  /// (`profiles_username_not_reserved`) as the real enforcement, since a
  /// client-side-only check can always be bypassed by calling the REST
  /// API directly. Keep both lists in sync.
  static const reservedUsernames = {
    'admin', 'administrator', 'support', 'help', 'wynos', 'wyn',
    'official', 'root', 'api', 'moderator', 'staff', 'security', 'system',
    'null', 'undefined', 'everyone', 'here', 'channel', 'settings',
    'about', 'terms', 'privacy', 'www', 'app',
  };

  Future<bool> isUsernameAvailable(String username) async {
    if (reservedUsernames.contains(username.toLowerCase())) return false;
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return row == null;
  }

  /// Creates or updates the caller's `profiles` row with [username] --
  /// upsert rather than update, since a brand-new Google sign-in has no
  /// `profiles` row yet at all until this (or [setDateOfBirth], which now
  /// runs first) creates one.
  Future<void> setUsername(String userId, String username) async {
    if (reservedUsernames.contains(username.toLowerCase())) {
      throw UsernameReservedException();
    }
    final available = await isUsernameAvailable(username);
    if (!available) throw UsernameTakenException();

    try {
      await _client.from('profiles').upsert({
        'id': userId,
        'username': username,
      });
    } on PostgrestException catch (e) {
      // 23505 = unique_violation. A concurrent request can still take this
      // username between the availability check above and this write;
      // surface that the same way as the pre-check instead of letting a
      // raw database error reach the UI.
      if (e.code == '23505') {
        throw UsernameTakenException();
      }
      rethrow;
    }
  }

  /// One read covering every step's completion state -- see
  /// [OnboardingState.resumeStep] for how AuthGate/OnboardingFlow turn
  /// this into "which screen to show next". [user] (not just its id) is
  /// needed because [OnboardingState.hasPassword] also considers whether
  /// the account's primary sign-up method was already email+password
  /// (`app_metadata.provider`), in which case the onboarding Password
  /// step is skipped entirely rather than asking twice.
  Future<OnboardingState> fetchOnboardingState(User user) async {
    final row = await _client
        .from('profiles')
        .select(
            'username, display_name, avatar_url, is_verified, profile_private(date_of_birth, password_set, onboarding_completed)')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return OnboardingState.notStarted();

    final private = row['profile_private'] as Map<String, dynamic>?;
    final signedUpWithEmailPassword = user.appMetadata['provider'] == 'email';

    return OnboardingState(
      hasDateOfBirth: private?['date_of_birth'] != null,
      username: row['username'] as String?,
      displayName: row['display_name'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      isVerified: row['is_verified'] as bool? ?? false,
      hasPassword:
          signedUpWithEmailPassword || (private?['password_set'] as bool? ?? false),
      completed: private?['onboarding_completed'] as bool? ?? false,
    );
  }

  /// Birthday step. Upserts the `profiles` row too (not just
  /// `profile_private`, whose `id` is a foreign key into it) -- Birthday
  /// is now the *first* onboarding step, so for a brand-new Google
  /// sign-in neither row exists yet at all.
  Future<void> setDateOfBirth(String userId, DateTime dateOfBirth) async {
    await _client.from('profiles').upsert({'id': userId});
    // Sent as a plain `YYYY-MM-DD` date (no time-of-day/timezone) --
    // `profile_private.date_of_birth` is a `date` column, and birthdays
    // aren't timestamps.
    final iso = dateOfBirth.toIso8601String().split('T').first;
    await _client.from('profile_private').upsert({
      'id': userId,
      'date_of_birth': iso,
    });
  }

  /// Display Name step. `profiles` row is guaranteed to exist by now
  /// (Birthday/Username steps both upsert it), so a plain update suffices.
  Future<void> setDisplayName(String userId, String displayName) {
    return _client
        .from('profiles')
        .update({'display_name': displayName}).eq('id', userId);
  }

  /// Password step -- sets a WYNOS password credential on the caller's
  /// *existing* Supabase Auth user (the one already created by Google
  /// Sign-In). Google stays the identity provider; this does not create a
  /// second account, and Supabase's own Auth handles the hashing/storage
  /// (see this method's callers -- never anything custom). Rethrows
  /// Supabase's own `AuthWeakPasswordException`/`AuthApiException`
  /// unchanged so PasswordStep can show a specific message for each.
  Future<void> setPassword(String userId, String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
    await _client
        .from('profile_private')
        .update({'password_set': true}).eq('id', userId);
  }

  /// Profile Optional step -- both [avatarUrl] and [bio] are genuinely
  /// optional (per the design spec's "ห้ามบังคับกรอก Bio"); pass null to
  /// leave a field untouched (e.g. the user skipped the whole step).
  Future<void> saveOptionalProfile(
    String userId, {
    String? avatarUrl,
    String? bio,
  }) {
    final updates = <String, dynamic>{};
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (bio != null) updates['bio'] = bio;
    if (updates.isEmpty) return Future.value();
    return _client.from('profiles').update(updates).eq('id', userId);
  }

  /// Finish step -- the one write that actually flips
  /// `onboarding_completed`, which is what AuthGate checks to decide
  /// Onboarding vs Home. Deliberately separate from
  /// [saveOptionalProfile] (a prior step) so a user who closes the app
  /// between "Profile Optional" and tapping "Enter WYNOS" on Finish is
  /// not silently marked done -- they resume and see Finish again.
  Future<void> completeOnboarding(String userId) {
    return _client.from('profile_private').update({
      'onboarding_completed': true,
      'onboarding_completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }
}
