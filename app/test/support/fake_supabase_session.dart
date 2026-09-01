import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes Supabase against a fake project and hydrates a locally-valid
/// (never sent to a real server) signed-in session, so widgets that read
/// `Supabase.instance.client.auth.currentUser` (e.g. FeedScreen) can be
/// pumped in a widget test. `recoverSession` only makes a network call for
/// an *expired* session, so a session dated a year out never touches the
/// network -- see gotrue's `GoTrueClient.recoverSession`.
Future<void> initFakeSupabaseSession({
  String userId = 'u1',
  bool isAnonymous = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  await Supabase.initialize(
    url: 'https://example.supabase.co',
    publishableKey: 'test-key',
  );

  final expiresAt =
      DateTime.now().add(const Duration(days: 365)).millisecondsSinceEpoch ~/
          1000;

  final sessionJson = {
    'access_token': 'fake-access-token',
    'token_type': 'bearer',
    'expires_in': 31536000,
    'expires_at': expiresAt,
    'refresh_token': 'fake-refresh-token',
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': DateTime.now().toIso8601String(),
      'is_anonymous': isAnonymous,
    },
  };

  await Supabase.instance.client.auth.recoverSession(
    const JsonEncoder().convert(sessionJson),
  );
}
