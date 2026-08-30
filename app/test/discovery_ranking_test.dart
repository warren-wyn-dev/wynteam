import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/search/data/discovery_ranking.dart';

void main() {
  group('rankTrendingHashtags', () {
    test('ranks tags by frequency (posts mentioning it), most-mentioned '
        'first, with counts', () {
      final captions = [
        // #wyn repeated within one caption still counts as 1 post, not 2
        // -- postCount is "how many distinct posts", not "how many
        // occurrences" (extractHashtags returns a per-text Set).
        'สวัสดี #wyn วันนี้อากาศดี #wyn',
        'ลอง #wyn กับ #flutter',
        'อีกโพสต์ #wyn',
        'สุดท้าย #flutter',
      ];

      final ranked = rankTrendingHashtags(captions, limit: 10);

      // "wyn": posts 1, 2, 3 = 3. "flutter": posts 2, 4 = 2.
      expect(ranked, hasLength(2));
      expect(ranked[0].tag, 'wyn');
      expect(ranked[0].postCount, 3);
      expect(ranked[1].tag, 'flutter');
      expect(ranked[1].postCount, 2);
    });

    test('caps the result at [limit]', () {
      final captions = ['#a #b #c #d #e'];

      final ranked = rankTrendingHashtags(captions, limit: 2);

      expect(ranked, hasLength(2));
    });

    test('ignores null captions (Pop content with no caption)', () {
      final captions = [null, '#wyn', null];

      final ranked = rankTrendingHashtags(captions, limit: 10);

      expect(ranked, hasLength(1));
      expect(ranked.single.tag, 'wyn');
      expect(ranked.single.postCount, 1);
    });

    test('an empty candidate list ranks to an empty result, not an error', () {
      expect(rankTrendingHashtags(const [], limit: 20), isEmpty);
    });

    test('a caption with no hashtags contributes nothing', () {
      final captions = ['วันนี้อากาศดีมาก ไม่มีแฮชแท็กเลย'];

      expect(rankTrendingHashtags(captions, limit: 20), isEmpty);
    });
  });
}
