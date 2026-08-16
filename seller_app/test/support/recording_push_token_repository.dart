import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zoky_seller/features/push/data/push_token_repository.dart';

/// A PushTokenRepository whose network-touching methods are overridden to
/// just record what they were called with, instead of making a real
/// Supabase call. Mirrors `app/`'s identical fake -- see
/// .wyn/learning/PATTERNS.md.
class RecordingPushTokenRepository extends PushTokenRepository {
  RecordingPushTokenRepository()
      : super(SupabaseClient('https://example.supabase.co', 'test-key'));

  String? lastUpsertedToken;
  PushPlatform? lastUpsertedPlatform;
  int upsertCalls = 0;

  String? lastDeletedToken;
  int deleteCalls = 0;

  @override
  Future<void> upsertToken({
    required String token,
    required PushPlatform platform,
  }) async {
    lastUpsertedToken = token;
    lastUpsertedPlatform = platform;
    upsertCalls++;
  }

  @override
  Future<void> deleteToken(String token) async {
    lastDeletedToken = token;
    deleteCalls++;
  }
}
