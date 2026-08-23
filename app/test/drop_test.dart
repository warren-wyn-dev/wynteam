import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';

Drop _drop({
  int likeCount = 0,
  int commentCount = 0,
  bool likedByMe = false,
  bool savedByMe = false,
  int redropCount = 0,
  bool redroppedByMe = false,
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
      redropCount: redropCount,
      redroppedByMe: redroppedByMe,
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

  test('withRemovedComment decrements commentCount only', () {
    final drop = _drop(commentCount: 2).withRemovedComment();
    expect(drop.commentCount, 1);
  });

  group('toggledRedrop (WYN-034)', () {
    test('ReDropping bumps redropCount and flips redroppedByMe', () {
      final toggled = _drop(redropCount: 2, redroppedByMe: false).toggledRedrop();
      expect(toggled.redroppedByMe, isTrue);
      expect(toggled.redropCount, 3);
    });

    test('un-ReDropping decrements redropCount and flips redroppedByMe', () {
      final toggled = _drop(redropCount: 2, redroppedByMe: true).toggledRedrop();
      expect(toggled.redroppedByMe, isFalse);
      expect(toggled.redropCount, 1);
    });

    test('does not touch likeCount/likedByMe/savedByMe', () {
      final toggled =
          _drop(likeCount: 5, likedByMe: true, savedByMe: true).toggledRedrop();
      expect(toggled.likeCount, 5);
      expect(toggled.likedByMe, isTrue);
      expect(toggled.savedByMe, isTrue);
    });
  });

  group('votedPoll (WYN-035)', () {
    Drop pollDrop({
      List<String> options = const ['Pizza', 'Sushi', 'Burger'],
      int? myVoteIndex,
      int? totalVotes,
      List<int>? optionCounts,
    }) =>
        Drop(
          id: 'd1',
          authorId: 'u1',
          authorUsername: 'namfah',
          createdAt: DateTime(2026, 1, 1),
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          savedByMe: false,
          pollId: 'p1',
          pollOptions: options,
          pollExpiresAt: DateTime.now().toUtc().add(const Duration(days: 3)),
          pollMyVoteIndex: myVoteIndex,
          pollTotalVotes: totalVotes,
          pollOptionCounts: optionCounts,
        );

    test('first-time vote sets myVoteIndex, seeds zeroed counts, and '
        'increments the chosen option + total', () {
      final voted = pollDrop().votedPoll(1);
      expect(voted.pollMyVoteIndex, 1);
      expect(voted.pollTotalVotes, 1);
      expect(voted.pollOptionCounts, [0, 1, 0]);
    });

    test('changing an existing vote moves the count without changing '
        'the total', () {
      final voted = pollDrop(
        myVoteIndex: 0,
        totalVotes: 3,
        optionCounts: [1, 2, 0],
      ).votedPoll(2);

      expect(voted.pollMyVoteIndex, 2);
      expect(voted.pollTotalVotes, 3);
      expect(voted.pollOptionCounts, [0, 2, 1]);
    });

    test('isPoll/pollResultsVisible/pollIsClosed reflect the fields '
        'they derive from', () {
      final open = pollDrop(totalVotes: 2, optionCounts: [1, 1, 0]);
      expect(open.isPoll, isTrue);
      expect(open.pollResultsVisible, isTrue);
      expect(open.pollIsClosed, isFalse);

      final hiddenResults = pollDrop();
      expect(hiddenResults.pollResultsVisible, isFalse);

      final noPoll = Drop(
        id: 'd2',
        authorId: 'u1',
        authorUsername: 'namfah',
        imageUrl: 'https://example.supabase.co/drops/d2.jpg',
        createdAt: DateTime(2026, 1, 1),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );
      expect(noPoll.isPoll, isFalse);
    });
  });

  test('withExtraRedrop bumps redropCount only, without touching '
      'redroppedByMe', () {
    final drop = _drop(redropCount: 1, redroppedByMe: false).withExtraRedrop();
    expect(drop.redropCount, 2);
    expect(drop.redroppedByMe, isFalse);
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

    test('parses embedded redrops count and redroppedByMe (WYN-034)', () {
      final drop = Drop.fromMap({
        'id': 'd1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'caption': null,
        'created_at': '2026-01-01T00:00:00Z',
        'drop_likes': <dynamic>[],
        'drop_comments': <dynamic>[],
        'redrops': [
          {'count': 4}
        ],
      }, likedByMe: false, savedByMe: false, redroppedByMe: true);

      expect(drop.redropCount, 4);
      expect(drop.redroppedByMe, isTrue);
    });

    test('redropCount defaults to 0 when the redrops embed is missing', () {
      final drop = Drop.fromMap({
        'id': 'd1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'caption': null,
        'created_at': '2026-01-01T00:00:00Z',
        'drop_likes': <dynamic>[],
        'drop_comments': <dynamic>[],
      }, likedByMe: false, savedByMe: false);

      expect(drop.redropCount, 0);
      expect(drop.redroppedByMe, isFalse);
    });

    test('parses a nested drop_polls embed and per-viewer poll state '
        '(WYN-035)', () {
      final drop = Drop.fromMap({
        'id': 'd1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'image_url': null,
        'caption': 'กินอะไรดี?',
        'created_at': '2026-01-01T00:00:00Z',
        'drop_likes': <dynamic>[],
        'drop_comments': <dynamic>[],
        'drop_polls': {
          'id': 'p1',
          'options': ['Pizza', 'Sushi'],
          'expires_at': '2026-01-04T00:00:00Z',
        },
      },
          likedByMe: false,
          savedByMe: false,
          pollMyVoteIndex: 0,
          pollTotalVotes: 5,
          pollOptionCounts: [3, 2]);

      expect(drop.imageUrl, isNull);
      expect(drop.isPoll, isTrue);
      expect(drop.pollId, 'p1');
      expect(drop.pollOptions, ['Pizza', 'Sushi']);
      expect(drop.pollExpiresAt, DateTime.parse('2026-01-04T00:00:00Z'));
      expect(drop.pollMyVoteIndex, 0);
      expect(drop.pollTotalVotes, 5);
      expect(drop.pollOptionCounts, [3, 2]);
    });

    test('a single-element drop_polls list (defensive PostgREST shape) '
        'parses the same as a bare object', () {
      final drop = Drop.fromMap({
        'id': 'd1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'image_url': null,
        'caption': 'poll?',
        'created_at': '2026-01-01T00:00:00Z',
        'drop_likes': <dynamic>[],
        'drop_comments': <dynamic>[],
        'drop_polls': [
          {
            'id': 'p1',
            'options': ['Yes', 'No'],
            'expires_at': '2026-01-04T00:00:00Z',
          }
        ],
      }, likedByMe: false, savedByMe: false);

      expect(drop.pollId, 'p1');
    });

    test('a Drop with no poll leaves every poll field null', () {
      final drop = Drop.fromMap({
        'id': 'd1',
        'author_id': 'u1',
        'author': {'username': 'namfah'},
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'caption': null,
        'created_at': '2026-01-01T00:00:00Z',
        'drop_likes': <dynamic>[],
        'drop_comments': <dynamic>[],
      }, likedByMe: false, savedByMe: false);

      expect(drop.isPoll, isFalse);
      expect(drop.pollOptions, isNull);
      expect(drop.pollExpiresAt, isNull);
    });
  });
}
