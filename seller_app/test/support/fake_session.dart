import 'package:supabase_flutter/supabase_flutter.dart';

/// Builds a `Session` object purely by parsing a JSON map -- no network
/// call, no `Supabase.initialize()` needed (unlike
/// `fake_supabase_session.dart`'s `initFakeSupabaseSession()`, which
/// hydrates a *real* signed-in session on `Supabase.instance.client`).
/// Used to stub `RecordingSellerAuthRepository.currentSession` directly,
/// since `SellerAuthGate` reads sessions through the injected
/// repository rather than `Supabase.instance` directly.
Session fakeSession({String userId = 'u1'}) {
  return Session.fromJson({
    'access_token': 'fake-access-token',
    'token_type': 'bearer',
    'user': {'id': userId},
  })!;
}
