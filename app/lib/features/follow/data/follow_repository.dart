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

  /// WYNOS Home reference spec 4.5 -- accounts to suggest following in
  /// the Home feed's empty state (a new account that follows no one
  /// yet). Same "fetch a bounded candidate set, filter/rank in Dart"
  /// shape as ClubRepository's own Explore Clubs discovery
  /// (_fetchDiscoverableClubs/fetchPopularClubs, WYN-015) -- this app's
  /// existing precedent for a small, unpaginated discovery list rather
  /// than a scalable ranking system, including that same precedent's
  /// per-row count RPC call (countFollowers) instead of a batched query.
  Future<List<Profile>> fetchSuggestedToFollow({int limit = 5}) async {
    final currentUserId = _client.auth.currentUser!.id;

    final followingRows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', currentUserId);
    final alreadyFollowingIds =
        followingRows.map((row) => row['following_id'] as String).toSet();

    // Bounded candidate scan (newest accounts first) -- not a real
    // ranking signal on its own, just keeps the per-row countFollowers
    // fan-out below small. Final order is by follower count, not
    // recency.
    const candidateScanLimit = 20;
    final candidateRows = await _client
        .from('profiles')
        .select()
        .neq('id', currentUserId)
        .order('created_at', ascending: false)
        .limit(candidateScanLimit);

    final candidates = candidateRows
        .map((row) => Profile.fromMap(row))
        .where((profile) => !alreadyFollowingIds.contains(profile.id))
        .toList();

    final ranked = await Future.wait(candidates.map((profile) async {
      final followerCount = await countFollowers(userId: profile.id);
      return MapEntry(profile, followerCount);
    }));
    ranked.sort((a, b) => b.value.compareTo(a.value));

    return ranked.take(limit).map((entry) => entry.key).toList();
  }
}
