import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/data/home_ranking.dart';

HomeFeedItem _item({
  DateTime? createdAt,
  int likeCount = 0,
  int commentCount = 0,
}) =>
    HomeFeedItem(
      id: 'i1',
      contentType: HomeContentType.drop,
      authorId: 'author-1',
      authorUsername: 'namfah',
      createdAt: createdAt ?? DateTime(2026, 1, 8, 12), // fixed "now" reference below
      imageUrl: 'https://example.supabase.co/drops/i1.jpg',
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: false,
      savedByMe: false,
    );

final _now = DateTime(2026, 1, 8, 12);

void main() {
  group('rankingScore (WYN-018)', () {
    test('a brand-new post with zero engagement scores exactly its recency term '
        '(168) plus no boost', () {
      final item = _item(createdAt: _now);
      expect(
        rankingScore(item, now: _now, isFollowingAuthor: false),
        168,
      );
    });

    test('recency decays linearly, exactly 1 point per hour', () {
      final item = _item(createdAt: _now.subtract(const Duration(hours: 10)));
      expect(
        rankingScore(item, now: _now, isFollowingAuthor: false),
        158, // 168 - 10
      );
    });

    test('recency floors at 0 once the post is older than 168 hours (7 days), '
        'never goes negative', () {
      final item = _item(createdAt: _now.subtract(const Duration(days: 30)));
      expect(
        rankingScore(item, now: _now, isFollowingAuthor: false),
        0,
      );
    });

    test('each like adds exactly 2 to the score', () {
      final item = _item(createdAt: _now, likeCount: 5);
      expect(
        rankingScore(item, now: _now, isFollowingAuthor: false),
        168 + 5 * 2,
      );
    });

    test('each comment adds exactly 3 to the score -- weighted higher than a like',
        () {
      final item = _item(createdAt: _now, commentCount: 5);
      expect(
        rankingScore(item, now: _now, isFollowingAuthor: false),
        168 + 5 * 3,
      );
    });

    test('following the author adds a flat 50-point boost', () {
      final item = _item(createdAt: _now);
      expect(
        rankingScore(item, now: _now, isFollowingAuthor: true),
        168 + 50,
      );
    });

    test('all three terms combine additively', () {
      final item = _item(
        createdAt: _now.subtract(const Duration(hours: 20)),
        likeCount: 3,
        commentCount: 2,
      );
      // recency: 168 - 20 = 148; engagement: 3*2 + 2*3 = 12; boost: 50
      expect(
        rankingScore(item, now: _now, isFollowingAuthor: true),
        148 + 12 + 50,
      );
    });

    test('a followed author with an old post can still outrank an unfollowed '
        'author\'s brand-new post if engagement is high enough', () {
      final oldButFollowed = _item(
        createdAt: _now.subtract(const Duration(hours: 100)),
        likeCount: 20,
        commentCount: 10,
      );
      final newButUnfollowed = _item(createdAt: _now);

      final scoreA = rankingScore(oldButFollowed, now: _now, isFollowingAuthor: true);
      final scoreB = rankingScore(newButUnfollowed, now: _now, isFollowingAuthor: false);

      // oldButFollowed: (168-100) + (20*2+10*3) + 50 = 68 + 70 + 50 = 188
      // newButUnfollowed: 168 + 0 + 0 = 168
      expect(scoreA, 188);
      expect(scoreB, 168);
      expect(scoreA, greaterThan(scoreB));
    });
  });
}
