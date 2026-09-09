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
///
/// For You should feel meaningfully different from a Following feed. The
/// previous mix devoted 35% of slots to followed creators but only 20% to the
/// personalized Recommended pool and 5% to Exploration. That made a mature
/// personalized feed lean too heavily toward accounts the viewer had already
/// chosen. This mix keeps Following as the largest relationship source while
/// giving recommendation/discovery sources half of the available slots:
/// Recommended 30% + New Creator 10% + Exploration 10% = 50%.
///
/// This is an explicit starting allocation, not a claim of data-derived
/// optimality. The backend still ranks every pool by quality, affinity,
/// engagement, trend and recency; these percentages only decide how those
/// independently-ranked pools are interleaved.
const feedSourceTargetWeights = <FeedSource, int>{
  FeedSource.following: 25,
  FeedSource.recommended: 30,
  FeedSource.trending: 10,
  FeedSource.latest: 10,
  FeedSource.club: 5,
  FeedSource.newCreator: 10,
  FeedSource.exploration: 10,
};

const feedFallbackPriority = <FeedSource>[
  FeedSource.recommended,
  FeedSource.following,
  FeedSource.latest,
  FeedSource.exploration,
];
