import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/home/data/cold_start.dart';
import 'package:wyn/features/home/data/feed_diversity.dart';
import 'package:wyn/features/home/data/feed_source.dart';

FeedDiversityCandidate candidate(String id, FeedSource source, {String? topic}) =>
    FeedDiversityCandidate(
      key: id,
      authorId: 'author-$id',
      wynosScore: (100 - int.parse(id.split('-').last)).toDouble(),
      isDiscovery: source == FeedSource.exploration,
      feedSource: source,
      topic: topic ?? 'topic-${int.parse(id.split('-').last) % 5}',
    );

void main() {
  test('every maturity policy is a complete bounded allocation', () {
    for (final entry in coldStartSourceWeights.entries) {
      expect(entry.value.keys.toSet(), FeedSource.values.toSet());
      expect(entry.value.values.reduce((a, b) => a + b), 100);
    }
    expect(coldStartSourceWeights[PersonalizationMaturity.zeroHistory]![FeedSource.following], 0);
    expect(coldStartSourceWeights[PersonalizationMaturity.zeroHistory]![FeedSource.club], 0);
    expect(coldStartSourceWeights[PersonalizationMaturity.personalized], feedSourceTargetWeights);
  });

  test('unknown backend maturity safely falls back to zero history', () {
    expect(
      PersonalizationMaturity.fromWire(null),
      PersonalizationMaturity.zeroHistory,
    );
    expect(
      PersonalizationMaturity.fromWire('future_version'),
      PersonalizationMaturity.zeroHistory,
    );
  });

  test('zero history redistributes empty social pools into diverse sources', () {
    final pools = <FeedSource, List<FeedDiversityCandidate>>{
      for (final source in FeedSource.values)
        source: source == FeedSource.following || source == FeedSource.club
            ? []
            : List.generate(20, (i) => candidate('${source.index}-$i', source)),
    };
    final result = allocateFeedSources(
      pools,
      limit: 20,
      targetWeights:
          coldStartSourceWeights[PersonalizationMaturity.zeroHistory]!,
    );
    expect(result, hasLength(20));
    expect(result.map((e) => e.contentIdentity).toSet(), hasLength(20));
    expect(
      result.map((e) => e.feedSource).toSet().length,
      greaterThanOrEqualTo(4),
    );
    expect(
      result.where((e) => e.feedSource == FeedSource.trending).length,
      lessThan(10),
    );
  });

  test('one sparse creator cannot be duplicated to fill Following quota', () {
    final shared = candidate('0-1', FeedSource.following);
    final pools = <FeedSource, List<FeedDiversityCandidate>>{
      for (final source in FeedSource.values) source: [],
      FeedSource.following: [shared],
      FeedSource.recommended: [
        shared,
        ...List.generate(
          12,
          (i) => candidate('1-$i', FeedSource.recommended),
        ),
      ],
      FeedSource.latest: List.generate(
        12,
        (i) => candidate('3-$i', FeedSource.latest),
      ),
    };
    final result = allocateFeedSources(
      pools,
      limit: 20,
      targetWeights: coldStartSourceWeights[PersonalizationMaturity.sparse]!,
    );
    expect(result, hasLength(20));
    expect(
      result.where((e) => e.contentIdentity == shared.contentIdentity),
      hasLength(1),
    );
  });
}
