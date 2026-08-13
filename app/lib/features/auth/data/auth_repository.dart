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

    await _client.from('profiles').upsert({
      'id': userId,
      'username': username,
    });
  }
}
