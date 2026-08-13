import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile.dart';

/// Converts an empty text field to `null`. Used for optional profile
/// fields backed by a DB constraint that requires either NULL or a
/// non-empty value (e.g. profiles_display_name_length in
/// supabase/schema.sql), where sending '' would violate the constraint.
String? normalizeOptionalText(String value) => value.isEmpty ? null : value;

/// Wraps the `profiles` table reads/writes and avatar storage needed for
/// WYN-003 (User Profile). See supabase/schema.sql for the RLS policies
/// this relies on.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id, username, display_name, bio, avatar_url')
        .eq('id', userId)
        .single();
    return Profile.fromMap(row);
  }

  Future<void> updateProfile({
    required String userId,
    required String displayName,
    required String bio,
  }) {
    return _client.from('profiles').update({
      // profiles_display_name_length requires display_name to be either
      // NULL or 1-50 characters (see supabase/schema.sql) -- an empty
      // string satisfies neither, so "no display name set" must be sent
      // as null, not ''. bio has no such minimum, so it's fine as-is.
      'display_name': normalizeOptionalText(displayName),
      'bio': bio,
    }).eq('id', userId);
  }

  /// Uploads [bytes] to the `avatars` bucket under the user's own folder
  /// (required by the storage RLS policies), then saves the resulting
  /// public URL on the profile row. Returns the new URL.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final path = '$userId/avatar.$fileExtension';

    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    // Bust CDN/client image caches so the new avatar shows immediately
    // instead of a stale copy previously cached at this same path.
    final url =
        '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';

    await _client.from('profiles').update({'avatar_url': url}).eq('id', userId);

    return url;
  }
}
