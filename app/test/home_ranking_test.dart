import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/data/home_ranking.dart';

HomeFeedItem _item({
  DateTime? createdAt,
  int likeCount = 0,
  int commentCount = 0,
  HomeContentType contentType = HomeContentType.drop,
  int? viewCount,
}) =>
    HomeFeedItem(
      id: 'i1',
      contentType: contentType,
      authorId: 'author-1',
      authorUsername: 'namfah',
      createdAt:
          createdAt ?? DateTime(2026, 1, 8, 12), // fixed "now" reference below
      imageUrl: 'https://example.supabase.co/drops/i1.jpg',
      likeCount: likeCount,
      commentCount: commentCount,
      viewCount: viewCount,
      likedByMe: false,
      savedByMe: false,
    );

final _now = DateTime(2026, 1, 8, 12);

void main() {
  group('rankingScore (WYN-018)', () {
    test(
        'a brand-new post with zero engagement scores exactly its recency term '
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

    test(
        'recency floors at 0 once the post is older than 168 hours (7 days), '
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

    test(
        'each comment adds exactly 3 to the score -- weighted higher than a like',
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

    test(
        'a followed author with an old post can still outrank an unfollowed '
        'author\'s brand-new post if engagement is high enough', () {
      final oldButFollowed = _item(
        createdAt: _now.subtract(const Duration(hours: 100)),
        likeCount: 20,
        commentCount: 10,
      );
      final newButUnfollowed = _item(createdAt: _now);

      final scoreA =
          rankingScore(oldButFollowed, now: _now, isFollowingAuthor: true);
      final scoreB =
          rankingScore(newButUnfollowed, now: _now, isFollowingAuthor: false);

      // oldButFollowed: (168-100) + (20*2+10*3) + 50 = 68 + 70 + 50 = 188
      // newButUnfollowed: 168 + 0 + 0 = 168
      expect(scoreA, 188);
      expect(scoreB, 168);
      expect(scoreA, greaterThan(scoreB));
    });
  });

  group('engagementScore (WYN-041)', () {
    test(
        'a Drop with zero views scores exactly its like/comment terms, no '
        'view contribution', () {
      final item = _item(likeCount: 5, commentCount: 2, viewCount: 0);
      expect(engagementScore(item), 5 * 2 + 2 * 3);
    });

    test('a Drop\'s viewCount adds 0.1 per view on top of like/comment', () {
      final item = _item(likeCount: 5, commentCount: 2, viewCount: 100);
      expect(engagementScore(item), 5 * 2 + 2 * 3 + 100 * 0.1);
    });

    test(
        'a Drop with a null viewCount (never fetched) contributes 0 from '
        'views, same as zero', () {
      final item = _item(likeCount: 5, commentCount: 2);
      expect(engagementScore(item), 5 * 2 + 2 * 3);
    });

    test(
        'a Pop\'s viewCount never contributes, no matter how large -- its '
        'view counter is unguarded and easy to game (WYN-006), unlike '
        'Drop\'s (WYN-038)', () {
      final item = _item(
        contentType: HomeContentType.pop,
        likeCount: 5,
        commentCount: 2,
        viewCount: 100000,
      );
      expect(engagementScore(item), 5 * 2 + 2 * 3);
    });

    test(
        'view weight is small enough that likes/comments still dominate: '
        '10 likes beats 1 view-heavy post with no likes/comments', () {
      final heavilyViewed = _item(viewCount: 50); // 50 * 0.1 = 5
      final liked = _item(likeCount: 3); // 3 * 2 = 6

      expect(
          engagementScore(liked), greaterThan(engagementScore(heavilyViewed)));
    });
  });

  group('rankingScore includes engagementScore\'s view term (WYN-041)', () {
    test(
        'two otherwise-identical Drops with different view counts rank '
        'differently', () {
      final fewViews = _item(createdAt: _now, viewCount: 10);
      final manyViews = _item(createdAt: _now, viewCount: 500);

      final scoreFew =
          rankingScore(fewViews, now: _now, isFollowingAuthor: false);
      final scoreMany =
          rankingScore(manyViews, now: _now, isFollowingAuthor: false);

      expect(scoreMany, greaterThan(scoreFew));
    });

    test('a Pop\'s ranking score is unaffected by viewCount', () {
      final fewViews = _item(
        createdAt: _now,
        contentType: HomeContentType.pop,
        viewCount: 10,
      );
      final manyViews = _item(
        createdAt: _now,
        contentType: HomeContentType.pop,
        viewCount: 500,
      );

      expect(
        rankingScore(fewViews, now: _now, isFollowingAuthor: false),
        rankingScore(manyViews, now: _now, isFollowingAuthor: false),
      );
    });
  });

  group('rankedCandidateRows (get_wynos_ranked_feed row flattening)', () {
    // Shaped like what the RPC actually returns: the whole home_feed row
    // nested under row_data, with the two ranking values as siblings.
    Map<String, dynamic> raw(String id, String contentType, double score,
            {bool discovery = false}) =>
        {
          'row_data': {'id': id, 'content_type': contentType},
          'wynos_score': score,
          'is_discovery': discovery,
        };

    test('keeps every row, with its own score, when nothing is excluded', () {
      final rows = rankedCandidateRows([
        raw('a', 'drop', 9),
        raw('b', 'drop', 5),
      ]);

      expect(rows.map((e) => e.row['id']), ['a', 'b']);
      expect(rows.map((e) => e.score), [9, 5]);
    });

    test('an excluded row does not shift the scores of the rows after it '
        '-- the silent "สำหรับคุณ" mis-ordering this replaced', () {
      // Before the fix, the Pop at index 1 was dropped from the row list
      // but not from the score list, so 'c' (the 3rd raw row) was scored
      // with rawRows[1]'s 8.0 -- the Pop's score -- and every later item
      // shifted the same way.
      final rows = rankedCandidateRows(
        [
          raw('a', 'drop', 9),
          raw('pop1', 'pop', 8),
          raw('c', 'drop', 7, discovery: true),
          raw('d', 'drop', 6),
        ],
        excludeContentTypes: const {'pop'},
      );

      expect(rows.map((e) => e.row['id']), ['a', 'c', 'd']);
      expect(rows.map((e) => e.score), [9, 7, 6]);
    });

    test('is_discovery follows its own row past an exclusion too', () {
      final rows = rankedCandidateRows(
        [
          raw('pop1', 'pop', 8, discovery: true),
          raw('b', 'drop', 7),
        ],
        excludeContentTypes: const {'pop'},
      );

      expect(rows.single.row['id'], 'b');
      expect(rows.single.discovery, isFalse);
    });

    test('accepts an int wynos_score (Postgres numeric can arrive either '
        'way) without throwing', () {
      final rows = rankedCandidateRows([
        {
          'row_data': {'id': 'a', 'content_type': 'drop'},
          'wynos_score': 3,
          'is_discovery': false,
        },
      ]);

      expect(rows.single.score, 3.0);
    });

    test('returns an empty list when every row is excluded', () {
      final rows = rankedCandidateRows(
        [raw('pop1', 'pop', 8), raw('pop2', 'pop', 7)],
        excludeContentTypes: const {'pop'},
      );

      expect(rows, isEmpty);
    });
  });
}
