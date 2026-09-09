import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/feed_learning_signal.dart';

void main() {
  test('learning signal wire names are bounded and contain no impression', () {
    expect(
      FeedLearningSignal.values.map((signal) => signal.wireName),
      [
        'fast_skip',
        'short_view',
        'qualified_view',
        'long_view',
        'not_interested',
        'follow_from_feed',
      ],
    );
    expect(
      FeedLearningSignal.values.any(
        (signal) => signal.wireName.contains('impression'),
      ),
      isFalse,
    );
  });
}
