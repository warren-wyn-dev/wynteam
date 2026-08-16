import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown by [AuthRepository.setUsername] when the chosen username is
/// already taken by another profile.
class UsernameTakenException implements Exception {}

/// Wraps all Supabase Auth + profile calls needed for WYN-002
/// (Authentication & Onboarding). See:
/// .wyn/tasks/active/WYN-002-authentication-onboarding.md
/// .wyn/docs/design/wyn-002-authentication-onboarding.md
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// The OAuth redirect used by both Google and Apple sign-in. Must be
  /// registered in the Supabase project's Auth settings and in the native
  /// app's URL scheme configuration once the platform folders exist.
  static const _oauthRedirect = 'io.wyn.app://login-callback';

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<void> signInWithGoogle() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirect,
    );
  }

  Future<void> signInWithApple() {
    return _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: _oauthRedirect,
    );
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
  /// `hasUsername`/onboarding flow is unaffected) just not tied to any
  /// verified identity yet. Requires "Allow anonymous sign-ins" enabled
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

  /// A signed-in user still needs onboarding (Screen 5) until their
  /// `profiles` row has a non-null `username`. See supabase/schema.sql.
  Future<bool> hasUsername(String userId) async {
    final row = await _client
        .from('profiles')
        .select('username')
        .eq('id', userId)
        .maybeSingle();
    return row != null && row['username'] != null;
  }

  Future<bool> isUsernameAvailable(String username) async {
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return row == null;
  }

  Future<void> setUsername(String userId, String username) async {
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
}
