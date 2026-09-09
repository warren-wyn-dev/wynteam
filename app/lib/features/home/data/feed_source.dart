/// Internal source labels for the WYNOS hybrid Home feed.
///
/// These values are deliberately typed rather than repeated strings. They are
/// safe to use as analytics/reason metadata; scoring weights remain private.
enum FeedSource {
  following('following'),
  recommended('recommended'),
  trending('trending'),
  latest('latest'),
  club('club'),
  newCreator('new_creator'),
  exploration('exploration');

  const FeedSource(this.wireName);
  final String wireName;

  static FeedSource fromWire(String value) => values.firstWhere(
        (source) => source.wireName == value,
        orElse: () => throw FormatException('Unknown feed source: $value'),
      );
}

/// The one authoritative Phase 1 allocation. Allocation belongs in Dart
/// because diversity and pagination/session deduplication already happen in
/// Dart; duplicating these percentages in SQL would let the two layers drift.
const feedSourceTargetWeights = <FeedSource, int>{
  FeedSource.following: 35,
  FeedSource.recommended: 20,
  FeedSource.trending: 10,
  FeedSource.latest: 10,
  FeedSource.club: 10,
  FeedSource.newCreator: 10,
  FeedSource.exploration: 5,
};

const feedFallbackPriority = <FeedSource>[
  FeedSource.recommended,
  FeedSource.following,
  FeedSource.latest,
  FeedSource.exploration,
];
