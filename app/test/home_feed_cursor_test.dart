import 'dart:convert';

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

  test('cursor encoding refuses to silently truncate seen identities', () {
    final cursor = HomeFeedCursor(
      userId: 'viewer-1',
      seen: {
        for (var i = 0; i <= HomeFeedCursor.maxSeen; i++) 'drop:$i',
      },
    );

    expect(cursor.encode, throwsStateError);
  });

  test('cursor rejects duplicate identities', () {
    final encoded = base64Url.encode(utf8.encode(jsonEncode({
      'v': 1,
      'u': 'viewer-1',
      's': ['drop:a', 'drop:a'],
    })));

    expect(
      () => HomeFeedCursor.decode(encoded, expectedUserId: 'viewer-1'),
      throwsFormatException,
    );
  });

  test('cursor rejects unbounded encoded input before JSON decoding', () {
    final oversized = 'a' * (HomeFeedCursor.maxEncodedLength + 1);

    expect(
      () => HomeFeedCursor.decode(oversized, expectedUserId: 'viewer-1'),
      throwsFormatException,
    );
  });
}
