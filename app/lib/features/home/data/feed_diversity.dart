/// WYNOS Unified Home Feed Algorithm V1.0 -- Feed Diversity.
///
/// One candidate for feed diversity reordering -- the minimal facts
/// [applyFeedDiversity] needs about each item, independent of how it's
/// actually rendered (that's [HomeFeedItem]'s job). Kept as its own small
/// type rather than adding `wynosScore`/`isDiscovery` fields to
/// [HomeFeedItem] itself -- those are ranking-pass-only facts nothing else
/// in the app ever needs to render, and [HomeFeedItem] is already read by
/// a large number of call sites this task has no reason to touch.
import 'feed_source.dart';

class FeedDiversityCandidate {
  const FeedDiversityCandidate({
    required this.key,
    required this.authorId,
    required this.wynosScore,
    required this.isDiscovery,
    this.feedSource = FeedSource.recommended,
    this.topic,
    this.contentType,
    String? contentIdentity,
    String? fatigueIdentity,
  })  : contentIdentity = contentIdentity ?? key,
        fatigueIdentity = fatigueIdentity ?? contentIdentity ?? key;

  /// Unique identifier for this row within one ranking pass -- for a
  /// ReDrop-sourced row this must be `'$id:$redropId'` (matching
  /// HomeDropCard's own widget key), not the bare content id alone,
  /// since the same underlying Drop can appear more than once in one
  /// candidate batch (once plain, once via someone's ReDrop of it --
  /// WYN-034).
  final String key;

  final String authorId;
  final double wynosScore;
  final bool isDiscovery;
  final FeedSource feedSource;
  final String? topic;
  final String? contentType;

  /// Identity of the underlying post. Plain and standard ReDrops share this
  /// identity and dedupe; a Quote ReDrop is intentionally distinct because
  /// its commentary is new content. [key] remains the rendered-row identity.
  final String contentIdentity;

  /// Original Drop identity even for Quote ReDrops. Quotes remain distinct for
  /// hard deduplication, but repeated social wrappers still accumulate fatigue.
  final String fatigueIdentity;
}

/// No more than this many consecutive slots from the same author --
/// Product spec requirement: "ห้ามแสดงโพสต์จาก Creator คนเดิมติดกัน
/// จำนวนมาก" (don't show many posts from the same creator back to
/// back). 2 is a starting, easily-adjustable number (not a data-backed
/// constant like the 6 Wynos Score weights in feed_ranking_config --
/// this is a structural placement rule, not a scoring weight, so it
/// stays a plain Dart constant rather than a DB config row).
const maxConsecutiveSameAuthor = 2;

/// At least one Discovery-flagged item within every window this wide,
/// if one is still available -- Product spec requirement: "ต้องมี
/// Discovery เพื่อให้ผู้ใช้ค้นพบ Creator ใหม่ ๆ", matching the rough
/// cadence of the Product spec's own example sequence (a Discovery
/// item appears roughly every 4-5 slots: positions 5 and 9 of 10).
const discoveryEveryNSlots = 5;

const maxConsecutiveSameTopic = 2;
const maxConsecutiveSameSource = 2;

/// Allocates candidates from seven independently-ranked pools. A candidate in
/// several pools is consumed only once by [contentIdentity]. Empty quotas are
/// filled in the documented fallback order, then by the best remaining pool so
/// an otherwise healthy feed is never sparse.
List<FeedDiversityCandidate> allocateFeedSources(
  Map<FeedSource, List<FeedDiversityCandidate>> pools, {
  required int limit,
  Set<String> seenContentIdentities = const {},
  Map<FeedSource, int> targetWeights = feedSourceTargetWeights,
}) {
  if (limit <= 0) return const [];
  final queues = <FeedSource, List<FeedDiversityCandidate>>{
    for (final source in FeedSource.values)
      source: <FeedDiversityCandidate>[
        ...(pools[source] ?? const <FeedDiversityCandidate>[]),
      ]
        ..sort((a, b) => b.wynosScore.compareTo(a.wynosScore)),
  };
  final used = <String>{...seenContentIdentities};
  final result = <FeedDiversityCandidate>[];

  FeedDiversityCandidate? take(FeedSource source) {
    final queue = queues[source]!;
    while (queue.isNotEmpty) {
      final candidate = queue.removeAt(0);
      if (!used.add(candidate.contentIdentity)) continue;
      return FeedDiversityCandidate(
        key: candidate.key,
        authorId: candidate.authorId,
        wynosScore: candidate.wynosScore,
        isDiscovery: candidate.isDiscovery,
        feedSource: source,
        topic: candidate.topic,
        contentType: candidate.contentType,
        contentIdentity: candidate.contentIdentity,
        fatigueIdentity: candidate.fatigueIdentity,
      );
    }
    return null;
  }

  // Weighted round-robin spreads Following and smaller discovery sources
  // throughout the window rather than emitting seven visibly separate blocks.
  final emittedBySource = <FeedSource, int>{
    for (final source in FeedSource.values) source: 0,
  };
  while (result.length < limit) {
    FeedSource? desired;
    var greatestDeficit = double.negativeInfinity;
    for (final source in FeedSource.values) {
      final target = (result.length + 1) * (targetWeights[source] ?? 0) / 100;
      final deficit = target - emittedBySource[source]!;
      if (deficit > greatestDeficit) {
        greatestDeficit = deficit;
        desired = source;
      }
    }

    var candidate = take(desired!);
    var actualSource = desired;
    if (candidate == null) {
      for (final fallback in feedFallbackPriority) {
        candidate = take(fallback);
        if (candidate != null) {
          actualSource = fallback;
          break;
        }
      }
    }
    if (candidate == null) {
      final available = FeedSource.values
          .where((source) => queues[source]!.isNotEmpty)
          .toList()
        ..sort((a, b) {
          final aScore = queues[a]!.first.wynosScore;
          final bScore = queues[b]!.first.wynosScore;
          return bScore.compareTo(aScore);
        });
      for (final source in available) {
        candidate = take(source);
        if (candidate != null) {
          actualSource = source;
          break;
        }
      }
    }
    if (candidate == null) break;
    result.add(candidate);
    emittedBySource[actualSource] = emittedBySource[actualSource]! + 1;
  }
  return result;
}

/// Bounded session-only fatigue. It decays completely when Home discards its
/// ranked window for a new session/refresh, never changes long-term affinity,
/// and never drops a candidate: when supply is sparse all eligible content
/// remains. The diminishing multipliers prevent creator/topic/format and
/// ReDrop flooding,
/// while a candidate's source score can still offset (but not erase) fatigue.
List<FeedDiversityCandidate> applyFeedFatigue(
  List<FeedDiversityCandidate> candidates,
) {
  final remaining = List<FeedDiversityCandidate>.from(candidates);
  final result = <FeedDiversityCandidate>[];
  final creators = <String, int>{};
  final topics = <String, int>{};
  final types = <String, int>{};
  final underlying = <String, int>{};

  double adjusted(FeedDiversityCandidate candidate) {
    final creatorFactor = _pow(0.82, creators[candidate.authorId] ?? 0);
    final topicFactor = _pow(0.88, topics[candidate.topic] ?? 0);
    final typeFactor = _pow(0.94, types[candidate.contentType] ?? 0);
    final priorUnderlying = underlying[candidate.fatigueIdentity] ?? 0;
    final repetitionFactor = priorUnderlying == 0 ? 1.0 : _pow(0.35, priorUnderlying);
    final fatigueFactor =
        creatorFactor * topicFactor * typeFactor * repetitionFactor;
    return candidate.wynosScore >= 0
        ? candidate.wynosScore * fatigueFactor
        : candidate.wynosScore / fatigueFactor;
  }

  while (remaining.isNotEmpty) {
    var best = 0;
    var bestScore = adjusted(remaining.first);
    for (var i = 1; i < remaining.length; i++) {
      final score = adjusted(remaining[i]);
      if (score > bestScore) {
        best = i;
        bestScore = score;
      }
    }
    final picked = remaining.removeAt(best);
    result.add(picked);
    creators[picked.authorId] = (creators[picked.authorId] ?? 0) + 1;
    if (picked.topic != null) {
      topics[picked.topic!] = (topics[picked.topic!] ?? 0) + 1;
    }
    if (picked.contentType != null) {
      types[picked.contentType!] = (types[picked.contentType!] ?? 0) + 1;
    }
    underlying[picked.fatigueIdentity] =
        (underlying[picked.fatigueIdentity] ?? 0) + 1;
  }
  return result;
}

double _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}

/// Reorders [candidates] (assumed already sorted by [FeedDiversityCandidate.wynosScore]
/// descending -- i.e. exactly what `get_wynos_ranked_feed()` already
/// returns) to satisfy Feed Diversity: no more than [maxConsecutiveSameAuthor]
/// in a row from the same author, and at least one Discovery item every
/// [discoveryEveryNSlots] slots when one is still available. A pure,
/// deterministic function of its input -- no randomness, no database
/// access -- so it can be unit-tested with fixed inputs, the same
/// "transparent, not a black box" posture WYN-018's rankingScore()
/// already established for the scoring half of this same feature.
///
/// Never drops or duplicates an item -- the result is always a
/// permutation of [candidates], same length, same set of [FeedDiversityCandidate.key]s.
/// This is what [HomeRepository.fetchRankedFeed] relies on to slice
/// pages out of the reordered list without ever producing a duplicate
/// or missing post across pages (Product spec: "ห้ามโหลดโพสต์ซ้ำ").
List<FeedDiversityCandidate> applyFeedDiversity(
  List<FeedDiversityCandidate> candidates,
) {
  final remaining = List<FeedDiversityCandidate>.from(candidates);
  final result = <FeedDiversityCandidate>[];

  // Tracks the run currently at the *tail* of [result] -- e.g. after
  // placing [A, A], lastAuthor='A' and streak=2, so the next pick must
  // not be 'A' again (streak >= maxConsecutiveSameAuthor). Placing any
  // other author resets the streak to 1 for that new author. This is
  // deliberately a "current tail run" counter, not "was this author
  // seen anywhere in the last N slots" -- A, B, A is a perfectly fine
  // sequence (no 3-in-a-row), and the latter check would have wrongly
  // blocked the 2nd A.
  String? lastAuthor;
  var currentStreak = 0;
  var slotsSinceDiscovery = 0;

  while (remaining.isNotEmpty) {
    final needsDiscovery = slotsSinceDiscovery >= discoveryEveryNSlots &&
        remaining.any((c) => c.isDiscovery);
    final blockedAuthor =
        currentStreak >= maxConsecutiveSameAuthor ? lastAuthor : null;

    int pickIndex;
    if (needsDiscovery) {
      pickIndex = remaining.indexWhere(
        (candidate) =>
            candidate.isDiscovery && candidate.authorId != blockedAuthor,
      );
      // The cadence is soft; never create an avoidable third consecutive post
      // from one creator merely to hit the Discovery slot exactly.
      if (pickIndex == -1) {
        pickIndex = remaining.indexWhere((c) => c.authorId != blockedAuthor);
      }
      if (pickIndex == -1) pickIndex = 0;
    } else {
      final tailTopic = result.isEmpty ? null : result.last.topic;
      final topicStreak = tailTopic == null
          ? 0
          : result.reversed.takeWhile((c) => c.topic == tailTopic).length;
      final tailSource = result.isEmpty ? null : result.last.feedSource;
      final sourceStreak = tailSource == null
          ? 0
          : result.reversed.takeWhile((c) => c.feedSource == tailSource).length;
      pickIndex = remaining.indexWhere((c) =>
          c.authorId != blockedAuthor &&
          (topicStreak < maxConsecutiveSameTopic || c.topic != tailTopic) &&
          (sourceStreak < maxConsecutiveSameSource || c.feedSource != tailSource));
      // Topic/source constraints are soft: retry with only the creator hard
      // preference before giving up completely.
      if (pickIndex == -1) {
        pickIndex = remaining.indexWhere((c) => c.authorId != blockedAuthor);
      }
      // Every remaining candidate is the same blocked author (e.g. only
      // one author has any content left) -- give up the constraint
      // rather than stall forever; the next best-scored item still
      // gets placed, just without the diversity guarantee this one
      // slot would otherwise have had.
      if (pickIndex == -1) pickIndex = 0;
    }

    final picked = remaining.removeAt(pickIndex);
    result.add(picked);

    if (picked.authorId == lastAuthor) {
      currentStreak++;
    } else {
      lastAuthor = picked.authorId;
      currentStreak = 1;
    }
    slotsSinceDiscovery = picked.isDiscovery ? 0 : slotsSinceDiscovery + 1;
  }

  return result;
}
