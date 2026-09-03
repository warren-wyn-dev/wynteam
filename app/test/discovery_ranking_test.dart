import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/search/data/discovery_ranking.dart';

/// A minimal HomeFeedItem fixture -- only the fields rankTrendingHashtags
/// (WYN-101) actually reads (caption, createdAt, likeCount, commentCount,
/// redropCount, viewCount) need real values; the rest take arbitrary
/// placeholders.
HomeFeedItem _item({
  required String id,
  String? caption,
  required DateTime createdAt,
  int likeCount = 0,
  int commentCount = 0,
  int redropCount = 0,
  int? viewCount,
}) {
  return HomeFeedItem(
    id: id,
    contentType: HomeContentType.drop,
    authorId: 'author-$id',
    authorUsername: 'author$id',
    createdAt: createdAt,
    caption: caption,
    likeCount: likeCount,
    commentCount: commentCount,
    redropCount: redropCount,
    viewCount: viewCount,
    likedByMe: false,
    savedByMe: false,
  );
}

void main() {
  final now = DateTime(2026, 9, 2, 12, 0, 0);

  group('rankTrendingHashtags (WYN-101 -- engagement-weighted + '
      'time-decay, not raw post frequency)', () {
    test('ranks tags by accumulated engagement score, highest first', () {
      final items = [
        // #wyn: 2 posts, modest engagement each.
        _item(
          id: '1',
          caption: 'สวัสดี #wyn',
          createdAt: now.subtract(const Duration(hours: 1)),
          likeCount: 5,
        ),
        _item(
          id: '2',
          caption: 'อีกโพสต์ #wyn',
          createdAt: now.subtract(const Duration(hours: 1)),
          likeCount: 5,
        ),
        // #flutter: 1 post, but far higher engagement -- must still
        // outrank #wyn's 2-post total, unlike the old raw-frequency
        // count that would have ranked #wyn first (more posts).
        _item(
          id: '3',
          caption: 'ลอง #flutter',
          createdAt: now.subtract(const Duration(hours: 1)),
          likeCount: 500,
          commentCount: 200,
          redropCount: 100,
        ),
      ];

      final ranked = rankTrendingHashtags(items, limit: 10, now: now);

      expect(ranked, hasLength(2));
      expect(ranked[0].tag, 'flutter');
      expect(ranked[1].tag, 'wyn');
    });

    test(
        'a new post going viral right now outranks an older post with '
        'more accumulated engagement (time-decay)', () {
      final items = [
        // Old, decayed: high engagement, but posted 30 days ago.
        _item(
          id: 'old',
          caption: '#เก่าแต่เยอะ',
          createdAt: now.subtract(const Duration(days: 30)),
          likeCount: 1000,
          commentCount: 500,
          redropCount: 200,
        ),
        // New, viral: modest engagement, but posted 10 minutes ago.
        _item(
          id: 'new',
          caption: '#ใหม่ไวรัล',
          createdAt: now.subtract(const Duration(minutes: 10)),
          likeCount: 50,
          commentCount: 30,
          redropCount: 20,
        ),
      ];

      final ranked = rankTrendingHashtags(items, limit: 10, now: now);

      expect(ranked[0].tag, 'ใหม่ไวรัล');
      expect(ranked[1].tag, 'เก่าแต่เยอะ');
    });

    test(
        'the same interaction count weighs more when it is comments or '
        'reposts than when it is plain likes', () {
      // 10 interactions each, same age -- only the *type* differs, so
      // any ranking difference can only come from the weight formula.
      final items = [
        _item(id: '1', caption: '#likes', createdAt: now, likeCount: 10),
        _item(id: '2', caption: '#comments', createdAt: now, commentCount: 10),
        _item(id: '3', caption: '#reposts', createdAt: now, redropCount: 10),
      ];

      final ranked = rankTrendingHashtags(items, limit: 10, now: now);

      expect(ranked.map((r) => r.tag).toList(), ['reposts', 'comments', 'likes']);
    });

    test('a null viewCount counts as 0, not a crash', () {
      final items = [
        _item(id: '1', caption: '#wyn', createdAt: now, likeCount: 1),
      ];

      expect(() => rankTrendingHashtags(items, limit: 10, now: now),
          returnsNormally);
    });

    test('a post created this instant does not divide by zero', () {
      final items = [
        _item(id: '1', caption: '#wyn', createdAt: now, likeCount: 1),
      ];

      final ranked = rankTrendingHashtags(items, limit: 10, now: now);

      expect(ranked.single.score.isFinite, isTrue);
      expect(ranked.single.score, greaterThan(0));
    });

    test('a post with multiple hashtags contributes its full score to '
        'each one (not divided across tags)', () {
      final items = [
        _item(
          id: '1',
          caption: 'ลอง #wyn กับ #flutter',
          createdAt: now,
          likeCount: 10,
        ),
      ];

      final ranked = rankTrendingHashtags(items, limit: 10, now: now);

      expect(ranked, hasLength(2));
      expect(ranked[0].score, ranked[1].score);
    });

    test('tags mentioned within one caption still count as 1 post for '
        'postCount, not once per occurrence', () {
      final items = [
        _item(
          id: '1',
          caption: 'สวัสดี #wyn วันนี้อากาศดี #wyn',
          createdAt: now,
          likeCount: 5,
        ),
      ];

      final ranked = rankTrendingHashtags(items, limit: 10, now: now);

      expect(ranked.single.postCount, 1);
    });

    test('ties on score break deterministically by higher postCount', () {
      final items = [
        // Same total engagement/age -> same score, but #many has 2
        // contributing posts vs #few's 1.
        _item(
          id: '1',
          caption: '#many',
          createdAt: now,
          likeCount: 10,
        ),
        _item(
          id: '2',
          caption: '#many',
          createdAt: now,
          likeCount: 10,
        ),
        _item(
          id: '3',
          caption: '#few',
          createdAt: now,
          likeCount: 20,
        ),
      ];

      final ranked = rankTrendingHashtags(items, limit: 10, now: now);

      // Both accumulate the same total score (10+10 vs 20, same
      // per-item formula) -- #many wins the tie on postCount (2 vs 1).
      expect(ranked[0].score, ranked[1].score);
      expect(ranked[0].tag, 'many');
      expect(ranked[0].postCount, 2);
      expect(ranked[1].tag, 'few');
      expect(ranked[1].postCount, 1);
    });

    test('caps the result at [limit]', () {
      final items = [
        _item(id: '1', caption: '#a #b #c #d #e', createdAt: now, likeCount: 1),
      ];

      final ranked = rankTrendingHashtags(items, limit: 2, now: now);

      expect(ranked, hasLength(2));
    });

    test('ignores items with a null caption (Pop content with no caption)',
        () {
      final items = [
        _item(id: '1', caption: null, createdAt: now),
        _item(id: '2', caption: '#wyn', createdAt: now, likeCount: 1),
        _item(id: '3', caption: null, createdAt: now),
      ];

      final ranked = rankTrendingHashtags(items, limit: 10, now: now);

      expect(ranked, hasLength(1));
      expect(ranked.single.tag, 'wyn');
    });

    test('an empty candidate list ranks to an empty result, not an error',
        () {
      expect(rankTrendingHashtags(const [], limit: 20, now: now), isEmpty);
    });

    test('a caption with no hashtags contributes nothing', () {
      final items = [
        _item(
          id: '1',
          caption: 'วันนี้อากาศดีมาก ไม่มีแฮชแท็กเลย',
          createdAt: now,
          likeCount: 100,
        ),
      ];

      expect(rankTrendingHashtags(items, limit: 20, now: now), isEmpty);
    });
  });
}
