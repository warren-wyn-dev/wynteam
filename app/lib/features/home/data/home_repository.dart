import 'package:supabase_flutter/supabase_flutter.dart';

import 'feed_diversity.dart';
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

  // Public (not `_`-prefixed) unlike the two constants below -- WYN-040's
  // DiscoveryRepository.fetchTrendingHashtags reuses this exact window/
  // candidate-count as its own "recent Drop candidates" source (see its
  // doc comment) rather than duplicating a second 48h/100 constant pair
  // that could silently drift out of sync with this one.
  static const trendingCandidateLimit = 100;
  static const _trendingResultLimit = 10;

  // The ranked "สำหรับคุณ" feed (WYN-018) is a bounded top-N window, not
  // true infinite ranking -- see fetchRankedFeed's doc comment.
  static const _rankedCandidateLimit = 200;

  // WYN-042 (WYN Top 100): a longer window/wider candidate pool than
  // Trending Now's -- a 7-day "chart" rather than a 48h "what's hot
  // right now" row, per Product's own framing of the two as distinct
  // concepts. Deliberately separate constants from _trendingWindow/
  // trendingCandidateLimit above (never touched by this task) rather
  // than parameterizing fetchTrending() itself -- see fetchTopContent's
  // doc comment.
  static const _topContentWindow = Duration(days: 7);
  static const _topContentCandidateLimit = 500;
  static const topContentResultLimit = 100;

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
    final redroppedIds =
        await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows
          .map((row) => row['poll_id'] as String?)
          .whereType<String>()
          .toList(),
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

  /// The Home "กำลังนิยม" (Trending) row -- highest [engagementScore]
  /// among items posted in the last 48 hours, across both Drop and Pop
  /// (WYN-041: like+comment+Drop-only-view, see that function's doc
  /// comment -- previously a plain `like_count + comment_count` sum).
  /// PostgREST can only `order()` by an actual column, and `home_feed`
  /// doesn't have a combined engagement column (adding one means
  /// altering the view), so this pulls a bounded set of recent
  /// candidates and ranks them client-side instead -- the same tradeoff
  /// `ClubRepository.fetchPopularClubs` already makes for the same
  /// reason ("still a small catalog", see that method's doc comment).
  ///
  /// [limit] only caps the *final ranked result*, not the candidate
  /// window itself ([trendingCandidateLimit]/[_trendingWindow] stay
  /// fixed regardless) -- added for WYN-040's Discovery page, which
  /// shows a wider "Trending Now" section (~30) than Home's own row
  /// (still defaults to 10, so every existing caller is unaffected).
  Future<List<HomeFeedItem>> fetchTrending(
      {int limit = _trendingResultLimit}) async {
    final userId = _client.auth.currentUser!.id;
    final since = DateTime.now().toUtc().subtract(_trendingWindow);

    final rows = await _client
        .from('home_feed')
        .select()
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false)
        .limit(trendingCandidateLimit);

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
    final redroppedIds =
        await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows
          .map((row) => row['poll_id'] as String?)
          .whereType<String>()
          .toList(),
    );
    final blockedAuthorIds = await _fetchPostingBlockedAuthorIds(authorIds);

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
    }).toList()
      ..removeWhere((item) => blockedAuthorIds.contains(item.authorId));

    items.sort((a, b) => engagementScore(b).compareTo(engagementScore(a)));
    return items.take(limit).toList();
  }

  /// WYN-042: the "WYN Top 100" leaderboard -- highest [engagementScore]
  /// among items posted in the last [_topContentWindow] (7 days, a
  /// weekly chart), across both Drop and Pop, excluding authors under
  /// an active moderation sanction ([_fetchPostingBlockedAuthorIds],
  /// same as [fetchTrending]). Structurally a near-duplicate of
  /// [fetchTrending] (same candidate-fetch-then-rank shape) but
  /// deliberately its own method with its own window/candidate-limit
  /// constants -- Product's WYN-042 spec explicitly calls for not
  /// touching [fetchTrending]/[_trendingWindow]/[trendingCandidateLimit]
  /// at all, since Trending Now (WYN-017/040) already passed QA on
  /// those exact values and Top 100 is framed as a distinct concept
  /// (weekly chart vs. "what's hot in the last 48h"), not a bigger
  /// version of the same thing.
  Future<List<HomeFeedItem>> fetchTopContent(
      {int limit = topContentResultLimit}) async {
    final userId = _client.auth.currentUser!.id;
    final since = DateTime.now().toUtc().subtract(_topContentWindow);

    final rows = await _client
        .from('home_feed')
        .select()
        .gte('created_at', since.toIso8601String())
        .order('created_at', ascending: false)
        .limit(_topContentCandidateLimit);

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
    final redroppedIds =
        await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows
          .map((row) => row['poll_id'] as String?)
          .whereType<String>()
          .toList(),
    );
    final blockedAuthorIds = await _fetchPostingBlockedAuthorIds(authorIds);

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
    }).toList()
      ..removeWhere((item) => blockedAuthorIds.contains(item.authorId));

    items.sort((a, b) => engagementScore(b).compareTo(engagementScore(a)));
    return items.take(limit).toList();
  }

  /// The ranked "สำหรับคุณ" feed -- WYNOS Unified Home Feed Algorithm
  /// V1.0. Calls `get_wynos_ranked_feed()` (see supabase/schema.sql),
  /// which already returns the bounded top-[_rankedCandidateLimit]
  /// (200) window scored by Wynos Score and sorted descending --
  /// backend does the heavy per-candidate computation (personalization
  /// signals, engagement/trending aggregation across the dataset) per
  /// the Product spec's explicit "Client -> Request / Backend ->
  /// Retrieve + Score / Backend -> Return Ranked Feed" flow. This
  /// replaces WYN-018's client-side rankingScore()-based sort for this
  /// one method only -- rankingScore() itself is untouched and still
  /// used by DropFeedScreen's own "For You" tab, and
  /// fetchTrending()/fetchTopContent() below are untouched too (out of
  /// scope this round, see this task's Coding notes for why).
  ///
  /// Feed Diversity re-ordering ([applyFeedDiversity]) is applied here,
  /// client-side, to the full already-scored 200-item window before
  /// slicing out a page -- see feed_diversity.dart's doc comment for
  /// why that one post-processing step stays a pure Dart function
  /// rather than more SQL. Applying it to the *full* window (not just
  /// the current page) every call, then slicing, is what keeps paging
  /// deterministic and duplicate-free: the same 200-item input always
  /// diversity-reorders into the same output, so page N always slices
  /// out the same items regardless of how many times it's re-fetched
  /// (same "bounded top-N window instead of truly infinite ranking"
  /// tradeoff WYN-018 already accepted, just with an extra reordering
  /// step now sitting in front of the slice).
  Future<List<HomeFeedItem>> fetchRankedFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;
    if (from >= _rankedCandidateLimit) return [];

    final rawRows =
        await _client.rpc('get_wynos_ranked_feed') as List<dynamic>;
    // row_data carries every public.home_feed column (plus some
    // ranking-internal ones HomeFeedItem.fromMap simply never reads) --
    // flattening it back out here is what lets fromMap keep working
    // completely unmodified, exactly as if this were still a plain
    // home_feed row. See get_wynos_ranked_feed()'s own doc comment.
    final rows = rawRows
        .map((raw) => Map<String, dynamic>.from(
            raw['row_data'] as Map<String, dynamic>))
        .toList();

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
    final redroppedIds =
        await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows
          .map((row) => row['poll_id'] as String?)
          .whereType<String>()
          .toList(),
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

    // '$id:${redropId ?? ''}' -- same composite key HomeDropCard already
    // builds for its own widget Key, needed here because the same
    // underlying Drop can appear twice in one window (once plain, once
    // via someone's ReDrop of it, WYN-034), so `id` alone isn't unique.
    String keyFor(HomeFeedItem item) => '${item.id}:${item.redropId ?? ''}';

    final diversityCandidates = [
      for (var i = 0; i < items.length; i++)
        FeedDiversityCandidate(
          key: keyFor(items[i]),
          authorId: items[i].authorId,
          wynosScore: (rawRows[i]['wynos_score'] as num).toDouble(),
          isDiscovery: rawRows[i]['is_discovery'] as bool,
        ),
    ];
    final itemsByKey = {for (final item in items) keyFor(item): item};
    final ordered = applyFeedDiversity(diversityCandidates)
        .map((c) => itemsByKey[c.key]!)
        .toList();

    if (from >= ordered.length) return [];
    return ordered.sublist(
        from, to + 1 > ordered.length ? ordered.length : to + 1);
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
    final redroppedIds =
        await _fetchRedroppedIds(userId: userId, dropIds: dropIds);
    final pollStates = await _fetchPollStates(
      userId: userId,
      pollIds: rows
          .map((row) => row['poll_id'] as String?)
          .whereType<String>()
          .toList(),
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
      pollIds: rows
          .map((row) => row['poll_id'] as String?)
          .whereType<String>()
          .toList(),
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

  /// WYN-041 (Trending Engine v2, anti-manipulation): candidate authors
  /// who currently have an active restrict/suspend/ban (per
  /// `internal.is_posting_blocked()`, WYN-029/030) get removed from
  /// ranking entirely -- not hidden from the app, just not boosted by
  /// the algorithm while sanctioned. `moderation_actions` has no SELECT
  /// policy for ordinary users, so this goes through the
  /// `authors_posting_blocked()` RPC (SECURITY DEFINER), which returns
  /// only the excluded author ids -- never the action type/reason/
  /// reviewer/expiry behind them. See
  /// .wyn/docs/design/wyn-041-trending-engine-v2.md, Decision 2/3.
  Future<Set<String>> _fetchPostingBlockedAuthorIds(
    Set<String> authorIds,
  ) async {
    if (authorIds.isEmpty) return {};

    final rows = await _client.rpc(
      'authors_posting_blocked',
      params: {'p_author_ids': authorIds.toList()},
    ) as List<dynamic>;

    return rows.map((row) => row['author_id'] as String).toSet();
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

  /// Records a "Hide" User Signal (WYNOS Unified Home Feed Algorithm
  /// V1.0) -- a hard negative signal: `get_wynos_ranked_feed()` excludes
  /// this content from this user's ranked feed entirely from the next
  /// fetch on. Only affects [contentType]/[contentId] for the *current
  /// user* -- the content itself is untouched and still visible to
  /// everyone else, same posture as a Mute (WYN-028) rather than a
  /// Report (WYN-026).
  ///
  /// WYN-079 (Wynos V1.0.0 Beta2, item 8): Founder overrode this task's
  /// original "no unhide this round" decision -- reversible now via
  /// [unhideContent], surfaced as a Snackbar "เลิกทำ" action right after
  /// hiding (see HomeFeedScreen._hideItem).
  Future<void> hideContent({
    required HomeContentType contentType,
    required String contentId,
  }) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('feed_signals').insert({
      'user_id': userId,
      'signal_type': 'hide',
      'target_type': contentType == HomeContentType.drop ? 'drop' : 'pop',
      'target_id': contentId,
    });
  }

  /// Reverses [hideContent] -- deletes this user's own "hide" signal row
  /// for [contentType]/[contentId], if one exists, so the content is no
  /// longer excluded from their ranked feed. WYN-079: backs the Snackbar
  /// "เลิกทำ" action HomeFeedScreen._hideItem shows right after hiding.
  Future<void> unhideContent({
    required HomeContentType contentType,
    required String contentId,
  }) {
    final userId = _client.auth.currentUser!.id;
    return _client
        .from('feed_signals')
        .delete()
        .eq('user_id', userId)
        .eq('signal_type', 'hide')
        .eq('target_type', contentType == HomeContentType.drop ? 'drop' : 'pop')
        .eq('target_id', contentId);
  }

  /// Records a "Profile Visit" User Signal (WYNOS Unified Home Feed
  /// Algorithm V1.0) -- a soft positive signal toward [profileId]'s
  /// author-affinity, folded into get_wynos_ranked_feed()'s Personalized
  /// Interest term the same way a Like/Save/View already is. The
  /// caller (ViewProfileScreen) is expected to skip calling this for
  /// the viewer's own profile -- there is no self-visit guard here
  /// (unlike record_drop_view()'s server-side one, WYN-038) since a
  /// self-affinity signal toward your own content is harmless noise,
  /// not a gameable public metric; skipping it client-side is enough.
  Future<void> recordProfileVisit(String profileId) {
    final userId = _client.auth.currentUser!.id;
    return _client.from('feed_signals').insert({
      'user_id': userId,
      'signal_type': 'profile_visit',
      'target_type': 'profile',
      'target_id': profileId,
    });
  }

  /// WYNOSHomeSpec.md 4.4 (New-posts pill) -- subscribes to every new
  /// Drop/Pop insert app-wide so HomeFeedScreen can surface "มีโพสต์ใหม่
  /// {N} โพสต์" instead of silently prepending on refresh (per spec's
  /// own "always surface this pill first" rule). [onInsert] is called
  /// with the new row's author_id so the caller can skip counting a
  /// post the *current* viewer themselves just made -- mirrors
  /// ChatRepository.subscribeToConversationMessages/subscribeToMy
  /// Messages's own realtime shape (see that file). No table-level
  /// filter (unlike a single-conversation chat subscription) since
  /// every authenticated viewer may see every new Drop/Pop -- the same
  /// RLS-scoped-by-default delivery subscribeToMyMessages's own doc
  /// comment already relies on for `messages`.
  ///
  /// Caller must [unsubscribe] in `dispose()` -- leaving a channel
  /// subscribed after the screen is gone leaks a socket listener.
  RealtimeChannel subscribeToNewPosts(void Function(String authorId) onInsert) {
    final channel = _client.channel('home-feed-new-posts');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'drops',
          callback: (payload) =>
              onInsert(payload.newRecord['author_id'] as String),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'pops',
          callback: (payload) =>
              onInsert(payload.newRecord['author_id'] as String),
        )
        .subscribe();
    return channel;
  }

  void unsubscribe(RealtimeChannel channel) {
    _client.removeChannel(channel);
  }
}
