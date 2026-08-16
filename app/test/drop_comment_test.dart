import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop_comment.dart';

DropComment _comment({
  String? authorDisplayName,
  int likeCount = 0,
  bool likedByMe = false,
  String? parentCommentId,
}) =>
    DropComment(
      id: 'c1',
      dropId: 'd1',
      authorId: 'u1',
      authorUsername: 'namfah',
      authorDisplayName: authorDisplayName,
      textContent: 'nice',
      createdAt: DateTime(2026, 1, 1),
      likeCount: likeCount,
      likedByMe: likedByMe,
      parentCommentId: parentCommentId,
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

  test('DropComment.fromMap parses embedded author fields and like count', () {
    final comment = DropComment.fromMap({
      'id': 'c1',
      'drop_id': 'd1',
      'author_id': 'u1',
      'author': {
        'username': 'namfah',
        'display_name': 'Nam Fah',
        'avatar_url': 'https://example.com/a.jpg',
      },
      'text_content': 'nice',
      'created_at': '2026-01-01T00:00:00Z',
      'drop_comment_likes': [
        {'count': 4}
      ],
    }, likedByMe: true);

    expect(comment.authorUsername, 'namfah');
    expect(comment.authorDisplayName, 'Nam Fah');
    expect(comment.textContent, 'nice');
    expect(comment.likeCount, 4);
    expect(comment.likedByMe, isTrue);
  });

  test('DropComment.fromMap treats a missing embedded count list as zero',
      () {
    final comment = DropComment.fromMap({
      'id': 'c1',
      'drop_id': 'd1',
      'author_id': 'u1',
      'author': {'username': 'namfah'},
      'text_content': 'nice',
      'created_at': '2026-01-01T00:00:00Z',
      'drop_comment_likes': <dynamic>[],
    }, likedByMe: false);

    expect(comment.likeCount, 0);
  });

  test('DropComment.fromMap defaults authorUsername to empty when author is null',
      () {
    final comment = DropComment.fromMap({
      'id': 'c1',
      'drop_id': 'd1',
      'author_id': 'u1',
      'author': null,
      'text_content': 'nice',
      'created_at': '2026-01-01T00:00:00Z',
      'drop_comment_likes': <dynamic>[],
    }, likedByMe: false);

    expect(comment.authorUsername, '');
  });

  group('parentCommentId (WYN-022)', () {
    test('DropComment.fromMap parses a null parent_comment_id as a top-level comment',
        () {
      final comment = DropComment.fromMap({
        'id': 'c1',
        'drop_id': 'd1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'text_content': 'nice',
        'created_at': '2026-01-01T00:00:00Z',
        'drop_comment_likes': <dynamic>[],
        'parent_comment_id': null,
      }, likedByMe: false);

      expect(comment.parentCommentId, isNull);
    });

    test('DropComment.fromMap parses a set parent_comment_id as a reply', () {
      final comment = DropComment.fromMap({
        'id': 'c2',
        'drop_id': 'd1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'text_content': 'a reply',
        'created_at': '2026-01-01T00:00:00Z',
        'drop_comment_likes': <dynamic>[],
        'parent_comment_id': 'c1',
      }, likedByMe: false);

      expect(comment.parentCommentId, 'c1');
    });

    test('copyWith preserves parentCommentId', () {
      final reply = _comment(parentCommentId: 'c1').copyWith(likeCount: 1);
      expect(reply.parentCommentId, 'c1');
    });
  });
}
