import 'cold_start.dart';
import 'feed_source.dart';
import 'home_feed_item.dart';

// WYN-041: how much weight one (deduped, rate-limited, self-view-
// excluded -- WYN-038) Drop view is worth relative to a like (2 points)
// or a comment (3 points). Product-chosen starting point, no real
// traffic data exists yet (the app isn't in production) -- adjust
// freely, but keep this comment so the next person knows *why* it's
// small: views naturally outnumber likes/comments by a wide margin on
// every platform, so an equal weight would let view count swamp the
// rest of the formula instead of complementing it.
const _viewWeight = 0.1;

/// Legacy cumulative engagement building block for [rankingScore]. Production
/// Trending and Top100 use their authoritative precomputed database contracts.
///
/// Pop is excluded from the view term entirely (early return, before any
/// arithmetic touches viewCount) -- Pop's view counter
/// (`increment_pop_view_count()`, WYN-006) is a plain unguarded `+1` per
/// call with no unique-viewer dedup/rate-limit/self-view-exclusion,
/// unlike Drop's (`drop_view_count()`, WYN-038). Folding it into a
/// formula this task explicitly calls "anti-manipulation" would hand
/// back exactly the manipulation vector it exists to close: anyone
/// could re-open their own Pop (or script several accounts to do it)
/// and inflate its Trending/สำหรับคุณ rank with zero real engagement.
/// See .wyn/tasks/backlog/WYN-041-trending-engine-v2.md, Requirement 2.
double engagementScore(HomeFeedItem item) {
  final likeCommentScore = item.likeCount * 2 + item.commentCount * 3;
  if (item.contentType != HomeContentType.drop) {
    return likeCommentScore.toDouble();
  }
  return likeCommentScore + (item.viewCount ?? 0) * _viewWeight;
}

/// Weighted score for Home's ranked "สำหรับคุณ" feed -- WYN-018. Every
/// term is plain arithmetic over data already on the item plus one
/// extra fact (does the viewer follow this author), so the result can
/// always be recomputed by hand -- deliberately not a black-box model.
/// See .wyn/docs/design/wyn-018-home-feed-ranking.md for the reasoning
/// behind each weight, and .wyn/docs/design/wyn-041-trending-engine-v2.md
/// for the view-count term added on top (WYN-041).
double rankingScore(
  HomeFeedItem item, {
  required DateTime now,
  required bool isFollowingAuthor,
}) {
  final hoursSincePosted = now.difference(item.createdAt).inMinutes / 60.0;
  final recencyScore = (168 - hoursSincePosted).clamp(0.0, 168.0);
  final followingBoost = isFollowingAuthor ? 50 : 0;

  return recencyScore + engagementScore(item) + followingBoost;
}

/// One `get_wynos_ranked_feed()` row: the `home_feed` columns plus the
/// two ranking values the RPC computed for it.
typedef RankedCandidateRow = ({
  Map<String, dynamic> row,
  double score,
  bool discovery,
  Set<FeedSource> sources,
  Map<FeedSource, double> sourceScores,
  String? topic,
  String? reasonCode,
  PersonalizationMaturity maturity,
});

/// Adapts rows from the pre-v1 `home_feed` view to the ranked-feed contract.
///
/// This is deliberately a compatibility path, not a second ranking engine. It
/// preserves the view's newest-first order and supplies only safe source
/// metadata so an app release can continue serving Home while the additive
/// Algorithm v1 migration is still rolling out or PostgREST is refreshing its
/// schema cache. Once `get_wynos_ranked_feed()` is available, production uses
/// its authoritative scores exclusively.
List<Map<String, dynamic>> legacyHomeFeedRankedRows(List<dynamic> rawRows) {
  return [
    for (var index = 0; index < rawRows.length; index++)
      {
        'row_data': <String, dynamic>{
          ...Map<String, dynamic>.from(rawRows[index] as Map),
          'feed_reason_code': 'schema_compatibility_fallback',
          'feed_maturity_state': 'zero_history',
        },
        // The query is already newest-first. A descending positional score
        // keeps that stable without recreating the backend ranking formula.
        'wynos_score': (rawRows.length - index).toDouble(),
        'is_following': false,
        'is_discovery': true,
      },
  ];
}

/// Flattens `get_wynos_ranked_feed()`'s raw rows into
/// [RankedCandidateRow]s, dropping any whose `content_type` is in
/// [excludeContentTypes] (WYN-102 hides `pop`).
///
/// Exists as a pure function -- rather than inline in
/// `HomeRepository.fetchRankedFeed` where it used to live -- because
/// keeping each row's score attached to the row *through* the filter is
/// the whole point. The previous version filtered the rows into a new
/// list, then read scores back out of the unfiltered list by position
/// (`rawRows[i]`), so one excluded row anywhere shifted every score
/// after it onto the wrong item and silently mis-ordered the entire
/// "สำหรับคุณ" feed. That is a correctness property worth a test of its
/// own, and a method that needs a live Supabase client can't have one.
List<RankedCandidateRow> rankedCandidateRows(
  List<dynamic> rawRows, {
  Set<String> excludeContentTypes = const {},
}) {
  final result = <RankedCandidateRow>[];
  for (final raw in rawRows) {
    final row = Map<String, dynamic>.from(raw['row_data'] as Map<String, dynamic>);
    if (excludeContentTypes.contains(row['content_type'])) continue;
    final sources = <FeedSource>{FeedSource.recommended};
    if (raw['is_following'] as bool? ?? false) sources.add(FeedSource.following);
    if (raw['is_discovery'] as bool? ?? false) sources.add(FeedSource.exploration);
    if (row['feed_is_trending'] as bool? ?? false) {
      sources.add(FeedSource.trending);
    }
    if (row['feed_is_latest'] as bool? ?? false) sources.add(FeedSource.latest);
    if (row['feed_is_club'] as bool? ?? false) sources.add(FeedSource.club);
    if (row['feed_is_new_creator'] as bool? ?? false) {
      sources.add(FeedSource.newCreator);
    }
    final rawSourceScores = row['feed_source_scores'] as Map<String, dynamic>?;
    final fallbackScore = (raw['wynos_score'] as num).toDouble();
    final sourceScores = <FeedSource, double>{
      for (final source in FeedSource.values)
        source: (rawSourceScores?[source.wireName] as num?)?.toDouble() ??
            fallbackScore,
    };
    result.add((
      row: row,
      score: fallbackScore,
      discovery: raw['is_discovery'] as bool,
      sources: sources,
      sourceScores: sourceScores,
      topic: row['feed_topic'] as String?,
      reasonCode: row['feed_reason_code'] as String?,
      maturity: PersonalizationMaturity.fromWire(
        row['feed_maturity_state'] as String?,
      ),
    ));
  }
  return result;
}

/// Preserves the authoritative backend ordering from
/// `get_trending_candidates()`. Keeping this as a pure decoder makes it
/// regression-testable that Home no longer applies cumulative client ranking.
List<Map<String, dynamic>> trendingCandidateRows(List<dynamic> rawRows) => [
      for (final raw in rawRows)
        Map<String, dynamic>.from(raw['row_data'] as Map<String, dynamic>),
    ];

/// Preserves `get_top100_candidates()`'s authoritative backend order.
List<Map<String, dynamic>> top100CandidateRows(List<dynamic> rawRows) => [
      for (final raw in rawRows)
        Map<String, dynamic>.from(raw['row_data'] as Map<String, dynamic>),
    ];
