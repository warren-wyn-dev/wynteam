import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/follow/data/follow_repository.dart';
import 'package:wyn/features/profile/data/profile.dart';

/// A FollowRepository whose network-touching methods are overridden to
/// just record what they were called with / return canned data, instead
/// of making a real Supabase call. Mirrors RecordingDropRepository -- see
/// .wyn/learning/PATTERNS.md.
class RecordingFollowRepository extends FollowRepository {
  RecordingFollowRepository({
    this.initiallyFollowing = false,
    List<Profile>? followers,
    List<Profile>? following,
    this.followerCount = 0,
    this.followingCount = 0,
  })  : followers = followers ?? [],
        following = following ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [isFollowing], regardless of userId.
  final bool initiallyFollowing;

  /// Returned by [fetchFollowers] for page 0 only (page 1+ returns empty).
  final List<Profile> followers;

  /// Returned by [fetchFollowing] for page 0 only (page 1+ returns empty).
  final List<Profile> following;

  final int followerCount;
  final int followingCount;

  int toggleFollowCalls = 0;
  final List<bool> toggleFollowCurrentlyFollowingArgs = [];

  @override
  Future<bool> isFollowing({required String userId}) async =>
      initiallyFollowing;

  @override
  Future<void> toggleFollow({
    required String userId,
    required bool currentlyFollowing,
  }) async {
    toggleFollowCalls++;
    toggleFollowCurrentlyFollowingArgs.add(currentlyFollowing);
  }

  @override
  Future<int> countFollowers({required String userId}) async => followerCount;

  @override
  Future<int> countFollowing({required String userId}) async => followingCount;

  @override
  Future<List<Profile>> fetchFollowers({
    required String userId,
    required int page,
  }) async {
    return page == 0 ? followers : <Profile>[];
  }

  @override
  Future<List<Profile>> fetchFollowing({
    required String userId,
    required int page,
  }) async {
    return page == 0 ? following : <Profile>[];
  }
}
