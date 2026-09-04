import 'package:supabase_flutter/supabase_flutter.dart';

import '../../drop/data/square_crop.dart';
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

/// The per-viewer overlay applied to one page of `home_feed` rows --
/// see [HomeRepository._fetchViewerState].
class _ViewerFeedState {
  const _ViewerFeedState({
    required this.likedDropIds,
    required this.likedPopIds,
    required this.savedIds,
    required this.redroppedIds,
    required this.pollStates,
    required this.blockedAuthorIds,
    required this.imageUrlsByDropId,
    required this.aspectRatioByDropId,
  });

  final Set<String> likedDropIds;
  final Set<String> likedPopIds;
  final Set<String> savedIds;
  final Set<String> redroppedIds;
  final Map<String, _PollState> pollStates;

  /// Empty unless the caller asked for the sanction check -- only the
  /// ranked/leaderboard surfaces (fetchTrending/fetchTopContent) do.
  final Set<String> blockedAuthorIds;

  /// Beta3: the ordered image list of every multi-image Drop in the
  /// page, keyed by drop id -- one query for the whole page instead of
  /// one per card. Only ever holds entries for rows whose
  /// `image_count` is greater than 1; a single-image Drop already
  /// carries its only URL in `image_url`.
  final Map<String, List<String>> imageUrlsByDropId;

  /// WYN-109: the aspect ratio the poster chose for every image Drop in
  /// the page, keyed by drop id. Read from the `drops` table rather
  /// than off the row, because `home_feed` -- the view every method
  /// here selects from -- has no `image_aspect_ratio` column and
  /// cannot be given one without a `create or replace view` against a
  /// production definition that has drifted from the repo's schema.sql
  /// (SCHEMA-004). Batched into [_fetchViewerState]'s existing
  /// `Future.wait`, so it shares the round-trip the page already pays
  /// for and costs no extra latency. Missing entries (a text-only
  /// Drop, a Pop, or a failed lookup) fall back to
  /// [DropAspectRatio.initial] in [HomeFeedItem.fromMap], which is the
  /// 4:5 every card drew before this existed.
  final Map<String, DropAspectRatio> aspectRatioByDropId;
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

  // WYN-102 (Wynos V1.0.0 Beta2, item 11, 2026-09-02): Founder ordered
  // Pop hidden from the app entirely ("พักเก็บไว้" -- shelved, not
  // deleted). `home_feed` is a UNION ALL of drops+pops (see
  // supabase/schema.sql) and this task deliberately does NOT touch that
  // view (it has known pre-existing load issues, see DECISIONS.md) --
  // every query below that reads from it filters this content_type out
  // in Dart instead. Reverting Pop later is deleting this one constant's
  // usages, not a migration.
  static const _hiddenContentType = 'pop';

  /// Re-reads a single feed row -- the one identified by [id], or by
  /// [redropId] when the row is someone's ReDrop of it (the same
  /// composite identity the feed keys cards on, since one Drop can
  /// appear both plainly and via a ReDrop). Returns null when the row is
  /// gone: deleted, or now hidden from this viewer by a block/audience/
  /// moderation rule, all of which RLS applies to this query exactly as
  /// it does to a feed page.
  ///
  /// Exists so returning from Detail can refresh just the card the user
  /// was looking at. Home used to reload the entire feed from page 0 on
  /// every back-navigation, which threw away the viewer's scroll
  /// position: open the 40th post, come back, and you are at the top
  /// again with the post you just read somewhere below. No mature feed
  /// behaves that way, and the reload existed only because syncing one
  /// row back was harder than starting over -- which is what this makes
  /// easy.
  Future<HomeFeedItem?> fetchItemById({
    required String id,
    String? redropId,
  }) async {
    final userId = _client.auth.currentUser!.id;

    var query = _client.from('home_feed').select().eq('id', id);
    // A plain row and a ReDrop of the same Drop share `id`, so the
    // ReDrop column is what disambiguates them.
    query = redropId == null
        ? query.isFilter('redrop_id', null)
        : query.eq('redrop_id', redropId);
    final row = await query.maybeSingle();
    if (row == null) return null;

    final isDrop = row['content_type'] == 'drop';
    final viewer = await _fetchViewerState(
      userId: userId,
      rows: [row],
      dropIds: isDrop ? [id] : const [],
      popIds: isDrop ? const [] : [id],
    );
    final pollState = viewer.pollStates[row['poll_id'] as String?];

    return HomeFeedItem.fromMap(
      row,
      likedByMe: isDrop
          ? viewer.likedDropIds.contains(id)
          : viewer.likedPopIds.contains(id),
      savedByMe: viewer.savedIds.contains(id),
      redroppedByMe: isDrop && viewer.redroppedIds.contains(id),
      pollMyVoteIndex: pollState?.myVoteIndex,
      pollTotalVotes: pollState?.totalVotes,
      pollOptionCounts: pollState?.optionCounts,
      imageUrls: viewer.imageUrlsByDropId[id],
      aspectRatio: viewer.aspectRatioByDropId[id],
    );
  }

  /// Fetches one page (0-indexed) of the unified Home feed, newest first
  /// across Drop content (Pop is hidden -- see [_excludePop]).
  Future<List<HomeFeedItem>> fetchFeed({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('home_feed')
        .select()
        .neq('content_type', _hiddenContentType)
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

    final viewer = await _fetchViewerState(
      userId: userId,
      rows: rows,
      dropIds: dropIds,
      popIds: popIds,
    );
    final likedDropIds = viewer.likedDropIds;
    final likedPopIds = viewer.likedPopIds;
    final savedIds = viewer.savedIds;
    final redroppedIds = viewer.redroppedIds;
    final pollStates = viewer.pollStates;

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
        imageUrls: viewer.imageUrlsByDropId[id],
        aspectRatio: viewer.aspectRatioByDropId[id],
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
        .neq('content_type', _hiddenContentType)
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

    final viewer = await _fetchViewerState(
      userId: userId,
      rows: rows,
      dropIds: dropIds,
      popIds: popIds,
      authorIdsForBlockCheck: authorIds,
    );
    final likedDropIds = viewer.likedDropIds;
    final likedPopIds = viewer.likedPopIds;
    final savedIds = viewer.savedIds;
    final redroppedIds = viewer.redroppedIds;
    final pollStates = viewer.pollStates;
    final blockedAuthorIds = viewer.blockedAuthorIds;

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
        imageUrls: viewer.imageUrlsByDropId[id],
        aspectRatio: viewer.aspectRatioByDropId[id],
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
        .neq('content_type', _hiddenContentType)
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

    final viewer = await _fetchViewerState(
      userId: userId,
      rows: rows,
      dropIds: dropIds,
      popIds: popIds,
      authorIdsForBlockCheck: authorIds,
    );
    final likedDropIds = viewer.likedDropIds;
    final likedPopIds = viewer.likedPopIds;
    final savedIds = viewer.savedIds;
    final redroppedIds = viewer.redroppedIds;
    final pollStates = viewer.pollStates;
    final blockedAuthorIds = viewer.blockedAuthorIds;

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
        imageUrls: viewer.imageUrlsByDropId[id],
        aspectRatio: viewer.aspectRatioByDropId[id],
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
    final from = page * pageSize;
    final to = from + pageSize - 1;
    if (from >= _rankedCandidateLimit) return [];

    // Page 0 is the start of a fresh scroll (initial load, pull-to-
    // refresh, feed-mode switch, new-posts pill) -- rebuild the window
    // then, and slice every later page out of that same one.
    //
    // Before this, every page re-ran get_wynos_ranked_feed(), which
    // re-scores the whole 200-candidate pool server-side: scrolling 10
    // pages meant scoring 2,000 candidates to show 100 posts. Worse, it
    // quietly broke the very property the doc comment above promises --
    // "page N always slices out the same items regardless of how many
    // times it's re-fetched" only holds for one *fixed* window, and a
    // window re-fetched a minute later (new posts, changed engagement)
    // reorders, so a slice could repeat or skip items across pages.
    final window = page == 0 || _rankedWindow == null
        ? await _buildRankedWindow()
        : _rankedWindow!;

    if (from >= window.length) return [];
    return window.sublist(
        from, to + 1 > window.length ? window.length : to + 1);
  }

  /// The bounded, already-diversity-ordered window [fetchRankedFeed]
  /// pages through -- cached between pages of one scroll, rebuilt
  /// whenever page 0 is requested again. Never a stale-data risk beyond
  /// what the feed already accepted: the items in it were fetched at the
  /// same moment page 0's were.
  List<HomeFeedItem>? _rankedWindow;

  Future<List<HomeFeedItem>> _buildRankedWindow() async {
    final userId = _client.auth.currentUser!.id;

    final rawRows = await _client.rpc('get_wynos_ranked_feed') as List<dynamic>;
    // row_data carries every public.home_feed column (plus some
    // ranking-internal ones HomeFeedItem.fromMap simply never reads) --
    // flattening it back out here is what lets fromMap keep working
    // completely unmodified, exactly as if this were still a plain
    // home_feed row. See get_wynos_ranked_feed()'s own doc comment.
    // WYN-102: get_wynos_ranked_feed() is a SECURITY DEFINER RPC, not a
    // plain query builder chain -- there's no `.neq()` to attach before
    // it runs, so Pop rows are filtered out of what it returns instead
    // (same "don't touch the SQL side, filter in Dart" posture as every
    // other fetch* method in this file -- see _hiddenContentType).
    //
    // The ranking metadata (`wynos_score`/`is_discovery`) is carried
    // alongside each row through the filter by [rankedCandidateRows],
    // not looked up by position afterwards. It used to be read as
    // `rawRows[i]` while `i` indexed the *filtered* list -- so the
    // moment a single Pop row appeared anywhere in the 200 candidates,
    // every item after it was scored with some other item's numbers and
    // the whole "สำหรับคุณ" ordering (and Feed Diversity's discovery
    // quota with it) came out wrong, silently: nothing throws, and the
    // feed still renders.
    final ranked = rankedCandidateRows(
      rawRows,
      excludeContentTypes: const {_hiddenContentType},
    );
    final rows = [for (final e in ranked) e.row];

    final dropIds = <String>[];
    final popIds = <String>[];
    for (final row in rows) {
      if (row['content_type'] == 'drop') {
        dropIds.add(row['id'] as String);
      } else {
        popIds.add(row['id'] as String);
      }
    }

    final viewer = await _fetchViewerState(
      userId: userId,
      rows: rows,
      dropIds: dropIds,
      popIds: popIds,
    );
    final likedDropIds = viewer.likedDropIds;
    final likedPopIds = viewer.likedPopIds;
    final savedIds = viewer.savedIds;
    final redroppedIds = viewer.redroppedIds;
    final pollStates = viewer.pollStates;

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
        imageUrls: viewer.imageUrlsByDropId[id],
        aspectRatio: viewer.aspectRatioByDropId[id],
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
          wynosScore: ranked[i].score,
          isDiscovery: ranked[i].discovery,
        ),
    ];
    final itemsByKey = {for (final item in items) keyFor(item): item};
    final ordered = applyFeedDiversity(diversityCandidates)
        .map((c) => itemsByKey[c.key]!)
        .toList();

    _rankedWindow = ordered;
    return ordered;
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
        .neq('content_type', _hiddenContentType)
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

    final viewer = await _fetchViewerState(
      userId: userId,
      rows: rows,
      dropIds: dropIds,
      popIds: popIds,
    );
    final likedDropIds = viewer.likedDropIds;
    final likedPopIds = viewer.likedPopIds;
    final savedIds = viewer.savedIds;
    final redroppedIds = viewer.redroppedIds;
    final pollStates = viewer.pollStates;

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
        imageUrls: viewer.imageUrlsByDropId[id],
        aspectRatio: viewer.aspectRatioByDropId[id],
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
        // WYN-102: a Pop can be ReDropped too (redropper_id isn't
        // Drop-exclusive, per this method's own doc comment above) --
        // without this, a hidden Pop could still surface here via
        // someone's ReDrop of it.
        .neq('content_type', _hiddenContentType)
        .order('created_at', ascending: false)
        .range(from, to);

    final dropIds = rows.map((row) => row['id'] as String).toList();
    // popIds is empty on purpose -- the Pop rows this list could contain
    // are already filtered out by the .neq above, so there is never a
    // pop_likes lookup to make here.
    final viewer = await _fetchViewerState(
      userId: viewerId,
      rows: rows,
      dropIds: dropIds,
      popIds: const [],
    );
    final likedIds = viewer.likedDropIds;
    final savedIds = viewer.savedIds;
    final redroppedIds = viewer.redroppedIds;
    final pollStates = viewer.pollStates;

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
        imageUrls: viewer.imageUrlsByDropId[id],
        aspectRatio: viewer.aspectRatioByDropId[id],
      );
    }).toList();
  }

  /// Everything a page of `home_feed` rows needs beyond the rows
  /// themselves: which of them this viewer liked, saved, ReDropped, how
  /// they voted in any Polls, (for the ranked/leaderboard surfaces that
  /// need it) which candidate authors are under an active moderation
  /// sanction, and (Beta3) the image list of every multi-image Drop in
  /// the page.
  ///
  /// Every fetch* method above needed this same set, and each one used
  /// to `await` the five/six lookups one after another -- five sequential
  /// round-trips before a single card could render, for queries that
  /// have no dependency on each other whatsoever. They are issued
  /// together now, so a feed page costs roughly one round-trip of viewer
  /// state instead of five. Consolidating them here also removes the
  /// five copies of the identical block that had to be kept in step by
  /// hand.
  ///
  /// [authorIdsForBlockCheck] is null for the plain feeds (which don't
  /// filter by sanction) and a real set for fetchTrending/
  /// fetchTopContent; [ViewerFeedState.blockedAuthorIds] is empty when
  /// it's null, so a caller that doesn't ask never pays for the RPC.
  Future<_ViewerFeedState> _fetchViewerState({
    required String userId,
    required List<Map<String, dynamic>> rows,
    required List<String> dropIds,
    required List<String> popIds,
    Set<String>? authorIdsForBlockCheck,
  }) async {
    final pollIds = rows
        .map((row) => row['poll_id'] as String?)
        .whereType<String>()
        .toList();

    final results = await Future.wait([
      _fetchLikedIds(
        table: 'drop_likes',
        idColumn: 'drop_id',
        userId: userId,
        ids: dropIds,
      ),
      _fetchLikedIds(
        table: 'pop_likes',
        idColumn: 'pop_id',
        userId: userId,
        ids: popIds,
      ),
      _fetchSavedIds(userId: userId, ids: [...dropIds, ...popIds]),
      _fetchRedroppedIds(userId: userId, dropIds: dropIds),
      _fetchPollStates(userId: userId, pollIds: pollIds),
      _fetchImageUrls(rows),
      _fetchAspectRatios(rows),
      if (authorIdsForBlockCheck != null)
        _fetchPostingBlockedAuthorIds(authorIdsForBlockCheck),
    ]);

    return _ViewerFeedState(
      likedDropIds: results[0] as Set<String>,
      likedPopIds: results[1] as Set<String>,
      savedIds: results[2] as Set<String>,
      redroppedIds: results[3] as Set<String>,
      pollStates: results[4] as Map<String, _PollState>,
      imageUrlsByDropId: results[5] as Map<String, List<String>>,
      aspectRatioByDropId: results[6] as Map<String, DropAspectRatio>,
      blockedAuthorIds:
          results.length > 7 ? results[7] as Set<String> : const {},
    );
  }

  /// The ordered image list of every multi-image Drop in [rows], in one
  /// query.
  ///
  /// Before this, nobody fetched these with the page: the feed card
  /// rendered, saw `image_count > 1`, and only then asked the server
  /// for that one Drop's images from inside a widget's `initState` --
  /// so a page holding 8 multi-image Drops cost 8 extra round trips,
  /// fired after the page was already on screen, each one replacing a
  /// single image with a carousel under the reader's thumb as it
  /// landed. The rows are read here, together, before a single card is
  /// built.
  ///
  /// `drop_images` has a `unique (drop_id, position)` constraint, so
  /// this filter-and-order is served straight off that index. Returns
  /// an empty map (no query at all) when the page has no multi-image
  /// Drop in it, which is the common case for a feed of single-image
  /// and text-only posts. A failure here is swallowed: the images are
  /// an optimization, and every consumer still falls back to its own
  /// on-demand fetch, so a hiccup on this one query must never take
  /// the whole feed page down with it.
  Future<Map<String, List<String>>> _fetchImageUrls(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = <String>{
      for (final row in rows)
        if (row['content_type'] == 'drop' &&
            ((row['image_count'] as num?)?.toInt() ?? 0) > 1)
          row['id'] as String,
    };
    if (ids.isEmpty) return const {};

    try {
      final imageRows = await _client
          .from('drop_images')
          .select('drop_id, image_url')
          .inFilter('drop_id', ids.toList())
          .order('position');

      final byDropId = <String, List<String>>{};
      for (final row in imageRows) {
        (byDropId[row['drop_id'] as String] ??= <String>[])
            .add(row['image_url'] as String);
      }
      return byDropId;
    } catch (_) {
      return const {};
    }
  }

  /// WYN-109: the poster-chosen aspect ratio of every image Drop in
  /// [rows], in one query.
  ///
  /// The column lives on `drops`, not on the `home_feed` view this
  /// repository reads -- see [_ViewerFeedState.aspectRatioByDropId] for
  /// why it is fetched instead of selected. Only image Drops are asked
  /// for: a text-only Drop and a Pop have no image to shape, and a page
  /// made entirely of those costs no query at all.
  ///
  /// A failure is swallowed exactly as [_fetchImageUrls] swallows its
  /// own: every card falls back to the 4:5 it drew before this existed,
  /// so a hiccup here changes the shape of some photos for one page
  /// rather than taking the whole feed down. That fallback is also what
  /// runs against a database where the column has not been added yet.
  Future<Map<String, DropAspectRatio>> _fetchAspectRatios(
    List<Map<String, dynamic>> rows,
  ) async {
    final ids = <String>{
      for (final row in rows)
        if (row['content_type'] == 'drop' && row['image_url'] != null)
          row['id'] as String,
    };
    if (ids.isEmpty) return const {};

    try {
      final dropRows = await _client
          .from('drops')
          .select('id, image_aspect_ratio')
          .inFilter('id', ids.toList());

      return {
        for (final row in dropRows)
          row['id'] as String:
              DropAspectRatio.fromWire(row['image_aspect_ratio'] as String?),
      };
    } catch (_) {
      return const {};
    }
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
