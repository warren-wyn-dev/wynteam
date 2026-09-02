import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/data/home_feed_item.dart';

/// Reads the `saved_feed` view (see supabase/schema.sql, WYN-013 section)
/// for the Saved tab on the current user's own profile. RLS on `saves`
/// already restricts this to the caller's own saved content -- there's
/// no userId parameter here because "someone else's Saved tab" isn't a
/// concept the backend allows at all, not just something the UI hides.
/// Reuses HomeFeedItem (WYN-007) rather than a new model since the shape
/// -- a content-type discriminator plus both Drop/Pop fields -- is
/// identical.
class SavedRepository {
  SavedRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 21;

  // WYN-102 (Wynos V1.0.0 Beta2, item 11, 2026-09-02): same "hide, don't
  // delete" filter HomeRepository applies to every home_feed query --
  // see that class's own _hiddenContentType doc comment. A previously-
  // saved Pop is exactly the kind of easy-to-miss access point that
  // task's own Risk section warned about (not the obvious nav/tab
  // spots), so this view gets the same treatment.
  static const _hiddenContentType = 'pop';

  Future<List<HomeFeedItem>> fetchFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('saved_feed')
        .select()
        .neq('content_type', _hiddenContentType)
        .order('saved_at', ascending: false)
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

    return rows.map((row) {
      final id = row['id'] as String;
      final isDrop = row['content_type'] == 'drop';
      final likedByMe =
          isDrop ? likedDropIds.contains(id) : likedPopIds.contains(id);
      // Every row here is, by construction, something the current user
      // saved -- savedByMe is always true, unlike Home's per-row lookup.
      return HomeFeedItem.fromMap(row, likedByMe: likedByMe, savedByMe: true);
    }).toList();
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
}
