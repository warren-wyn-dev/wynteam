import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/data/home_repository.dart';

/// A HomeRepository whose fetchFeed is overridden to return canned data
/// instead of making a real Supabase call. Mirrors RecordingDropRepository/
/// RecordingPopRepository -- see .wyn/learning/PATTERNS.md. Unlike those,
/// HomeRepository has no interactive methods to record calls for -- Like/
/// Save/Delete on a Home card are delegated straight to DropRepository/
/// PopRepository, whichever matches the card's content type.
class RecordingHomeRepository extends HomeRepository {
  RecordingHomeRepository({
    List<HomeFeedItem>? feedItems,
    List<HomeFeedItem>? trendingItems,
    List<HomeFeedItem>? rankedFeedItems,
    List<HomeFeedItem>? followingFeedItems,
    List<HomeFeedItem>? redropsByUser,
  })  : feedItems = feedItems ?? [],
        trendingItems = trendingItems ?? [],
        // Defaults to the same list as feedItems -- most existing
        // call sites (predating WYN-018) only care that "the feed
        // shows these items" regardless of forYou/latest mode. Pass
        // rankedFeedItems/followingFeedItems explicitly to test a mode
        // returning genuinely different data from the others.
        rankedFeedItems = rankedFeedItems ?? feedItems ?? [],
        followingFeedItems = followingFeedItems ?? feedItems ?? [],
        redropsByUser = redropsByUser ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchFeed] for page 0 only (page 1+ returns empty).
  final List<HomeFeedItem> feedItems;

  /// Returned by [fetchTrending] (WYN-017).
  final List<HomeFeedItem> trendingItems;

  /// Returned by [fetchRankedFeed] for page 0 only (page 1+ returns
  /// empty) -- WYN-018. Defaults to the same list as [feedItems] unless
  /// given explicitly (see constructor doc comment).
  final List<HomeFeedItem> rankedFeedItems;

  /// Returned by [fetchFollowingFeed] for page 0 only (page 1+ returns
  /// empty) -- WYN-024. Defaults to the same list as [feedItems] unless
  /// given explicitly (see constructor doc comment).
  final List<HomeFeedItem> followingFeedItems;

  /// Returned by [fetchRedropsByUser] for page 0 only (page 1+ returns
  /// empty) -- WYN-034.
  final List<HomeFeedItem> redropsByUser;

  int fetchRankedFeedCalls = 0;
  int fetchFollowingFeedCalls = 0;
  int fetchRedropsByUserCalls = 0;
  final List<String> fetchRedropsByUserUserIdArgs = [];

  @override
  Future<List<HomeFeedItem>> fetchFeed({required int page}) async {
    return page == 0 ? feedItems : <HomeFeedItem>[];
  }

  @override
  Future<List<HomeFeedItem>> fetchTrending() async => trendingItems;

  @override
  Future<List<HomeFeedItem>> fetchRankedFeed({required int page}) async {
    fetchRankedFeedCalls++;
    return page == 0 ? rankedFeedItems : <HomeFeedItem>[];
  }

  @override
  Future<List<HomeFeedItem>> fetchFollowingFeed({required int page}) async {
    fetchFollowingFeedCalls++;
    return page == 0 ? followingFeedItems : <HomeFeedItem>[];
  }

  @override
  Future<List<HomeFeedItem>> fetchRedropsByUser({
    required String userId,
    required int page,
  }) async {
    fetchRedropsByUserCalls++;
    fetchRedropsByUserUserIdArgs.add(userId);
    return page == 0 ? redropsByUser : <HomeFeedItem>[];
  }
}
