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

  /// Returned by [isFollowing], regardless of userId. Mutable (WYN-039)
  /// so a single shared instance can be reused across testWidgets cases
  /// each needing a different canned value, same approach
  /// RecordingMuteRepository.isMutedResult already establishes.
  bool initiallyFollowing;

  /// Returned by [fetchFollowers] for page 0 only (page 1+ returns empty).
  final List<Profile> followers;

  /// Returned by [fetchFollowing] for page 0 only (page 1+ returns empty).
  final List<Profile> following;

  int followerCount;
  int followingCount;

  int toggleFollowCalls = 0;
  final List<bool> toggleFollowCurrentlyFollowingArgs = [];

  /// WYN-039 Requirement 3 ("Remove Follower").
  final List<String> removeFollowerArgs = [];
  Object? removeFollowerError;

  @override
  Future<void> removeFollower({required String followerId}) async {
    removeFollowerArgs.add(followerId);
    final error = removeFollowerError;
    if (error != null) throw error;
  }

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

  /// Returned by [fetchMutualFollows] for page 0 only -- WYN-097.
  List<Profile> mutualFollows = [];
  Object? fetchMutualFollowsError;

  @override
  Future<List<Profile>> fetchMutualFollows({required int page}) async {
    if (fetchMutualFollowsError != null) throw fetchMutualFollowsError!;
    return page == 0 ? mutualFollows : <Profile>[];
  }

  /// Returned by [fetchCloseFriends] -- WYN-097. Mutable so a test can
  /// observe [addCloseFriend]/[removeCloseFriend] actually changing it,
  /// the same optimistic-then-re-fetch shape CloseFriendsScreen itself
  /// uses.
  List<Profile> closeFriends = [];
  final List<String> addCloseFriendArgs = [];
  final List<String> removeCloseFriendArgs = [];
  Object? addCloseFriendError;
  Object? removeCloseFriendError;
  Object? fetchCloseFriendsError;

  @override
  Future<List<Profile>> fetchCloseFriends() async {
    if (fetchCloseFriendsError != null) throw fetchCloseFriendsError!;
    return closeFriends;
  }

  @override
  Future<void> addCloseFriend({required String friendId}) async {
    addCloseFriendArgs.add(friendId);
    final error = addCloseFriendError;
    if (error != null) throw error;
  }

  @override
  Future<void> removeCloseFriend({required String friendId}) async {
    removeCloseFriendArgs.add(friendId);
    final error = removeCloseFriendError;
    if (error != null) throw error;
  }
}
