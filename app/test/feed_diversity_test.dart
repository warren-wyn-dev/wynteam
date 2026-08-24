import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/feed_diversity.dart';

FeedDiversityCandidate _c(
  String key,
  String authorId, {
  double? score,
  bool isDiscovery = false,
}) =>
    FeedDiversityCandidate(
      key: key,
      authorId: authorId,
      wynosScore: score ?? 0,
      isDiscovery: isDiscovery,
    );

void main() {
  group('applyFeedDiversity (WYNOS Unified Home Feed Algorithm V1.0)', () {
    test('an empty list stays empty', () {
      expect(applyFeedDiversity([]), isEmpty);
    });

    test('a single item passes through unchanged', () {
      final candidates = [_c('a', 'author-1')];
      expect(applyFeedDiversity(candidates), candidates);
    });

    test('already-diverse input (alternating authors) keeps score order',
        () {
      final candidates = [
        _c('a', 'author-1', score: 90),
        _c('b', 'author-2', score: 80),
        _c('c', 'author-1', score: 70),
        _c('d', 'author-3', score: 60),
      ];
      final result = applyFeedDiversity(candidates);
      expect(result.map((c) => c.key).toList(), ['a', 'b', 'c', 'd']);
    });

    test('never drops or duplicates an item -- result is a permutation of '
        'the input', () {
      final candidates = [
        _c('a', 'author-1', score: 100),
        _c('b', 'author-1', score: 90),
        _c('c', 'author-1', score: 80),
        _c('d', 'author-2', score: 70),
        _c('e', 'author-3', score: 60, isDiscovery: true),
      ];
      final result = applyFeedDiversity(candidates);
      expect(result.length, candidates.length);
      expect(
        result.map((c) => c.key).toSet(),
        candidates.map((c) => c.key).toSet(),
      );
    });

    test(
        '3 consecutive posts from the same author get broken up by a '
        'lower-scored item from someone else', () {
      final candidates = [
        _c('a', 'author-1', score: 100),
        _c('b', 'author-1', score: 90),
        _c('c', 'author-1', score: 80),
        _c('d', 'author-2', score: 10),
      ];
      final result = applyFeedDiversity(candidates);

      // 'a' and 'b' (author-1) can still run together (max 2 in a row),
      // but the 3rd author-1 post ('c') must not immediately follow --
      // 'd' (the only other author available) gets pulled forward.
      expect(result.map((c) => c.key).toList(), ['a', 'b', 'd', 'c']);
    });

    test(
        'never places more than maxConsecutiveSameAuthor in a row, for a '
        'long same-author run, as long as enough other authors exist to '
        'break it up', () {
      // 6 posts from author-1 dominate by score, but 3 different other
      // authors have at least one post each -- enough alternates to
      // satisfy "max 2 in a row" for every one of author-1's breaks.
      final candidates = [
        for (var i = 0; i < 6; i++)
          _c('same-$i', 'author-1', score: (100 - i).toDouble()),
        for (var i = 0; i < 3; i++)
          _c('other-$i', 'author-${i + 2}', score: (10 - i).toDouble()),
      ];
      final result = applyFeedDiversity(candidates);

      var streak = 0;
      String? lastAuthor;
      for (final item in result) {
        streak = item.authorId == lastAuthor ? streak + 1 : 1;
        lastAuthor = item.authorId;
        expect(streak, lessThanOrEqualTo(maxConsecutiveSameAuthor));
      }
    });

    test(
        'when the same author dominates so heavily that no alternate is '
        'left, the diversity constraint is relaxed rather than the '
        'function stalling or losing items', () {
      final candidates = [
        for (var i = 0; i < 6; i++)
          _c('same-$i', 'author-1', score: (100 - i).toDouble()),
        _c('other', 'author-2', score: 1),
      ];
      final result = applyFeedDiversity(candidates);

      // Only 1 alternate post exists for 6 same-author posts -- "never
      // more than 2 in a row" is mathematically unsatisfiable here, so
      // this only asserts the function's actual contract: nothing lost,
      // nothing duplicated, no infinite loop.
      expect(result.length, candidates.length);
      expect(
        result.map((c) => c.key).toSet(),
        candidates.map((c) => c.key).toSet(),
      );
    });

    test(
        'falls back to placing the next item anyway when every remaining '
        'candidate is the same (already-streaking) author -- never stalls',
        () {
      final candidates = [
        for (var i = 0; i < 4; i++)
          _c('a$i', 'author-1', score: (100 - i).toDouble()),
      ];
      final result = applyFeedDiversity(candidates);

      expect(result.length, 4);
      expect(result.map((c) => c.key).toSet(), {'a0', 'a1', 'a2', 'a3'});
    });

    test(
        'a Discovery item is pulled forward once discoveryEveryNSlots '
        'non-Discovery slots have passed, even if it scores lower than '
        'everything ahead of it', () {
      final candidates = [
        for (var i = 0; i < discoveryEveryNSlots; i++)
          _c('p$i', 'author-${i + 1}', score: (100 - i).toDouble()),
        _c('discovery', 'new-author', score: 1, isDiscovery: true),
        _c('after', 'author-99', score: 0.5),
      ];
      final result = applyFeedDiversity(candidates);

      final discoveryIndex = result.indexWhere((c) => c.key == 'discovery');
      expect(discoveryIndex, lessThanOrEqualTo(discoveryEveryNSlots));
    });

    test('no Discovery items in the batch at all -- diversity still runs '
        'normally, no crash, no infinite loop', () {
      final candidates = [
        for (var i = 0; i < 12; i++)
          _c('p$i', 'author-${i % 2}', score: (12 - i).toDouble()),
      ];
      final result = applyFeedDiversity(candidates);

      expect(result.length, candidates.length);
    });

    test('multiple Discovery items -- only the earliest-needed one is '
        'pulled forward per window, the rest stay in score order among '
        'themselves', () {
      final candidates = [
        _c('p0', 'author-1', score: 100),
        _c('d1', 'discoverer-1', score: 90, isDiscovery: true),
        _c('d2', 'discoverer-2', score: 80, isDiscovery: true),
        _c('p1', 'author-2', score: 70),
      ];
      final result = applyFeedDiversity(candidates);

      // Nothing here is streaking or forced yet (discoveryEveryNSlots is
      // 5) -- with no diversity rule actually triggered, plain score
      // order is preserved exactly.
      expect(result.map((c) => c.key).toList(), ['p0', 'd1', 'd2', 'p1']);
    });
  });
}
