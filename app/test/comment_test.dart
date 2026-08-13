import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/feed/data/comment.dart';

void main() {
  group('authorNameOrUsername', () {
    test('falls back to @username when authorDisplayName is null', () {
      final comment = Comment(
        id: 'c1',
        postId: 'p1',
        authorId: 'u1',
        authorUsername: 'namfah',
        textContent: 'nice post',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(comment.authorNameOrUsername, '@namfah');
    });

    test('uses authorDisplayName when set', () {
      final comment = Comment(
        id: 'c1',
        postId: 'p1',
        authorId: 'u1',
        authorUsername: 'namfah',
        authorDisplayName: 'Nam Fah',
        textContent: 'nice post',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(comment.authorNameOrUsername, 'Nam Fah');
    });
  });

  test('Comment.fromMap parses embedded author fields', () {
    final comment = Comment.fromMap({
      'id': 'c1',
      'post_id': 'p1',
      'author_id': 'u1',
      'author': {
        'username': 'namfah',
        'display_name': 'Nam Fah',
        'avatar_url': 'https://example.com/a.jpg',
      },
      'text_content': 'nice post',
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(comment.authorUsername, 'namfah');
    expect(comment.authorDisplayName, 'Nam Fah');
    expect(comment.authorAvatarUrl, 'https://example.com/a.jpg');
    expect(comment.textContent, 'nice post');
  });

  test('Comment.fromMap defaults authorUsername to empty when author is null',
      () {
    final comment = Comment.fromMap({
      'id': 'c1',
      'post_id': 'p1',
      'author_id': 'u1',
      'author': null,
      'text_content': 'nice post',
      'created_at': '2026-01-01T00:00:00Z',
    });

    expect(comment.authorUsername, '');
    expect(comment.authorDisplayName, isNull);
  });
}
