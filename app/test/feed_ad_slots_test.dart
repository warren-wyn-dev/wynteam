import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/feed_ad_slots.dart';

void main() {
  group('feedAdSlotCountWithin (WYN-106)', () {
    test('kFeedAdInterval is 8 -- Founder-approved 2026-09-03, pinned so a '
        'later accidental change is caught here first', () {
      expect(kFeedAdInterval, 8);
    });

    test('0 real posts -- no ad-slots', () {
      expect(feedAdSlotCountWithin(0), 0);
    });

    test('fewer than kFeedAdInterval real posts -- no ad-slots at all '
        '(design spec: "โฆษณาไม่ปรากฏเลยถ้าฟีดยังมีโพสต์จริงไม่ถึง N โพสต์")',
        () {
      for (var i = 0; i < kFeedAdInterval; i++) {
        expect(feedAdSlotCountWithin(i), 0, reason: 'realPostCount=$i');
      }
    });

    test('exactly kFeedAdInterval real posts -- exactly 1 ad-slot', () {
      expect(feedAdSlotCountWithin(8), 1);
    });

    test('one short of the next interval -- still only 1 ad-slot', () {
      expect(feedAdSlotCountWithin(15), 1);
    });

    test('2 full intervals -- exactly 2 ad-slots', () {
      expect(feedAdSlotCountWithin(16), 2);
    });

    test('3 full intervals -- exactly 3 ad-slots', () {
      expect(feedAdSlotCountWithin(24), 3);
    });
  });

  group('feedContentRowCount (WYN-106)', () {
    test('equals realPostCount alone below kFeedAdInterval', () {
      expect(feedContentRowCount(5), 5);
    });

    test('adds exactly the ad-slot count on top of the real post count', () {
      expect(feedContentRowCount(8), 9); // 8 posts + 1 ad-slot
      expect(feedContentRowCount(16), 18); // 16 posts + 2 ad-slots
      expect(feedContentRowCount(23), 25); // 23 posts + 2 ad-slots
    });
  });

  group('feedContentRowAt (WYN-106)', () {
    test('position 0..7 map to FeedRealPostRow(0..7)', () {
      for (var i = 0; i < kFeedAdInterval; i++) {
        expect(feedContentRowAt(i), FeedRealPostRow(i));
      }
    });

    test('position 8 (right after the 8th real post) is the first ad-slot',
        () {
      expect(feedContentRowAt(8), const FeedAdSlotRow(0));
    });

    test('positions 9..16 (the next 8 real posts) map to FeedRealPostRow('
        '8..15)', () {
      for (var i = 0; i < kFeedAdInterval; i++) {
        expect(feedContentRowAt(9 + i), FeedRealPostRow(8 + i));
      }
    });

    test('position 17 is the second ad-slot', () {
      expect(feedContentRowAt(17), const FeedAdSlotRow(1));
    });

    test('position 26 is the third ad-slot (after 3 full groups of 8)', () {
      expect(feedContentRowAt(26), const FeedAdSlotRow(2));
    });

    test('never places 2 ad-slots back to back -- every ad-slot position '
        'is followed immediately by a real post, never another ad-slot',
        () {
      for (var group = 0; group < 5; group++) {
        final adPosition = group * (kFeedAdInterval + 1) + kFeedAdInterval;
        expect(feedContentRowAt(adPosition), isA<FeedAdSlotRow>());
        expect(feedContentRowAt(adPosition + 1), isA<FeedRealPostRow>());
      }
    });

    test(
        'walking every position up to feedContentRowCount(realPostCount) '
        'for a range of feed sizes visits every real post index exactly '
        'once, in order, with the expected number of ad-slots interleaved '
        '-- the same "never drops or duplicates" contract '
        'feed_diversity_test.dart holds applyFeedDiversity to', () {
      for (final realPostCount in [0, 1, 7, 8, 9, 15, 16, 17, 30, 33]) {
        final rowCount = feedContentRowCount(realPostCount);
        final seenItemIndexes = <int>[];
        var adSlotCount = 0;

        for (var p = 0; p < rowCount; p++) {
          final row = feedContentRowAt(p);
          switch (row) {
            case FeedRealPostRow(itemIndex: final itemIndex):
              seenItemIndexes.add(itemIndex);
            case FeedAdSlotRow(adSlotIndex: final adSlotIndex):
              expect(adSlotIndex, adSlotCount,
                  reason: 'ad-slots must appear in ascending order');
              adSlotCount++;
          }
        }

        expect(seenItemIndexes, List.generate(realPostCount, (i) => i),
            reason: 'realPostCount=$realPostCount');
        expect(adSlotCount, feedAdSlotCountWithin(realPostCount),
            reason: 'realPostCount=$realPostCount');
      }
    });
  });
}
