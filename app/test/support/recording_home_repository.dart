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
  RecordingHomeRepository({List<HomeFeedItem>? feedItems, List<HomeFeedItem>? trendingItems})
      : feedItems = feedItems ?? [],
        trendingItems = trendingItems ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchFeed] for page 0 only (page 1+ returns empty).
  final List<HomeFeedItem> feedItems;

  /// Returned by [fetchTrending] (WYN-017).
  final List<HomeFeedItem> trendingItems;

  @override
  Future<List<HomeFeedItem>> fetchFeed({required int page}) async {
    return page == 0 ? feedItems : <HomeFeedItem>[];
  }

  @override
  Future<List<HomeFeedItem>> fetchTrending() async => trendingItems;
}
