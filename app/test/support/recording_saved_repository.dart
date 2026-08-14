import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/saved/data/saved_repository.dart';

/// A SavedRepository whose fetchFeed is overridden to return canned data
/// instead of making a real Supabase call. Mirrors RecordingHomeRepository
/// -- see .wyn/learning/PATTERNS.md.
class RecordingSavedRepository extends SavedRepository {
  RecordingSavedRepository({List<HomeFeedItem>? feedItems})
      : feedItems = feedItems ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchFeed] for page 0 only (page 1+ returns empty).
  final List<HomeFeedItem> feedItems;

  @override
  Future<List<HomeFeedItem>> fetchFeed({required int page}) async {
    return page == 0 ? feedItems : <HomeFeedItem>[];
  }
}
