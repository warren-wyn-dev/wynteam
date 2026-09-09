import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/home/data/feed_diversity.dart';
import 'package:wyn/features/home/data/feed_source.dart';

FeedDiversityCandidate item(
  String key,
  String author,
  double score, {
  String? topic = 'topic',
  String? type = 'image',
  String? underlying,
}) =>
    FeedDiversityCandidate(
      key: key,
      authorId: author,
      wynosScore: score,
      isDiscovery: false,
      feedSource: FeedSource.recommended,
      topic: topic,
      contentType: type,
      contentIdentity: key,
      fatigueIdentity: underlying,
    );

void main() {
  test('creator fatigue makes room without dropping eligible content', () {
    final result = applyFeedFatigue([
      item('a1', 'a', 100),
      item('a2', 'a', 99),
      item('a3', 'a', 98),
      item('b1', 'b', 70, topic: 'other'),
    ]);
    expect(result.map((e) => e.key), ['a1', 'a2', 'b1', 'a3']);
    expect(result, hasLength(4));
  });

  test('topic fatigue is temporary and does not mutate affinity or score', () {
    final gaming = item('g1', 'a', 100, topic: 'gaming');
    final result = applyFeedFatigue([
      gaming,
      item('g2', 'b', 99, topic: 'gaming'),
      item('g3', 'c', 98, topic: 'gaming'),
      item('m1', 'd', 80, topic: 'music'),
    ]);
    expect(result.map((e) => e.key), ['g1', 'g2', 'm1', 'g3']);
    expect(gaming.wynosScore, 100); // Session ordering never changes affinity.
  });

  test('Quote ReDrops remain distinct but share underlying fatigue', () {
    final result = applyFeedFatigue([
      item('quote-1', 'a', 100, underlying: 'drop:original'),
      item('quote-2', 'b', 90, underlying: 'drop:original'),
      item('different', 'c', 50, underlying: 'drop:different'),
    ]);
    expect(result.map((e) => e.key), ['quote-1', 'different', 'quote-2']);
    expect(result.map((e) => e.key).toSet(), hasLength(3));
  });

  test('missing topic/content type is neutral and sparse supply stays full', () {
    final input = [
      item('a', 'same', 3, topic: null, type: null),
      item('b', 'same', 2, topic: null, type: null),
      item('c', 'same', 1, topic: null, type: null),
    ];
    expect(applyFeedFatigue(input).map((e) => e.key).toSet(), hasLength(3));
  });
}
