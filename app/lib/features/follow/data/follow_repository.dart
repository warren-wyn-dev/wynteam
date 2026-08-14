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

  Future<int> countFollowers({required String userId}) async {
    final response = await _client
        .from('follows')
        .count(CountOption.exact)
        .eq('following_id', userId);
    return response;
  }

  Future<int> countFollowing({required String userId}) async {
    final response = await _client
        .from('follows')
        .count(CountOption.exact)
        .eq('follower_id', userId);
    return response;
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
}
