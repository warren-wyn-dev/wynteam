import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/home/data/feed_diversity.dart';
import 'package:wyn/features/home/data/feed_experiment.dart';
import 'package:wyn/features/home/data/feed_source.dart';

void main() {
  test('missing or malformed resolution preserves production exactly', () {
    final missing = EffectiveHomeExperiment.fromRpc(null);
    final invalid = EffectiveHomeExperiment.fromRpc({
      'home.source_mix': {'following': -1},
    });
    expect(missing.sourceWeights, isNull);
    expect(missing.fatigue.creatorFactor, 0.82);
    expect(invalid.sourceWeights, isNull);
    expect(invalid.fatigue.creatorFactor, 0.82);
  });

  test('valid source mix is typed, complete, and sums to 100', () {
    final config = EffectiveHomeExperiment.fromRpc({
      'home.source_mix': {
        'following': 30,
        'recommended': 25,
        'trending': 10,
        'latest': 10,
        'club': 10,
        'new_creator': 10,
        'exploration': 5,
      },
      '_assignments': ['home_mix:v1:treatment'],
    });
    expect(config.sourceWeights!.values.reduce((a, b) => a + b), 100);
    expect(config.sourceWeights![FeedSource.following], 30);
    expect(config.assignments, ['home_mix:v1:treatment']);
  });

  test('invalid sum and unsafe fatigue factor fail closed', () {
    Map<String, int> mix(int following) => {
          'following': following,
          'recommended': 20,
          'trending': 10,
          'latest': 10,
          'club': 10,
          'new_creator': 10,
          'exploration': 5,
        };
    expect(EffectiveHomeExperiment.fromRpc({'home.source_mix': mix(34)})
        .sourceWeights, isNull);
    expect(EffectiveHomeExperiment.fromRpc({'fatigue.creator_factor': 2})
        .fatigue.creatorFactor, 0.82);
  });

  test('fatigue treatment changes ordering without dropping candidates', () {
    FeedDiversityCandidate item(String key, String author, double score) =>
        FeedDiversityCandidate(
          key: key,
          authorId: author,
          wynosScore: score,
          isDiscovery: false,
          contentIdentity: key,
        );
    final candidates = [
      item('a1', 'a', 100),
      item('a2', 'a', 99),
      item('b1', 'b', 70),
    ];
    final treatment = applyFeedFatigue(
      candidates,
      config: const FeedFatigueConfig(
        creatorFactor: 0.5,
        topicFactor: 0.88,
        contentTypeFactor: 0.94,
        repetitionFactor: 0.35,
      ),
    );
    expect(treatment.map((e) => e.key), ['a1', 'b1', 'a2']);
    expect(treatment.toSet(), candidates.toSet());
  });

  test('experimental source mix keeps Phase 1 empty-pool fallback', () {
    final config = EffectiveHomeExperiment.fromRpc({
      'home.source_mix': {
        'following': 40,
        'recommended': 20,
        'trending': 10,
        'latest': 10,
        'club': 5,
        'new_creator': 10,
        'exploration': 5,
      },
    });
    FeedDiversityCandidate item(String key, FeedSource source) =>
        FeedDiversityCandidate(
          key: key,
          authorId: key,
          wynosScore: 1,
          isDiscovery: source == FeedSource.exploration,
          feedSource: source,
        );
    final result = allocateFeedSources(
      {
        FeedSource.following: [],
        FeedSource.recommended: [
          for (var i = 0; i < 10; i++) item('r$i', FeedSource.recommended),
        ],
        FeedSource.latest: [
          for (var i = 0; i < 10; i++) item('l$i', FeedSource.latest),
        ],
      },
      limit: 10,
      targetWeights: config.sourceWeights!,
    );
    expect(result, hasLength(10));
    expect(result.where((item) => item.feedSource == FeedSource.following),
        isEmpty);
  });
}
