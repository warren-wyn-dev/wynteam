import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/home/data/feed_source.dart';

void main() {
  test('For You source allocation stays balanced and totals 100 percent', () {
    expect(feedSourceTargetWeights.values.fold<int>(0, (a, b) => a + b), 100);

    expect(feedSourceTargetWeights[FeedSource.following], 25);
    expect(feedSourceTargetWeights[FeedSource.recommended], 30);
    expect(feedSourceTargetWeights[FeedSource.trending], 10);
    expect(feedSourceTargetWeights[FeedSource.latest], 10);
    expect(feedSourceTargetWeights[FeedSource.club], 5);
    expect(feedSourceTargetWeights[FeedSource.newCreator], 10);
    expect(feedSourceTargetWeights[FeedSource.exploration], 10);

    final discoveryShare =
        feedSourceTargetWeights[FeedSource.recommended]! +
        feedSourceTargetWeights[FeedSource.newCreator]! +
        feedSourceTargetWeights[FeedSource.exploration]!;
    expect(discoveryShare, 50);
  });
}
