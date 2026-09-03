import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/data/profile.dart';

/// Wraps the `follows` reads/writes needed for WYN-008 (Follow system).
/// Follows a *user*, not content -- shared by both Drop and Pop, per the
/// Founder's confirmation that Follow is one system, not per-content-type.
/// See supabase/schema.sql for the RLS policies this relies on.
class FollowRepository {
  FollowRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 30;

  Future<bool> isFollowing({required String userId}) async {
    final currentUserId = _client.auth.currentUser!.id;
    final row = await _client
        .from('follows')
        .select()
        .eq('follower_id', currentUserId)
        .eq('following_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<void> toggleFollow({
    required String userId,
    required bool currentlyFollowing,
  }) async {
    final currentUserId = _client.auth.currentUser!.id;
    if (currentlyFollowing) {
      await _client
          .from('follows')
          .delete()
          .eq('follower_id', currentUserId)
          .eq('following_id', userId);
    } else {
      await _client
          .from('follows')
          .insert({'follower_id': currentUserId, 'following_id': userId});
    }
  }

  /// WYN-039: routed through the `follower_count()` RPC (not a raw
  /// `.count()` on `follows`) so the number stays accurate for everyone
  /// regardless of the target's privacy or the caller's own follow
  /// relationship to them -- see supabase/schema.sql's comment on
  /// follower_count() for why a raw count would otherwise be wrong for a
  /// stranger viewing a Private account (mirrors drop_view_count(),
  /// WYN-038).
  Future<int> countFollowers({required String userId}) async {
    final response = await _client.rpc(
      'follower_count',
      params: {'p_user_id': userId},
    );
    return (response as num).toInt();
  }

  Future<int> countFollowing({required String userId}) async {
    final response = await _client.rpc(
      'following_count',
      params: {'p_user_id': userId},
    );
    return (response as num).toInt();
  }

  /// WYN-039 Requirement 3 ("Remove Follower") -- the caller removes
  /// [followerId] from their own followers list, without blocking them.
  /// Only the person being followed may do this (RLS: `auth.uid() =
  /// following_id`, a 2nd, purely additive DELETE policy alongside
  /// WYN-008's own "unfollow yourself" policy).
  Future<void> removeFollower({required String followerId}) {
    final currentUserId = _client.auth.currentUser!.id;
    return _client
        .from('follows')
        .delete()
        .eq('follower_id', followerId)
        .eq('following_id', currentUserId);
  }

  /// Users who follow [userId], newest-followed first.
  Future<List<Profile>> fetchFollowers({
    required String userId,
    required int page,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('follows')
        .select('created_at, follower:profiles!follows_follower_id_fkey(*)')
        .eq('following_id', userId)
        .order('created_at', ascending: false)
        .range(from, to);

    return rows
        .map((row) => Profile.fromMap(row['follower'] as Map<String, dynamic>))
        .toList();
  }

  /// Users [userId] follows, newest-followed first.
  Future<List<Profile>> fetchFollowing({
    required String userId,
    required int page,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('follows')
        .select('created_at, following:profiles!follows_following_id_fkey(*)')
        .eq('follower_id', userId)
        .order('created_at', ascending: false)
        .range(from, to);

    return rows
        .map((row) => Profile.fromMap(row['following'] as Map<String, dynamic>))
        .toList();
  }

  /// WYN-097: "เพื่อน" -- the caller's own mutual-follow list (people who
  /// follow the caller back), alphabetical by username. Backs both the
  /// "เลือกเพื่อนที่จะซ่อน" (ExcludeFriendsScreen) and "เพื่อนที่สนิท"
  /// (CloseFriendsScreen) pickers -- see `public.fetch_mutual_follows()`
  /// in supabase/schema.sql, which does the actual two-way `follows`
  /// check server-side (not reproduced with two client queries here,
  /// same "let Postgres do the join" posture as every other RPC-backed
  /// read in this repository).
  static const mutualFollowsPageSize = 30;

  Future<List<Profile>> fetchMutualFollows({required int page}) async {
    final rows = await _client.rpc(
      'fetch_mutual_follows',
      params: {'p_page': page},
    ) as List<dynamic>;
    return rows
        .map((row) => Profile.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  /// WYN-097: the caller's own persistent "เพื่อนที่สนิท" (Close
  /// Friends) list -- unpaginated (same "one screen, no pagination"
  /// shape MutedListScreen/BlockedListScreen already use for a
  /// similarly-bounded personal list) since RLS already restricts this
  /// to rows the caller themselves added (`close_friends`' own SELECT
  /// policy is owner-only).
  Future<List<Profile>> fetchCloseFriends() async {
    final rows = await _client
        .from('close_friends')
        .select('friend:profiles!close_friends_friend_id_fkey(*)')
        .order('created_at', ascending: false);
    return rows
        .map((row) => Profile.fromMap(row['friend'] as Map<String, dynamic>))
        .toList();
  }

  /// Adds [friendId] to the caller's Close Friends list -- rejected
  /// server-side (RLS INSERT policy) unless [friendId] is currently a
  /// mutual follow of the caller.
  Future<void> addCloseFriend({required String friendId}) {
    final currentUserId = _client.auth.currentUser!.id;
    return _client.from('close_friends').insert(
        {'owner_id': currentUserId, 'friend_id': friendId});
  }

  Future<void> removeCloseFriend({required String friendId}) {
    final currentUserId = _client.auth.currentUser!.id;
    return _client
        .from('close_friends')
        .delete()
        .eq('owner_id', currentUserId)
        .eq('friend_id', friendId);
  }
}
