import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/home_feed_cursor.dart';

void main() {
  test('cursor round-trips session deduplication identities', () {
    const cursor = HomeFeedCursor(
      userId: 'viewer-1',
      seen: {'drop:a', 'drop:b:quote:q1'},
    );
    final decoded = HomeFeedCursor.decode(
      cursor.encode(),
      expectedUserId: 'viewer-1',
    );
    expect(decoded.seen, cursor.seen);
  });

  test('cursor cannot be continued by another user', () {
    const cursor = HomeFeedCursor(userId: 'viewer-1', seen: {'drop:a'});
    expect(
      () => HomeFeedCursor.decode(
        cursor.encode(),
        expectedUserId: 'viewer-2',
      ),
      throwsFormatException,
    );
  });

  test('malformed cursor fails closed instead of resetting pagination', () {
    expect(
      () => HomeFeedCursor.decode('not-a-cursor', expectedUserId: 'viewer-1'),
      throwsFormatException,
    );
  });
}
