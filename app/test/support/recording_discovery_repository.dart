import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/data/home_repository.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/data/profile_repository.dart';
import 'package:wyn/features/search/data/discovery_repository.dart';

/// A DiscoveryRepository whose network-touching methods are overridden to
/// just return canned data instead of making a real Supabase call.
/// Mirrors RecordingHomeRepository -- see .wyn/learning/PATTERNS.md.
///
/// Every field is mutable (not `final`), mirroring
/// RecordingProfileRepository.profile/RecordingFollowRepository.
/// initiallyFollowing (WYN-039) -- construct exactly one shared instance
/// per test file (in `setUp`, not inside a `testWidgets` body) and
/// reassign these fields per test case instead. This isn't just a style
/// preference: constructing a *new* SupabaseClient from directly inside
/// a `testWidgets` body (rather than `setUp`, which runs outside
/// flutter_test's per-test timer-tracking zone) leaves its GoTrue
/// auto-refresh timer flagged as "still pending" when that specific
/// test ends, tripping flutter_test's own `!timersPending` invariant --
/// discovered the hard way while writing discovery_view_test.dart.
class RecordingDiscoveryRepository extends DiscoveryRepository {
  RecordingDiscoveryRepository()
      : trendingNowItems = [],
        topContentItems = [],
        trendingHashtags = [],
        risingProfiles = [],
        suggestedUsers = [],
        super(
          _client,
          // Every network-touching method below is overridden, so these
          // 2 sub-repositories are never actually called -- they still
          // need *some* client to construct with, so this reuses the
          // same one rather than creating 2 more.
          homeRepository: HomeRepository(_client),
          profileRepository: ProfileRepository(_client),
        );

  static final _client =
      SupabaseClient('https://example.supabase.co', 'test-key');

  /// Returned by [fetchTrendingNow].
  List<HomeFeedItem> trendingNowItems;

  /// Returned by [fetchTopContent] (WYN-042).
  List<HomeFeedItem> topContentItems;

  /// Returned by [fetchTrendingHashtags].
  List<String> trendingHashtags;

  /// Returned by [fetchRisingProfiles].
  List<Profile> risingProfiles;

  /// Returned by [fetchSuggestedUsers].
  List<Profile> suggestedUsers;

  /// When set, [fetchRisingProfiles] throws this instead of returning
  /// [risingProfiles] -- for exercising DiscoveryView's per-section
  /// fail-safe fallback (mirrors ClubSection's own fail-safe posture,
  /// WYN-017): one section's failure must never block the other 4.
  Object? risingProfilesError;

  /// When set, [fetchTopContent] throws this instead of returning
  /// [topContentItems] -- for exercising Top100Screen's error+retry
  /// state (WYN-042).
  Object? topContentError;

  @override
  Future<List<HomeFeedItem>> fetchTrendingNow({
    int limit = DiscoveryRepository.trendingNowLimit,
  }) async =>
      trendingNowItems;

  @override
  Future<List<HomeFeedItem>> fetchTopContent({
    int limit = HomeRepository.topContentResultLimit,
  }) async {
    final error = topContentError;
    if (error != null) throw error;
    return topContentItems;
  }

  @override
  Future<List<String>> fetchTrendingHashtags({
    int limit = DiscoveryRepository.trendingHashtagsLimit,
  }) async =>
      trendingHashtags;

  @override
  Future<List<Profile>> fetchRisingProfiles({
    int limit = DiscoveryRepository.risingLimit,
  }) async {
    final error = risingProfilesError;
    if (error != null) throw error;
    return risingProfiles;
  }

  @override
  Future<List<Profile>> fetchSuggestedUsers({
    int limit = DiscoveryRepository.suggestedUsersLimit,
  }) async =>
      suggestedUsers;
}
