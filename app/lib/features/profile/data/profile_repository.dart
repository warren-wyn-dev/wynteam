import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import 'profile.dart';

/// Wraps the `profiles` table reads/writes and avatar storage needed for
/// WYN-003 (User Profile). See supabase/schema.sql for the RLS policies
/// this relies on.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  // 30 to match FollowRepository's list page size -- both are the same
  // "paginated list of Profile rows" shape.
  static const searchPageSize = 30;

  Future<Profile> fetchProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select('id, username, display_name, bio, avatar_url')
        .eq('id', userId)
        .single();
    return Profile.fromMap(row);
  }

  /// Resolves an `@username` mention span (WYN-021) to the user it
  /// points at, for opening their profile on tap. Returns null rather
  /// than throwing when the username doesn't exist (typo, or the
  /// account was deleted since the mention was posted) -- an
  /// unresolvable mention should fail silently, not crash the screen it
  /// was tapped from.
  Future<Profile?> fetchProfileByUsername(String username) async {
    final row = await _client
        .from('profiles')
        .select('id, username, display_name, bio, avatar_url')
        .eq('username', username)
        .maybeSingle();
    return row == null ? null : Profile.fromMap(row);
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

  /// Users whose username or display name contains [query] (case
  /// insensitive), for WYN-009 Search's User tab. A separate method from
  /// [fetchProfile] (single row by id) rather than overloading it.
  Future<List<Profile>> searchProfiles({
    required String query,
    required int page,
  }) async {
    final from = page * searchPageSize;
    final to = from + searchPageSize - 1;

    final rows = await _client
        .from('profiles')
        .select('id, username, display_name, bio, avatar_url')
        .or('username.ilike.%$query%,display_name.ilike.%$query%')
        .range(from, to);

    return rows.map((row) => Profile.fromMap(row)).toList();
  }
}
