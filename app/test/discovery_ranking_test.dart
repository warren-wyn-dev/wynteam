import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/search/data/discovery_ranking.dart';

void main() {
  group('rankTrendingHashtags', () {
    test('ranks tags by frequency, most-mentioned first', () {
      final captions = [
        'สวัสดี #wyn วันนี้อากาศดี #wyn',
        'ลอง #flutter กับ #wyn',
        'อีกโพสต์ #flutter',
      ];

      final ranked = rankTrendingHashtags(captions, limit: 10);

      // "wyn" appears 3 times, "flutter" appears 2 times.
      expect(ranked, ['wyn', 'flutter']);
    });

    test('caps the result at [limit]', () {
      final captions = ['#a #b #c #d #e'];

      final ranked = rankTrendingHashtags(captions, limit: 2);

      expect(ranked, hasLength(2));
    });

    test('ignores null captions (Pop content with no caption)', () {
      final captions = [null, '#wyn', null];

      final ranked = rankTrendingHashtags(captions, limit: 10);

      expect(ranked, ['wyn']);
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
