import 'dart:math';

import '../../../core/text_utils.dart';
import '../../home/data/home_feed_item.dart';

/// One hashtag's rank -- [tag] plus its accumulated [score] (WYN-101).
/// [postCount] is kept only for internal tie-breaking (see
/// [rankTrendingHashtags]) -- no longer shown in the UI (Founder,
/// Wynos V1.0.0 Beta2 item 10: "ปล. ใต้แฮชแท็ก ห้ามระบุว่ากี่โพสต์").
class RankedHashtag {
  const RankedHashtag({
    required this.tag,
    required this.postCount,
    required this.score,
  });

  final String tag;
  final int postCount;
  final double score;
}

// WYN-101 (Wynos V1.0.0 Beta2, item 10, 2026-09-02): weights/decay as
// named constants, not inlined into _trendingScore, so a future tuning
// pass (Founder seeing real results and wanting different weights) is
// a one-line change here rather than a rewrite of the ranking logic --
// per the Product spec's own Risk R1 mitigation.
const double _likeWeight = 1;
const double _commentWeight = 2;
const double _repostWeight = 3;
const double _viewWeight = 0.1;
const double _decayOffset = 2;
const double _decayExponent = 1.5;

/// A single post's contribution to its hashtags' trending score --
/// engagement-weighted (comments/reposts count for more than a bare
/// like) with a time-decay denominator so a post going viral *right
/// now* outranks an older post that merely accumulated more engagement
/// over a longer time. `+ _decayOffset` keeps the denominator away from
/// zero for a just-published post instead of dividing by ~0.
double _trendingScore(HomeFeedItem item, DateTime now) {
  final hours = now.difference(item.createdAt).inMinutes / 60.0;
  final engagement = item.likeCount * _likeWeight +
      item.commentCount * _commentWeight +
      item.redropCount * _repostWeight +
      (item.viewCount ?? 0) * _viewWeight;
  return engagement / pow(hours + _decayOffset, _decayExponent);
}

/// Ranks every `#hashtag` mentioned across [items]' captions (via
/// [extractHashtags] -- WYN-020's own tokenizer, reused as-is) by
/// accumulated trending score (WYN-101), returning the top [limit]
/// tags highest-score first. A post with multiple hashtags contributes
/// its full score to each of them (same "counted once per tag it has"
/// shape the old frequency count used, not divided across tags).
///
/// Pure/no I/O, mirroring `home_ranking.dart`'s `rankingScore()` shape
/// -- lets `DiscoveryRepository.fetchTrendingHashtags`'s ranking logic
/// be unit-tested without a live Supabase call. [now] is injectable for
/// exactly that reason (deterministic time-decay in tests).
List<RankedHashtag> rankTrendingHashtags(
  Iterable<HomeFeedItem> items, {
  required int limit,
  DateTime? now,
}) {
  final effectiveNow = now ?? DateTime.now();
  final score = <String, double>{};
  final postCount = <String, int>{};
  for (final item in items) {
    final caption = item.caption;
    if (caption == null) continue;
    final tags = extractHashtags(caption);
    if (tags.isEmpty) continue;
    final itemScore = _trendingScore(item, effectiveNow);
    for (final tag in tags) {
      score[tag] = (score[tag] ?? 0) + itemScore;
      postCount[tag] = (postCount[tag] ?? 0) + 1;
    }
  }

  final ranked = score.keys.toList()
    ..sort((a, b) {
      final byScore = score[b]!.compareTo(score[a]!);
      // Deterministic tie-break (Edge Case 4) -- higher postCount wins
      // an exact-score tie, rather than leaving insertion order (which
      // depends on Map iteration, not user-meaningful) to decide.
      if (byScore != 0) return byScore;
      return postCount[b]!.compareTo(postCount[a]!);
    });
  return ranked
      .take(limit)
      .map((tag) => RankedHashtag(
            tag: tag,
            postCount: postCount[tag]!,
            score: score[tag]!,
          ))
      .toList();
}
