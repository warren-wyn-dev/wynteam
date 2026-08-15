import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes Supabase against a fake project and hydrates a locally-valid
/// (never sent to a real server) signed-in session. Ported verbatim from
/// `app/test/support/fake_supabase_session.dart` -- see
/// .wyn/learning/PATTERNS.md, "ปลอม signed-in Supabase session แบบ
/// local-only".
Future<void> initFakeSupabaseSession({String userId = 'u1'}) async {
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
    },
  };

  await Supabase.instance.client.auth.recoverSession(
    const JsonEncoder().convert(sessionJson),
  );
}
