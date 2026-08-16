import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club_post_comment.dart';

void main() {
  group('authorNameOrUsername', () {
    test('falls back to @username when authorDisplayName is null', () {
      final comment = ClubPostComment(
        id: 'c1',
        clubPostId: 'cp1',
        authorId: 'u1',
        authorUsername: 'namfah',
        textContent: 'nice',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(comment.authorNameOrUsername, '@namfah');
    });
  });

  group('parentCommentId (WYN-022)', () {
    test('ClubPostComment.fromMap parses a null parent_comment_id as a top-level comment',
        () {
      final comment = ClubPostComment.fromMap({
        'id': 'c1',
        'club_post_id': 'cp1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'text_content': 'nice',
        'created_at': '2026-01-01T00:00:00Z',
        'parent_comment_id': null,
      });

      expect(comment.parentCommentId, isNull);
    });

    test('ClubPostComment.fromMap parses a set parent_comment_id as a reply', () {
      final comment = ClubPostComment.fromMap({
        'id': 'c2',
        'club_post_id': 'cp1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'text_content': 'a reply',
        'created_at': '2026-01-01T00:00:00Z',
        'parent_comment_id': 'c1',
      });

      expect(comment.parentCommentId, 'c1');
    });
  });
}
