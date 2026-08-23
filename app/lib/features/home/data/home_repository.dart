import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_feed_item.dart';
import 'home_ranking.dart';

/// WYN-035: per-viewer poll state -- see DropRepository's identically-
/// shaped private class for the full reasoning (duplicated rather than
/// shared, same as every other pair of parallel private helpers across
/// these two repositories).
class _PollState {
  const _PollState({this.myVoteIndex, this.totalVotes, this.optionCounts});

  final int? myVoteIndex;
  final int? totalVotes;
  final List<int>? optionCounts;
}

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

  // The ranked "สำหรับคุณ" feed (WYN-018) is a bounded top-N window, not
  // true infinite ranking -- see fetchRankedFeed's doc comment.
  static const _rankedCandidateLimit = 200;

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
    final redroppedIds = await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map((row) => row['poll_id'] as String?).whereType<String>().toList(),
    );

    return rows.map((row) {
      final id = row['id'] as String;
      final isDrop = row['content_type'] == 'drop';
      final likedByMe =
          isDrop ? likedDropIds.contains(id) : likedPopIds.contains(id);
      final pollState = pollStates[row['poll_id'] as String?];
      return HomeFeedItem.fromMap(
        row,
        likedByMe: likedByMe,
        savedByMe: savedIds.contains(id),
        redroppedByMe: isDrop && redroppedIds.contains(id),
        pollMyVoteIndex: pollState?.myVoteIndex,
        pollTotalVotes: pollState?.totalVotes,
        pollOptionCounts: pollState?.optionCounts,
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
    final redroppedIds = await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map((row) => row['poll_id'] as String?).whereType<String>().toList(),
    );

    final items = rows.map((row) {
      final id = row['id'] as String;
      final isDrop = row['content_type'] == 'drop';
      final likedByMe =
          isDrop ? likedDropIds.contains(id) : likedPopIds.contains(id);
      final pollState = pollStates[row['poll_id'] as String?];
      return HomeFeedItem.fromMap(
        row,
        likedByMe: likedByMe,
        savedByMe: savedIds.contains(id),
        redroppedByMe: isDrop && redroppedIds.contains(id),
        pollMyVoteIndex: pollState?.myVoteIndex,
        pollTotalVotes: pollState?.totalVotes,
        pollOptionCounts: pollState?.optionCounts,
      );
    }).toList();

    items.sort((a, b) =>
        (b.likeCount + b.commentCount).compareTo(a.likeCount + a.commentCount));
    return items.take(_trendingResultLimit).toList();
  }

  /// The ranked "สำหรับคุณ" feed (WYN-018): fetches a bounded window of
  /// the most recent [_rankedCandidateLimit] items (same "PostgREST
  /// can't order by a computed expression" constraint fetchTrending
  /// already works around), scores each with [rankingScore], sorts by
  /// that score descending, then slices out one page. This makes
  /// "สำหรับคุณ" a bounded top-200 window rather than truly infinite --
  /// [page]s beyond that return empty, same as any other exhausted feed.
  Future<List<HomeFeedItem>> fetchRankedFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;
    if (from >= _rankedCandidateLimit) return [];

    final rows = await _client
        .from('home_feed')
        .select()
        .order('created_at', ascending: false)
        .limit(_rankedCandidateLimit);

    final dropIds = <String>[];
    final popIds = <String>[];
    final authorIds = <String>{};
    for (final row in rows) {
      authorIds.add(row['author_id'] as String);
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
    final redroppedIds = await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map((row) => row['poll_id'] as String?).whereType<String>().toList(),
    );
    final followedAuthorIds = await _fetchFollowedAuthorIds(
      userId: userId,
      authorIds: authorIds,
    );

    final items = rows.map((row) {
      final id = row['id'] as String;
      final isDrop = row['content_type'] == 'drop';
      final likedByMe =
          isDrop ? likedDropIds.contains(id) : likedPopIds.contains(id);
      final pollState = pollStates[row['poll_id'] as String?];
      return HomeFeedItem.fromMap(
        row,
        likedByMe: likedByMe,
        savedByMe: savedIds.contains(id),
        redroppedByMe: isDrop && redroppedIds.contains(id),
        pollMyVoteIndex: pollState?.myVoteIndex,
        pollTotalVotes: pollState?.totalVotes,
        pollOptionCounts: pollState?.optionCounts,
      );
    }).toList();

    final now = DateTime.now().toUtc();
    items.sort((a, b) {
      final scoreA = rankingScore(
        a,
        now: now,
        isFollowingAuthor: followedAuthorIds.contains(a.authorId),
      );
      final scoreB = rankingScore(
        b,
        now: now,
        isFollowingAuthor: followedAuthorIds.contains(b.authorId),
      );
      return scoreB.compareTo(scoreA);
    });

    if (from >= items.length) return [];
    return items.sublist(from, to + 1 > items.length ? items.length : to + 1);
  }

  /// The "ติดตาม" (Following) feed mode (WYN-024): Drop+Pop content from
  /// users the current user follows, chronological. Absorbs
  /// DropRepository.fetchFollowingFeed's capability (WYN-019) into the
  /// unified Home feed now that Drop no longer has its own tab -- Home is
  /// "the" place to browse content per the WYNOS V1.0.0 spec, so this
  /// mirrors that method's own follows-then-filter approach exactly, just
  /// against `home_feed` (Drop+Pop) instead of `drops` alone.
  Future<List<HomeFeedItem>> fetchFollowingFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final followRows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId);
    final followingIds =
        followRows.map((row) => row['following_id'] as String).toList();
    if (followingIds.isEmpty) return [];

    // WYN-034: a plain `.inFilter('author_id', ...)` would only ever
    // show a ReDrop when the *original* Drop's author is also
    // followed -- missing the entire point of ReDrop (a followed user
    // sharing someone else's content into view). `.or()` matches a row
    // whose author_id OR redropper_id is a followed user; redropper_id
    // is null on every plain drop/pop row, so it never accidentally
    // widens those.
    final followingList = followingIds.join(',');
    final rows = await _client
        .from('home_feed')
        .select()
        .or('author_id.in.($followingList),redropper_id.in.($followingList)')
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
    final redroppedIds = await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows.map((row) => row['poll_id'] as String?).whereType<String>().toList(),
    );

    return rows.map((row) {
      final id = row['id'] as String;
      final isDrop = row['content_type'] == 'drop';
      final likedByMe =
          isDrop ? likedDropIds.contains(id) : likedPopIds.contains(id);
      final pollState = pollStates[row['poll_id'] as String?];
      return HomeFeedItem.fromMap(
        row,
        likedByMe: likedByMe,
        savedByMe: savedIds.contains(id),
        redroppedByMe: isDrop && redroppedIds.contains(id),
        pollMyVoteIndex: pollState?.myVoteIndex,
        pollTotalVotes: pollState?.totalVotes,
        pollOptionCounts: pollState?.optionCounts,
      );
    }).toList();
  }

  /// Fetches one page (0-indexed) of Standard + Quote ReDrops made by
  /// [userId], newest-ReDropped-first -- for Profile's "ReDrops" tab
  /// (WYN-034, Master Spec section 9). `redropper_id` is null on every
  /// plain drop/pop row in `home_feed`, so filtering on it alone
  /// already isolates ReDrop-sourced rows -- no `content_type`/
  /// `redrop_id is not null` filter needed on top.
  Future<List<HomeFeedItem>> fetchRedropsByUser({
    required String userId,
    required int page,
  }) async {
    final viewerId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('home_feed')
        .select()
        .eq('redropper_id', userId)
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    final likedIds = await _fetchLikedIds(
      table: 'drop_likes',
      idColumn: 'drop_id',
      userId: viewerId,
      ids: dropIds,
    );
    final savedIds = await _fetchSavedIds(userId: viewerId, ids: dropIds);
    final redroppedIds =
        await _fetchRedroppedIds(userId: viewerId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: viewerId,
      pollIds: rows.map((row) => row['poll_id'] as String?).whereType<String>().toList(),
    );

    return rows.map((row) {
      final id = row['id'] as String;
      final pollState = pollStates[row['poll_id'] as String?];
      return HomeFeedItem.fromMap(
        row,
        likedByMe: likedIds.contains(id),
        savedByMe: savedIds.contains(id),
        redroppedByMe: redroppedIds.contains(id),
        pollMyVoteIndex: pollState?.myVoteIndex,
        pollTotalVotes: pollState?.totalVotes,
        pollOptionCounts: pollState?.optionCounts,
      );
    }).toList();
  }

  /// Same shape as DropRepository's identically-named private method
  /// -- see its doc comment. `home_feed`'s poll_id is already a flat
  /// column (unlike DropRepository's nested drop_polls embed), so the
  /// caller here just does `row['poll_id']` directly, no extraction
  /// helper needed.
  Future<Map<String, _PollState>> _fetchPollStates({
    required String userId,
    required List<String> pollIds,
  }) async {
    if (pollIds.isEmpty) return {};

    final myVoteRows = await _client
        .from('drop_poll_votes')
        .select('poll_id, option_index')
        .eq('voter_id', userId)
        .inFilter('poll_id', pollIds);
    final myVotes = {
      for (final row in myVoteRows)
        row['poll_id'] as String: row['option_index'] as int,
    };

    final resultRows = await _client.rpc(
      'get_poll_results',
      params: {'p_poll_ids': pollIds},
    ) as List<dynamic>;
    final resultsByPollId = {
      for (final row in resultRows)
        row['poll_id'] as String: row as Map<String, dynamic>,
    };

    return {
      for (final id in pollIds)
        id: _PollState(
          myVoteIndex: myVotes[id],
          totalVotes: resultsByPollId[id]?['visible'] == true
              ? (resultsByPollId[id]!['total_votes'] as num).toInt()
              : null,
          optionCounts: resultsByPollId[id]?['visible'] == true
              ? (resultsByPollId[id]!['option_counts'] as List<dynamic>)
                  .map((e) => (e as num).toInt())
                  .toList()
              : null,
        ),
    };
  }

  Future<Set<String>> _fetchFollowedAuthorIds({
    required String userId,
    required Set<String> authorIds,
  }) async {
    if (authorIds.isEmpty) return {};

    final rows = await _client
        .from('follows')
        .select('following_id')
        .eq('follower_id', userId)
        .inFilter('following_id', authorIds.toList());

    return rows.map((row) => row['following_id'] as String).toSet();
  }

  /// Only Standard ReDrops (quote_text is null) count toward
  /// [HomeFeedItem.redroppedByMe] -- see that field's doc comment.
  Future<Set<String>> _fetchRedroppedIds({
    required String userId,
    required List<String> dropIds,
  }) async {
    if (dropIds.isEmpty) return {};

    final rows = await _client
        .from('redrops')
        .select('drop_id')
        .eq('redropper_id', userId)
        .isFilter('quote_text', null)
        .inFilter('drop_id', dropIds);

    return rows.map((row) => row['drop_id'] as String).toSet();
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
