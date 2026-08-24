/// WYNOS Unified Home Feed Algorithm V1.0 -- Feed Diversity.
///
/// One candidate for feed diversity reordering -- the minimal facts
/// [applyFeedDiversity] needs about each item, independent of how it's
/// actually rendered (that's [HomeFeedItem]'s job). Kept as its own small
/// type rather than adding `wynosScore`/`isDiscovery` fields to
/// [HomeFeedItem] itself -- those are ranking-pass-only facts nothing else
/// in the app ever needs to render, and [HomeFeedItem] is already read by
/// a large number of call sites this task has no reason to touch.
class FeedDiversityCandidate {
  const FeedDiversityCandidate({
    required this.key,
    required this.authorId,
    required this.wynosScore,
    required this.isDiscovery,
  });

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

    int pickIndex;
    if (needsDiscovery) {
      pickIndex = remaining.indexWhere((c) => c.isDiscovery);
    } else {
      final blockedAuthor =
          currentStreak >= maxConsecutiveSameAuthor ? lastAuthor : null;
      pickIndex = remaining.indexWhere((c) => c.authorId != blockedAuthor);
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
