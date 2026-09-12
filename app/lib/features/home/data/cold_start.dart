import 'feed_source.dart';

enum PersonalizationMaturity {
  zeroHistory('zero_history'),
  sparse('sparse'),
  learning('learning'),
  personalized('personalized');

  const PersonalizationMaturity(this.wireName);
  final String wireName;

  static PersonalizationMaturity fromWire(String? value) => values.firstWhere(
        (state) => state.wireName == value,
        orElse: () => PersonalizationMaturity.zeroHistory,
      );
}

/// Phase 1 owns allocation in Dart, so cold-start redistribution lives beside
/// the normal source weights rather than duplicating it in SQL/UI. Every map
/// totals 100; exhausted pools still use the existing deterministic fallback.
const coldStartSourceWeights = <
    PersonalizationMaturity,
    Map<FeedSource, int>>{
  PersonalizationMaturity.zeroHistory: {
    FeedSource.following: 0,
    FeedSource.recommended: 25,
    FeedSource.trending: 20,
    FeedSource.latest: 20,
    FeedSource.club: 0,
    FeedSource.newCreator: 20,
    FeedSource.exploration: 15,
  },
  PersonalizationMaturity.sparse: {
    FeedSource.following: 15,
    FeedSource.recommended: 25,
    FeedSource.trending: 15,
    FeedSource.latest: 15,
    FeedSource.club: 5,
    FeedSource.newCreator: 15,
    FeedSource.exploration: 10,
  },
  PersonalizationMaturity.learning: {
    FeedSource.following: 25,
    FeedSource.recommended: 25,
    FeedSource.trending: 10,
    FeedSource.latest: 15,
    FeedSource.club: 10,
    FeedSource.newCreator: 10,
    FeedSource.exploration: 5,
  },
  PersonalizationMaturity.personalized: feedSourceTargetWeights,
};
