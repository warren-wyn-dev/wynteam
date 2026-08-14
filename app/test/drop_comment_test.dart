import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop_comment.dart';

void main() {
  group('authorNameOrUsername', () {
    test('falls back to @username when authorDisplayName is null', () {
      final comment = DropComment(
        id: 'c1',
        dropId: 'd1',
        authorId: 'u1',
        authorUsername: 'namfah',
        textContent: 'nice',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(comment.authorNameOrUsername, '@namfah');
    });

    test('uses authorDisplayName when set', () {
      final comment = DropComment(
        id: 'c1',
        dropId: 'd1',
        authorId: 'u1',
        authorUsername: 'namfah',
        authorDisplayName: 'Nam Fah',
        textContent: 'nice',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(comment.authorNameOrUsername, 'Nam Fah');
    });
  });

  test('DropComment.fromMap parses embedded author fields', () {
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
    });

    expect(comment.authorUsername, 'namfah');
    expect(comment.authorDisplayName, 'Nam Fah');
    expect(comment.textContent, 'nice');
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
    });

    expect(comment.authorUsername, '');
  });
}
