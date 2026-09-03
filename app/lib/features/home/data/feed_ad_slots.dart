/// WYN-106 -- Native In-Feed Ads (Home feed, "สำหรับคุณ" only): pure,
/// deterministic placement logic for *where* an ad-slot belongs among
/// the real posts already loaded, mirroring feed_diversity.dart's own
/// "pure, no database/SDK access, unit-testable" shape on purpose --
/// this is a business rule with logic worth testing the same way, and
/// the design spec explicitly asks for exactly this file (see
/// .wyn/docs/design/wyn-106-feed-native-ads.md, section 2: "แนะนำให้
/// Coding เพิ่ม pure function แยกไฟล์ใหม่ ... mirror รูปแบบเดียวกับ
/// feed_diversity.dart เป๊ะ").
///
/// Deliberately carries **no** dependency on `google_mobile_ads` or any
/// other AdMob SDK type -- everything here is plain `int` arithmetic, so
/// it can be unit tested (see feed_ad_slots_test.dart) without mocking a
/// NativeAd at all, same as feed_diversity_test.dart needs no database.
///
/// This is a completely separate, later pass than
/// [FeedDiversityCandidate]/`applyFeedDiversity` (feed_diversity.dart) --
/// ad-slots are never mixed into that ranking pipeline, never become a
/// `FeedDiversityCandidate`, and never reach `_items`/`HomeFeedItem` in
/// home_feed_screen.dart. See that file's own `_buildBodySlivers` for the
/// only place these functions are actually called, and its own
/// `adsEnabled` gate for why every mode other than "สำหรับคุณ" (and
/// every build without a real AdMob config, see core/ad_env.dart) never
/// calls into this file at all.
library;

/// One ad-slot for every this many consecutive *real* posts rendered --
/// Founder-approved 2026-09-03 (design spec, "ค่า N = 8"). Hardcoded in
/// the app, not server config, per that same decision: changing the
/// cadence requires a new app release, a deliberate trade-off already
/// accepted.
const kFeedAdInterval = 8;

/// How many ad-slots belong within the first [realPostCount] real posts
/// already loaded -- e.g. 8 real posts means exactly 1 ad-slot (right
/// after the 8th), 15 still means 1, 16 means 2. Zero for any count
/// under [kFeedAdInterval], which is what keeps a fresh/small feed
/// (design spec section 1: "โฆษณาไม่ปรากฏเลยถ้าฟีดยังมีโพสต์จริงไม่ถึง N
/// โพสต์") ad-free without any extra rule -- integer division already
/// gives 0 for every count below the interval.
int feedAdSlotCountWithin(int realPostCount) {
  assert(realPostCount >= 0, 'realPostCount must not be negative');
  return realPostCount ~/ kFeedAdInterval;
}

/// Total rows (real posts + ad-slots) once ad-slots are interleaved
/// among [realPostCount] real posts -- what `_buildBodySlivers` uses in
/// place of a bare `_items.length` when ad-slots are enabled for the
/// current render.
int feedContentRowCount(int realPostCount) =>
    realPostCount + feedAdSlotCountWithin(realPostCount);

/// One row of the interleaved (posts + ad-slots) sequence -- either a
/// real post ([FeedRealPostRow], carrying the index it has in `_items`,
/// untouched by ad insertion) or an ad-slot ([FeedAdSlotRow], carrying
/// its own 0-based ordinal among ad-slots only).
sealed class FeedContentRow {
  const FeedContentRow();
}

/// A real post -- [itemIndex] is exactly the index this row has in
/// `_items`, so every existing index-based method
/// (`_toggleLike`/`_toggleSave`/`_hideItem`/...) keeps addressing
/// `_items` exactly as it did before ad-slots existed (design spec
/// section 2: "`_toggleLike(index)`/... ไม่ต้องแก้แม้แต่บรรทัดเดียว").
class FeedRealPostRow extends FeedContentRow {
  const FeedRealPostRow(this.itemIndex);

  final int itemIndex;

  @override
  bool operator ==(Object other) =>
      other is FeedRealPostRow && other.itemIndex == itemIndex;

  @override
  int get hashCode => Object.hash(FeedRealPostRow, itemIndex);

  @override
  String toString() => 'FeedRealPostRow($itemIndex)';
}

/// An ad-slot -- [adSlotIndex] is 0-based and stable across rebuilds of
/// the *same* loaded feed (same `_items`), so it can key a widget/an
/// AdMob load without depending on any post's own id (design spec
/// section 2: an ad's position is "ฟังก์ชันล้วนของ 'โพสต์จริงที่ผ่านมา
/// แล้วกี่โพสต์' ไม่ใช่ผูกกับ id ของโพสต์เฉพาะ").
class FeedAdSlotRow extends FeedContentRow {
  const FeedAdSlotRow(this.adSlotIndex);

  final int adSlotIndex;

  @override
  bool operator ==(Object other) =>
      other is FeedAdSlotRow && other.adSlotIndex == adSlotIndex;

  @override
  int get hashCode => Object.hash(FeedAdSlotRow, adSlotIndex);

  @override
  String toString() => 'FeedAdSlotRow($adSlotIndex)';
}

/// Which row sits at [position] (0-based) in the interleaved sequence
/// once ad-slots are inserted -- pure arithmetic over the fixed pattern
/// "[kFeedAdInterval] real posts, then 1 ad-slot, repeat", with no
/// dependency on how many real posts actually exist (a caller only ever
/// asks for `position < feedContentRowCount(_items.length)`, same
/// contract `applyFeedDiversity` leaves to its own caller for its input
/// list).
FeedContentRow feedContentRowAt(int position) {
  assert(position >= 0, 'position must not be negative');
  const groupSize = kFeedAdInterval + 1;
  final group = position ~/ groupSize;
  final offsetInGroup = position % groupSize;
  if (offsetInGroup < kFeedAdInterval) {
    return FeedRealPostRow(group * kFeedAdInterval + offsetInGroup);
  }
  return FeedAdSlotRow(group);
}
