import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/pop/data/pop.dart';

Pop _pop({
  int viewCount = 0,
  int likeCount = 0,
  int commentCount = 0,
  bool likedByMe = false,
  bool savedByMe = false,
}) =>
    Pop(
      id: 'p1',
      authorId: 'u1',
      authorUsername: 'namfah',
      videoUrl: 'https://example.supabase.co/pops/p1.mp4',
      durationSeconds: 15,
      viewCount: viewCount,
      createdAt: DateTime(2026, 1, 1),
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe,
      savedByMe: savedByMe,
    );

void main() {
  group('authorNameOrUsername', () {
    test('falls back to @username when authorDisplayName is null', () {
      expect(_pop().authorNameOrUsername, '@namfah');
    });

    test('uses authorDisplayName when set', () {
      final pop = Pop(
        id: 'p1',
        authorId: 'u1',
        authorUsername: 'namfah',
        authorDisplayName: 'Nam Fah',
        videoUrl: 'https://example.supabase.co/pops/p1.mp4',
        durationSeconds: 15,
        viewCount: 0,
        createdAt: DateTime(2026, 1, 1),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );
      expect(pop.authorNameOrUsername, 'Nam Fah');
    });
  });

  group('toggledLike', () {
    test('liking bumps likeCount and flips likedByMe', () {
      final toggled = _pop(likeCount: 3, likedByMe: false).toggledLike();
      expect(toggled.likedByMe, isTrue);
      expect(toggled.likeCount, 4);
    });

    test('unliking decrements likeCount and flips likedByMe', () {
      final toggled = _pop(likeCount: 3, likedByMe: true).toggledLike();
      expect(toggled.likedByMe, isFalse);
      expect(toggled.likeCount, 2);
    });
  });

  group('toggledSave', () {
    test('flips savedByMe without touching likeCount/likedByMe', () {
      final saved = _pop(likeCount: 5, likedByMe: true).toggledSave();
      expect(saved.savedByMe, isTrue);
      expect(saved.likeCount, 5);
      expect(saved.likedByMe, isTrue);
    });

    test('toggling twice returns to the original state', () {
      final original = _pop(savedByMe: false);
      final roundTrip = original.toggledSave().toggledSave();
      expect(roundTrip.savedByMe, original.savedByMe);
    });
  });

  test('withExtraComment bumps commentCount only', () {
    final pop = _pop(commentCount: 2).withExtraComment();
    expect(pop.commentCount, 3);
  });

  test('withRemovedComment decrements commentCount only', () {
    final pop = _pop(commentCount: 2).withRemovedComment();
    expect(pop.commentCount, 1);
  });

  test('withExtraView bumps viewCount only', () {
    final pop = _pop(viewCount: 10).withExtraView();
    expect(pop.viewCount, 11);
  });

  group('Pop.fromMap', () {
    test(
        'parses embedded author, like/comment counts, view count, '
        'liked/saved state', () {
      final pop = Pop.fromMap({
        'id': 'p1',
        'author_id': 'u1',
        'author': {
          'username': 'namfah',
          'display_name': 'Nam Fah',
          'avatar_url': 'https://example.com/a.jpg',
        },
        'video_url': 'https://example.supabase.co/pops/p1.mp4',
        'thumbnail_url': 'https://example.supabase.co/pops/p1_thumb.jpg',
        'caption': 'hello',
        'duration_seconds': 30,
        'view_count': 42,
        'created_at': '2026-01-01T00:00:00Z',
        'pop_likes': [
          {'count': 5}
        ],
        'pop_comments': [
          {'count': 2}
        ],
      }, likedByMe: true, savedByMe: true);

      expect(pop.authorUsername, 'namfah');
      expect(pop.authorDisplayName, 'Nam Fah');
      expect(pop.thumbnailUrl, 'https://example.supabase.co/pops/p1_thumb.jpg');
      expect(pop.durationSeconds, 30);
      expect(pop.viewCount, 42);
      expect(pop.likeCount, 5);
      expect(pop.commentCount, 2);
      expect(pop.likedByMe, isTrue);
      expect(pop.savedByMe, isTrue);
    });

    test('treats a missing embedded count list as zero', () {
      final pop = Pop.fromMap({
        'id': 'p1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'video_url': 'https://example.supabase.co/pops/p1.mp4',
        'thumbnail_url': null,
        'caption': null,
        'duration_seconds': 15,
        'view_count': 0,
        'created_at': '2026-01-01T00:00:00Z',
        'pop_likes': <dynamic>[],
        'pop_comments': null,
      }, likedByMe: false, savedByMe: false);

      expect(pop.likeCount, 0);
      expect(pop.commentCount, 0);
    });

    test('view_count arriving as a non-int num still parses', () {
      // Postgres bigint can come back over the wire in a form that isn't
      // a plain Dart int -- guard against that instead of assuming int.
      final pop = Pop.fromMap({
        'id': 'p1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'video_url': 'https://example.supabase.co/pops/p1.mp4',
        'thumbnail_url': null,
        'caption': null,
        'duration_seconds': 15,
        'view_count': 42.0,
        'created_at': '2026-01-01T00:00:00Z',
        'pop_likes': <dynamic>[],
        'pop_comments': <dynamic>[],
      }, likedByMe: false, savedByMe: false);

      expect(pop.viewCount, 42);
    });
  });
}
