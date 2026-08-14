import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/pop/data/pop_comment.dart';

PopComment _comment({
  String? authorDisplayName,
  int likeCount = 0,
  bool likedByMe = false,
}) =>
    PopComment(
      id: 'c1',
      popId: 'p1',
      authorId: 'u1',
      authorUsername: 'namfah',
      authorDisplayName: authorDisplayName,
      textContent: 'nice',
      createdAt: DateTime(2026, 1, 1),
      likeCount: likeCount,
      likedByMe: likedByMe,
    );

void main() {
  group('authorNameOrUsername', () {
    test('falls back to @username when authorDisplayName is null', () {
      expect(_comment().authorNameOrUsername, '@namfah');
    });

    test('uses authorDisplayName when set', () {
      expect(_comment(authorDisplayName: 'Nam Fah').authorNameOrUsername,
          'Nam Fah');
    });
  });

  group('toggledLike', () {
    test('liking bumps likeCount and flips likedByMe', () {
      final toggled = _comment(likeCount: 2, likedByMe: false).toggledLike();
      expect(toggled.likedByMe, isTrue);
      expect(toggled.likeCount, 3);
    });

    test('unliking decrements likeCount and flips likedByMe', () {
      final toggled = _comment(likeCount: 2, likedByMe: true).toggledLike();
      expect(toggled.likedByMe, isFalse);
      expect(toggled.likeCount, 1);
    });
  });

  test('PopComment.fromMap parses embedded author fields and like count', () {
    final comment = PopComment.fromMap({
      'id': 'c1',
      'pop_id': 'p1',
      'author_id': 'u1',
      'author': {
        'username': 'namfah',
        'display_name': 'Nam Fah',
        'avatar_url': 'https://example.com/a.jpg',
      },
      'text_content': 'nice',
      'created_at': '2026-01-01T00:00:00Z',
      'pop_comment_likes': [
        {'count': 4}
      ],
    }, likedByMe: true);

    expect(comment.authorUsername, 'namfah');
    expect(comment.authorDisplayName, 'Nam Fah');
    expect(comment.textContent, 'nice');
    expect(comment.likeCount, 4);
    expect(comment.likedByMe, isTrue);
  });

  test('PopComment.fromMap treats a missing embedded count list as zero', () {
    final comment = PopComment.fromMap({
      'id': 'c1',
      'pop_id': 'p1',
      'author_id': 'u1',
      'author': {'username': 'namfah'},
      'text_content': 'nice',
      'created_at': '2026-01-01T00:00:00Z',
      'pop_comment_likes': <dynamic>[],
    }, likedByMe: false);

    expect(comment.likeCount, 0);
  });

  test(
      'PopComment.fromMap defaults authorUsername to empty when author is '
      'null', () {
    final comment = PopComment.fromMap({
      'id': 'c1',
      'pop_id': 'p1',
      'author_id': 'u1',
      'author': null,
      'text_content': 'nice',
      'created_at': '2026-01-01T00:00:00Z',
      'pop_comment_likes': <dynamic>[],
    }, likedByMe: false);

    expect(comment.authorUsername, '');
  });
}
