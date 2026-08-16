import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_feed_item.dart';

/// Reads the unified `home_feed` view (see supabase/schema.sql, WYN-007
/// section) for the Home tab. Only handles fetching -- Like/Save/Delete
/// actions on a card are delegated straight to DropRepository/
/// PopRepository (whichever matches the card's content type) rather than
/// duplicated here, since those repositories already own that logic.
class HomeRepository {
  HomeRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 10;

  // How far back "Trending" looks, and how many recent candidates are
  // pulled before ranking client-side -- see fetchTrending's doc comment.
  static const _trendingWindow = Duration(hours: 48);
  static const _trendingCandidateLimit = 100;
  static const _trendingResultLimit = 10;

  /// Fetches one page (0-indexed) of the unified Home feed, newest first
  /// across both Drop and Pop content.
  Future<List<HomeFeedItem>> fetchFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('home_feed')
        .select()
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = <String>[];
    final popIds = <String>[];
    for (final row in rows) {
      if (row['content_type'] == 'drop') {
        dropIds.add(row['id'] as String);
      } else {
        popIds.add(row['id'] as String);
      }
    }

    final likedDropIds = await _fetchLikedIds(
      table: 'drop_likes',
      idColumn: 'drop_id',
      userId: userId,
      ids: dropIds,
    );
    final likedPopIds = await _fetchLikedIds(
      table: 'pop_likes',
      idColumn: 'pop_id',
      userId: userId,
      ids: popIds,
    );
    final savedIds = await _fetchSavedIds(
      userId: userId,
      ids: [...dropIds, ...popIds],
    );

    return rows.map((row) {
      final id = row['id'] as String;
      final isDrop = row['content_type'] == 'drop';
      final likedByMe =
          isDrop ? likedDropIds.contains(id) : likedPopIds.contains(id);
      return HomeFeedItem.fromMap(
        row,
        likedByMe: likedByMe,
        savedByMe: savedIds.contains(id),
      );
    }).toList();
  }

  /// The Home "กำลังนิยม" (Trending) row -- highest `like_count +
  /// comment_count` among items posted in the last 48 hours, across both
  /// Drop and Pop. PostgREST can only `order()` by an actual column, and
  /// `home_feed` doesn't have a combined engagement column (adding one
  /// means altering the view), so this pulls a bounded set of recent
  /// candidates and ranks them client-side instead -- the same tradeoff
  /// `ClubRepository.fetchPopularClubs` already makes for the same
  /// reason ("still a small catalog", see that method's doc comment).
  Future<List<HomeFeedItem>> fetchTrending() async {
    final userId = _client.auth.currentUser!.id;
    final since = DateTime.now().toUtc().subtract(_trendingWindow);

    final rows = await _client
        .from('home_feed')
        .select()
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false)
        .limit(_trendingCandidateLimit);

    final dropIds = <String>[];
    final popIds = <String>[];
    for (final row in rows) {
      if (row['content_type'] == 'drop') {
        dropIds.add(row['id'] as String);
      } else {
        popIds.add(row['id'] as String);
      }
    }

    final likedDropIds = await _fetchLikedIds(
      table: 'drop_likes',
      idColumn: 'drop_id',
      userId: userId,
      ids: dropIds,
    );
    final likedPopIds = await _fetchLikedIds(
      table: 'pop_likes',
      idColumn: 'pop_id',
      userId: userId,
      ids: popIds,
    );
    final savedIds = await _fetchSavedIds(
      userId: userId,
      ids: [...dropIds, ...popIds],
    );

    final items = rows.map((row) {
      final id = row['id'] as String;
      final isDrop = row['content_type'] == 'drop';
      final likedByMe =
          isDrop ? likedDropIds.contains(id) : likedPopIds.contains(id);
      return HomeFeedItem.fromMap(
        row,
        likedByMe: likedByMe,
        savedByMe: savedIds.contains(id),
      );
    }).toList();

    items.sort((a, b) =>
        (b.likeCount + b.commentCount).compareTo(a.likeCount + a.commentCount));
    return items.take(_trendingResultLimit).toList();
  }

  Future<Set<String>> _fetchLikedIds({
    required String table,
    required String idColumn,
    required String userId,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return {};

    final rows = await _client
        .from(table)
        .select(idColumn)
        .eq('user_id', userId)
        .inFilter(idColumn, ids);

    return rows.map((row) => row[idColumn] as String).toSet();
  }

  /// A single query covers both content types -- `saves` stores
  /// content_type per row already, and Drop/Pop ids never collide (both
  /// are UUIDs), so filtering by `content_id in (all ids)` for this user
  /// is enough without needing to split by type like the likes queries.
  Future<Set<String>> _fetchSavedIds({
    required String userId,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return {};

    final rows = await _client
        .from('saves')
        .select('content_id')
        .eq('user_id', userId)
        .inFilter('content_id', ids);

    return rows.map((row) => row['content_id'] as String).toSet();
  }
}
