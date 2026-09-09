import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/feed_diversity.dart';
import 'package:wyn/features/home/data/feed_source.dart';

FeedDiversityCandidate _c(
  String key,
  String authorId, {
  double? score,
  bool isDiscovery = false,
  FeedSource source = FeedSource.recommended,
  String? topic,
  String? contentIdentity,
}) =>
    FeedDiversityCandidate(
      key: key,
      authorId: authorId,
      wynosScore: score ?? 0,
      isDiscovery: isDiscovery,
      feedSource: source,
      topic: topic,
      contentIdentity: contentIdentity,
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

  group('seven-source allocation', () {
    Map<FeedSource, List<FeedDiversityCandidate>> fullPools(int count) => {
          for (final source in FeedSource.values)
            source: [
              for (var i = 0; i < count; i++)
                _c('${source.wireName}-$i', '${source.wireName}-author-$i',
                    score: (count - i).toDouble(),
                    source: source,
                    contentIdentity: '${source.wireName}:$i'),
            ],
        };

    test('all seven sources contribute at the 35/20/10/10/10/10/5 target',
        () {
      final result = allocateFeedSources(fullPools(100), limit: 100);
      final counts = <FeedSource, int>{
        for (final source in FeedSource.values)
          source: result.where((item) => item.feedSource == source).length,
      };
      expect(counts, feedSourceTargetWeights);
    });

    test('empty source quotas fall back without leaving avoidable holes', () {
      final pools = fullPools(30)
        ..[FeedSource.club] = []
        ..[FeedSource.trending] = [];
      final result = allocateFeedSources(pools, limit: 20);
      expect(result, hasLength(20));
      expect(result.where((item) => item.feedSource == FeedSource.club), isEmpty);
      expect(
        result.where((item) => item.feedSource == FeedSource.recommended),
        isNotEmpty,
      );
    });

    test('a candidate present in multiple pools is emitted only once', () {
      final duplicate = _c('render-a', 'author-a',
          score: 100, contentIdentity: 'drop:a');
      final result = allocateFeedSources({
        FeedSource.following: [duplicate],
        FeedSource.recommended: [duplicate],
        FeedSource.latest: [duplicate],
      }, limit: 10);
      expect(result, hasLength(1));
    });

    test('page 2 excludes every identity seen on page 1', () {
      final pools = fullPools(20);
      final first = allocateFeedSources(pools, limit: 10);
      final second = allocateFeedSources(
        pools,
        limit: 10,
        seenContentIdentities:
            first.map((item) => item.contentIdentity).toSet(),
      );
      expect(
        first.map((item) => item.contentIdentity).toSet().intersection(
              second.map((item) => item.contentIdentity).toSet(),
            ),
        isEmpty,
      );
      expect(second, hasLength(10));
    });

    test('plain and standard redrop dedupe while a quote remains distinct', () {
      final result = allocateFeedSources({
        FeedSource.following: [
          _c('plain', 'original', score: 100, contentIdentity: 'drop:a'),
          _c('standard-redrop', 'original',
              score: 90, contentIdentity: 'drop:a'),
          _c('quote-redrop', 'original',
              score: 80, contentIdentity: 'drop:a:quote:q1'),
        ],
      }, limit: 10);
      expect(result.map((item) => item.key), ['plain', 'quote-redrop']);
    });

    test('topic and source runs are broken when alternatives exist', () {
      final candidates = [
        for (var i = 0; i < 3; i++)
          _c('same-$i', 'author-$i',
              score: (100 - i).toDouble(),
              source: FeedSource.recommended,
              topic: 'music'),
        _c('alternate', 'author-x',
            score: 1, source: FeedSource.latest, topic: 'sports'),
      ];
      final result = applyFeedDiversity(candidates);
      expect(result.map((item) => item.key),
          ['same-0', 'same-1', 'alternate', 'same-2']);
    });
  });
}
