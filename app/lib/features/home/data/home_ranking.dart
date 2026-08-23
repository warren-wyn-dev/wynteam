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

/// Shared "how much engagement has this item gotten" building block for
/// both [rankingScore] (WYN-018, "สำหรับคุณ") and
/// `HomeRepository.fetchTrending` (WYN-017, "กำลังนิยม") -- a single
/// source of truth so the two formulas can't silently drift apart on
/// the like/comment weights (they used to: fetchTrending summed
/// like+comment 1:1 while this used 2:3 -- WYN-041 aligns them).
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
