import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';

Drop _drop({
  int likeCount = 0,
  int commentCount = 0,
  bool likedByMe = false,
  bool savedByMe = false,
}) =>
    Drop(
      id: 'd1',
      authorId: 'u1',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d1.jpg',
      createdAt: DateTime(2026, 1, 1),
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe,
      savedByMe: savedByMe,
    );

void main() {
  group('authorNameOrUsername', () {
    test('falls back to @username when authorDisplayName is null', () {
      expect(_drop().authorNameOrUsername, '@namfah');
    });

    test('uses authorDisplayName when set', () {
      final drop = Drop(
        id: 'd1',
        authorId: 'u1',
        authorUsername: 'namfah',
        authorDisplayName: 'Nam Fah',
        imageUrl: 'https://example.supabase.co/drops/d1.jpg',
        createdAt: DateTime(2026, 1, 1),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );
      expect(drop.authorNameOrUsername, 'Nam Fah');
    });
  });

  group('toggledLike', () {
    test('liking bumps likeCount and flips likedByMe', () {
      final toggled = _drop(likeCount: 3, likedByMe: false).toggledLike();
      expect(toggled.likedByMe, isTrue);
      expect(toggled.likeCount, 4);
    });

    test('unliking decrements likeCount and flips likedByMe', () {
      final toggled = _drop(likeCount: 3, likedByMe: true).toggledLike();
      expect(toggled.likedByMe, isFalse);
      expect(toggled.likeCount, 2);
    });
  });

  group('toggledSave', () {
    test('flips savedByMe without touching likeCount/likedByMe', () {
      final saved = _drop(likeCount: 5, likedByMe: true).toggledSave();
      expect(saved.savedByMe, isTrue);
      expect(saved.likeCount, 5);
      expect(saved.likedByMe, isTrue);
    });

    test('toggling twice returns to the original state', () {
      final original = _drop(savedByMe: false);
      final roundTrip = original.toggledSave().toggledSave();
      expect(roundTrip.savedByMe, original.savedByMe);
    });
  });

  test('withExtraComment bumps commentCount only', () {
    final drop = _drop(commentCount: 2).withExtraComment();
    expect(drop.commentCount, 3);
  });

  group('Drop.fromMap', () {
    test('parses embedded author, like/comment counts, liked/saved state', () {
      final drop = Drop.fromMap({
        'id': 'd1',
        'author_id': 'u1',
        'author': {
          'username': 'namfah',
          'display_name': 'Nam Fah',
          'avatar_url': 'https://example.com/a.jpg',
        },
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'caption': 'hello',
        'created_at': '2026-01-01T00:00:00Z',
        'drop_likes': [
          {'count': 5}
        ],
        'drop_comments': [
          {'count': 2}
        ],
      }, likedByMe: true, savedByMe: true);

      expect(drop.authorUsername, 'namfah');
      expect(drop.authorDisplayName, 'Nam Fah');
      expect(drop.likeCount, 5);
      expect(drop.commentCount, 2);
      expect(drop.likedByMe, isTrue);
      expect(drop.savedByMe, isTrue);
    });

    test('treats a missing embedded count list as zero', () {
      final drop = Drop.fromMap({
        'id': 'd1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'caption': null,
        'created_at': '2026-01-01T00:00:00Z',
        'drop_likes': <dynamic>[],
        'drop_comments': null,
      }, likedByMe: false, savedByMe: false);

      expect(drop.likeCount, 0);
      expect(drop.commentCount, 0);
    });
  });
}
