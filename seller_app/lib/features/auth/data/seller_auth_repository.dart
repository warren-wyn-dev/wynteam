import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown by [SellerAuthRepository.setUsername] when the chosen username
/// is already taken by another profile.
class UsernameTakenException implements Exception {}

/// Wraps all Supabase Auth + profile calls needed for SellerAuthGate.
/// Mirrors `app/lib/features/auth/data/auth_repository.dart` (WYN
/// Social's `AuthRepository`) method-for-method -- Seller sign-in reuses
/// the *same* Supabase Auth (Google/Apple OAuth + Phone OTP) and the
/// same `profiles` table, since a seller is just a WYN user who
/// registered a store (see .wyn/tasks/backlog/SELLER-001-foundation.md).
/// Duplicated instead of shared because this is a separate Flutter
/// binary -- see .wyn/company/DECISIONS.md, 2026-08-15.
class SellerAuthRepository {
  SellerAuthRepository(this._client);

  final SupabaseClient _client;

  /// The OAuth redirect used by both Google and Apple sign-in. Must be
  /// registered in the Supabase project's Auth settings and in the
  /// native app's URL scheme configuration once that's set up -- see
  /// README.md, Known Issues (same gap `app/`'s `io.wyn.app://` redirect
  /// currently has).
  static const _oauthRedirect = 'io.wyn.zokyseller://login-callback';

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

  /// Temporary Internal Testing bypass -- see
  /// `app/lib/features/auth/data/auth_repository.dart`'s identical method
  /// for the full rationale and .wyn/company/DECISIONS.md, 2026-08-16.
  Future<AuthResponse> signInAnonymously() {
    return _client.auth.signInAnonymously();
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  /// A signed-in user still needs onboarding until their `profiles` row
  /// has a non-null `username` -- true for both apps since they share
  /// the same `profiles` table. A seller who opens this app before ever
  /// using WYN Social hits this exact same path. See supabase/schema.sql.
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
      // 23505 = unique_violation. A concurrent request can still take
      // this username between the availability check above and this
      // write; surface that the same way as the pre-check instead of
      // letting a raw database error reach the UI.
      if (e.code == '23505') {
        throw UsernameTakenException();
      }
      rethrow;
    }
  }
}
