import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import 'profile.dart';

/// Thrown by [ProfileRepository.updateUsername] when the chosen username
/// is already taken by a different profile -- WYNOS V1.0.0 Beta
/// requirement 5 (editable @username). Same role as AuthRepository's
/// UsernameTakenException (WYN-002's onboarding username check); kept as
/// a separate type since ProfileRepository and AuthRepository are
/// deliberately independent (different features), not because the two
/// situations differ.
class UsernameTakenException implements Exception {}

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
        // platform_role (WYN-029) included here specifically -- Settings'
        // "เครื่องมือผู้ดูแล" entry point (Screen 1) reads it straight off
        // the profile ViewProfileScreen already fetches for itself, no
        // extra query. is_private (WYN-039) drives both Settings'
        // Privacy toggle and ViewProfileScreen's Locked persona the same
        // way. dm_permission/mention_permission/comment_permission
        // (WYN-045) feed SettingsScreen's 3 new permission rows the same
        // "already-fetched, not re-queried" way.
        .select(
            'id, username, display_name, bio, avatar_url, platform_role, is_private, dm_permission, mention_permission, comment_permission, likes_visibility')
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

  /// Whether [username] is free to take -- WYNOS V1.0.0 Beta requirement
  /// 5. [currentUserId]'s own existing username still counts as
  /// "available" (typing back what you already have, or not changing it
  /// at all, must never show "taken"), unlike UsernameSetupScreen's
  /// onboarding check (WYN-002), which never has to consider that case
  /// since a brand-new user has no username yet.
  Future<bool> isUsernameAvailable(
    String username, {
    required String currentUserId,
  }) async {
    final row = await _client
        .from('profiles')
        .select('id')
        .eq('username', username)
        .maybeSingle();
    return row == null || row['id'] == currentUserId;
  }

  /// Changes [userId]'s `@username` -- WYNOS V1.0.0 Beta requirement 5.
  /// Every read path (feeds, profiles, search, mentions, ...) selects
  /// `username` straight off `profiles` on each fetch, so there's no
  /// denormalized copy anywhere else in the schema to keep in sync; the
  /// next time any screen re-fetches this user's profile, the new
  /// username is just there.
  Future<void> updateUsername({
    required String userId,
    required String username,
  }) async {
    final available =
        await isUsernameAvailable(username, currentUserId: userId);
    if (!available) throw UsernameTakenException();

    try {
      await _client
          .from('profiles')
          .update({'username': username}).eq('id', userId);
    } on PostgrestException catch (e) {
      // 23505 = unique_violation -- a concurrent request can still take
      // this username between the availability check above and this
      // write; surface that the same way as the pre-check instead of
      // letting a raw database error reach the UI. Mirrors
      // AuthRepository.setUsername's identical race-handling.
      if (e.code == '23505') throw UsernameTakenException();
      rethrow;
    }
  }

  /// WYN-039 Settings, Screen 1 -- flips the caller's own account between
  /// Public/Private. Switching to Public triggers
  /// profiles_auto_approve_follow_requests (schema.sql) server-side,
  /// which the client doesn't need to know about or react to beyond
  /// re-fetching Follow Requests state.
  Future<void> updateIsPrivate({
    required String userId,
    required bool isPrivate,
  }) {
    return _client
        .from('profiles')
        .update({'is_private': isPrivate}).eq('id', userId);
  }

  /// WYN-045 Settings -- who can start a new DM conversation with this
  /// user. Gated server-side by get_or_create_conversation() (see
  /// supabase/schema.sql); this just persists the choice.
  Future<void> updateDmPermission({
    required String userId,
    required InteractionPermission value,
  }) {
    return _client
        .from('profiles')
        .update({'dm_permission': value.dbValue}).eq('id', userId);
  }

  /// WYN-045 Settings -- who can @mention this user in a Drop (or Poll
  /// Drop). Gated server-side by internal.mention_allowed() (see
  /// supabase/schema.sql); this just persists the choice.
  Future<void> updateMentionPermission({
    required String userId,
    required InteractionPermission value,
  }) {
    return _client
        .from('profiles')
        .update({'mention_permission': value.dbValue}).eq('id', userId);
  }

  /// WYN-045 Settings -- who can comment on this user's Drops/Pops
  /// (Club Post comments are deliberately unaffected -- see Product
  /// spec's Requirement 4). Gated server-side by
  /// internal.comment_allowed() (see supabase/schema.sql); this just
  /// persists the choice.
  Future<void> updateCommentPermission({
    required String userId,
    required InteractionPermission value,
  }) {
    return _client
        .from('profiles')
        .update({'comment_permission': value.dbValue}).eq('id', userId);
  }

  /// WYN-099 -- whether the *current viewer* is allowed to see
  /// [targetUserId]'s "ถูกใจ" (Likes) tab, per that profile's own
  /// `likes_visibility` setting. `fetch_liked_drops`/`fetch_liked_pops`
  /// alone can't tell [ProfileLikesTab] apart's 2 empty states ("no
  /// Likes yet" vs. "not allowed to see this") since both return an
  /// empty list either way -- this is what actually distinguishes them.
  Future<bool> canViewLikes(String targetUserId) async {
    final result = await _client
        .rpc('can_view_likes', params: {'p_target': targetUserId});
    return result as bool;
  }

  /// WYN-099 Settings -- who can see this user's "ถูกใจ" (Likes) tab on
  /// their profile. Gated server-side by internal.can_view_likes() (see
  /// supabase/schema.sql); this just persists the choice.
  Future<void> updateLikesVisibility({
    required String userId,
    required LikesVisibility value,
  }) {
    return _client
        .from('profiles')
        .update({'likes_visibility': value.dbValue}).eq('id', userId);
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

  /// Fetches multiple profiles by id in a single query, returning them
  /// in the same order as [ids] (not whatever order Postgres happens to
  /// return rows in) -- WYN-040's Discovery RPCs (rising_profiles/
  /// suggested_users) return only an already-ranked list of ids, and
  /// this re-hydrates full Profile rows for that list without
  /// duplicating any ranking logic client-side. An id with no matching
  /// row (shouldn't normally happen, but defensive) is silently
  /// dropped rather than throwing.
  Future<List<Profile>> fetchProfilesByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final rows = await _client
        .from('profiles')
        .select(
            'id, username, display_name, bio, avatar_url, platform_role, is_private, is_verified')
        .inFilter('id', ids);

    final byId = {
      for (final row in rows) row['id'] as String: Profile.fromMap(row),
    };
    return ids.map((id) => byId[id]).whereType<Profile>().toList();
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
