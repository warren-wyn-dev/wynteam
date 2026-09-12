import 'package:supabase_flutter/supabase_flutter.dart';

/// Which platform a registered [PushTokenRepository] token belongs to --
/// matches the `push_tokens.platform` CHECK constraint exactly (see
/// supabase/schema.sql, WYN-016 section).
enum PushPlatform { android, ios, web }

String _platformToDbValue(PushPlatform platform) => switch (platform) {
      PushPlatform.android => 'android',
      PushPlatform.ios => 'ios',
      PushPlatform.web => 'web',
    };

/// Wraps the `push_tokens` table reads/writes for WYN-016 -- a plain CRUD
/// wrapper with no Firebase SDK dependency at all, so it's fully testable
/// (and usable) before Firebase is actually configured. See
/// PushNotificationService for the piece that calls `firebase_messaging`
/// to obtain a token in the first place and hands it to this repository.
class PushTokenRepository {
  PushTokenRepository(this._client);

  final SupabaseClient _client;

  /// Registers or re-registers [token] for the current device. Upserts
  /// on the `token` unique constraint -- see that constraint's comment
  /// in supabase/schema.sql for exactly which re-registration case this
  /// covers (same user only; RLS blocks a different user's upsert from
  /// retargeting an existing row it doesn't own).
  Future<void> upsertToken({
    required String token,
    required PushPlatform platform,
  }) async {
    final userId = _client.auth.currentUser!.id;
    // `onConflict: 'token'` -- the table's primary key is the generated
    // `id`, not `token`, so without this the upsert would only ever
    // match on `id` (always a fresh uuid here) and insert a duplicate
    // row per call instead of updating the existing one for this token.
    await _client.from('push_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': _platformToDbValue(platform),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  /// One row of `push_tokens` as the owner can see it.
  ///
  /// Only ever the current user's own rows -- RLS on this table has no
  /// authenticated-wide select (see supabase/schema.sql), which is why
  /// this is safe to read from the client at all while the Edge
  /// Function needs the service-role key to read across users.
  ///
  /// [token] is carried so the caller can tell whether the device it is
  /// running on is one of these rows. Nothing displays it: see
  /// `PushDiagnostics.tokenTail`.
  Future<List<RegisteredPushDevice>> devicesForCurrentUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return const [];
    final rows = await _client
        .from('push_tokens')
        .select('token, platform, updated_at')
        .eq('user_id', userId);
    return [
      for (final row in rows as List<dynamic>)
        RegisteredPushDevice(
          token: (row as Map<String, dynamic>)['token'] as String,
          platform: row['platform'] as String,
          updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? ''),
        ),
    ];
  }

  /// Removes [token] on sign-out -- see the RLS comment in
  /// supabase/schema.sql: this is what actually lets a different WYN
  /// account register the same token cleanly afterward on a shared/
  /// reused device, since RLS itself never permits a cross-user
  /// retarget.
  Future<void> deleteToken(String token) {
    return _client.from('push_tokens').delete().eq('token', token);
  }
}


/// A device registered to receive push for the signed-in account.
class RegisteredPushDevice {
  const RegisteredPushDevice({
    required this.token,
    required this.platform,
    this.updatedAt,
  });

  final String token;
  final String platform;
  final DateTime? updatedAt;
}
