import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/feed/data/post.dart';

Post _post({
  String? textContent = 'hello',
  int likeCount = 0,
  int commentCount = 0,
  bool likedByMe = false,
}) =>
    Post(
      id: 'p1',
      authorId: 'u1',
      authorUsername: 'namfah',
      createdAt: DateTime(2026, 1, 1),
      textContent: textContent,
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe,
    );

void main() {
  group('authorNameOrUsername', () {
    test('falls back to @username when authorDisplayName is null', () {
      expect(_post().authorNameOrUsername, '@namfah');
    });

    test('uses authorDisplayName when set', () {
      final post = Post(
        id: 'p1',
        authorId: 'u1',
        authorUsername: 'namfah',
        authorDisplayName: 'Nam Fah',
        createdAt: DateTime(2026, 1, 1),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
      );
      expect(post.authorNameOrUsername, 'Nam Fah');
    });
  });

  group('toggledLike', () {
    test('liking bumps likeCount and flips likedByMe', () {
      final toggled = _post(likeCount: 3, likedByMe: false).toggledLike();
      expect(toggled.likedByMe, isTrue);
      expect(toggled.likeCount, 4);
    });

    test('unliking decrements likeCount and flips likedByMe', () {
      final toggled = _post(likeCount: 3, likedByMe: true).toggledLike();
      expect(toggled.likedByMe, isFalse);
      expect(toggled.likeCount, 2);
    });
  });

  test('withExtraComment bumps commentCount only', () {
    final post = _post(commentCount: 2).withExtraComment();
    expect(post.commentCount, 3);
  });

  group('Post.fromMap', () {
    test('parses embedded author, like/comment counts, and likedByMe', () {
      final post = Post.fromMap({
        'id': 'p1',
        'author_id': 'u1',
        'author': {
          'username': 'namfah',
          'display_name': 'Nam Fah',
          'avatar_url': 'https://example.com/a.jpg',
        },
        'text_content': 'hello',
        'image_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'likes': [
          {'count': 5}
        ],
        'comments': [
          {'count': 2}
        ],
      }, likedByMe: true);

      expect(post.authorUsername, 'namfah');
      expect(post.authorDisplayName, 'Nam Fah');
      expect(post.likeCount, 5);
      expect(post.commentCount, 2);
      expect(post.likedByMe, isTrue);
    });

    test('treats a missing embedded count list as zero', () {
      final post = Post.fromMap({
        'id': 'p1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'text_content': 'hello',
        'image_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'likes': <dynamic>[],
        'comments': null,
      }, likedByMe: false);

      expect(post.likeCount, 0);
      expect(post.commentCount, 0);
    });
  });
}
