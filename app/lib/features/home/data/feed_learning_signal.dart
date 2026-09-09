enum FeedLearningSignal {
  fastSkip('fast_skip'),
  shortView('short_view'),
  qualifiedView('qualified_view'),
  longView('long_view'),
  notInterested('not_interested'),
  followFromFeed('follow_from_feed');

  const FeedLearningSignal(this.wireName);
  final String wireName;
}

enum FeedLearningTarget {
  drop('drop'),
  profile('profile');

  const FeedLearningTarget(this.wireName);
  final String wireName;
}
