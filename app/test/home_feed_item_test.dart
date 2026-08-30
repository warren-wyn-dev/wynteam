import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';

void main() {
  group('HomeFeedItem.fromMap', () {
    test('parses a drop row correctly', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': 'Nam Fah',
        'author_avatar_url': 'https://example.com/a.jpg',
        'created_at': '2026-01-01T00:00:00Z',
        'caption': 'hello',
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 5,
        'comment_count': 2,
      }, likedByMe: true, savedByMe: false);

      expect(item.contentType, HomeContentType.drop);
      expect(item.authorUsername, 'namfah');
      expect(item.imageUrl, 'https://example.supabase.co/drops/d1.jpg');
      expect(item.likeCount, 5);
      expect(item.commentCount, 2);
      expect(item.likedByMe, isTrue);
      expect(item.savedByMe, isFalse);
    });

    test('parses a pop row correctly', () {
      final item = HomeFeedItem.fromMap({
        'id': 'p1',
        'content_type': 'pop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': null,
        'video_url': 'https://example.supabase.co/pops/p1.mp4',
        'thumbnail_url': 'https://example.supabase.co/pops/p1_thumb.jpg',
        'duration_seconds': 30,
        'view_count': 100,
        'like_count': 3,
        'comment_count': 1,
      }, likedByMe: false, savedByMe: true);

      expect(item.contentType, HomeContentType.pop);
      expect(item.videoUrl, 'https://example.supabase.co/pops/p1.mp4');
      expect(item.durationSeconds, 30);
      expect(item.viewCount, 100);
      expect(item.savedByMe, isTrue);
    });

    test('parses a ReDrop-sourced drop row (WYN-034)', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': 'original caption',
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 5,
        'comment_count': 2,
        'redrop_count': 3,
        'redrop_id': 'r1',
        'redropper_id': 'u2',
        'redropper_username': 'som',
        'redropper_display_name': 'Som',
        'redropper_avatar_url': 'https://example.com/som.jpg',
        'quote_text': 'ดูนี่สิ',
      }, likedByMe: false, savedByMe: false, redroppedByMe: true);

      expect(item.redropId, 'r1');
      expect(item.redropperId, 'u2');
      expect(item.redropperUsername, 'som');
      expect(item.redropperNameOrUsername, 'Som');
      expect(item.quoteText, 'ดูนี่สิ');
      expect(item.redropCount, 3);
      expect(item.redroppedByMe, isTrue);
      // The underlying content still describes the *original* Drop.
      expect(item.authorUsername, 'namfah');
      expect(item.caption, 'original caption');
    });

    test('redrop_* fields are null and redropCount is 0 for a plain row', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 0,
        'comment_count': 0,
      }, likedByMe: false, savedByMe: false);

      expect(item.redropId, isNull);
      expect(item.redropperId, isNull);
      expect(item.quoteText, isNull);
      expect(item.redropCount, 0);
      expect(item.redroppedByMe, isFalse);
    });

    test('parses poll_id/poll_options/poll_expires_at and per-viewer '
        'poll state (WYN-035)', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': 'กินอะไรดี?',
        'image_url': null,
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 0,
        'comment_count': 0,
        'poll_id': 'p1',
        'poll_options': ['Pizza', 'Sushi'],
        'poll_expires_at': '2026-01-04T00:00:00Z',
      },
          likedByMe: false,
          savedByMe: false,
          pollMyVoteIndex: 1,
          pollTotalVotes: 4,
          pollOptionCounts: [1, 3]);

      expect(item.isPoll, isTrue);
      expect(item.pollOptions, ['Pizza', 'Sushi']);
      expect(item.pollExpiresAt, DateTime.parse('2026-01-04T00:00:00Z'));
      expect(item.pollMyVoteIndex, 1);
      expect(item.pollResultsVisible, isTrue);
    });

    test('poll_id absent (a plain row) leaves isPoll false', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 0,
        'comment_count': 0,
      }, likedByMe: false, savedByMe: false);

      expect(item.isPoll, isFalse);
      expect(item.pollResultsVisible, isFalse);
    });

    test('parses top_reply into a HomeTopReply (WYNOSHomeSpec.md 4.10)', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 5,
        'comment_count': 3,
        'top_reply': {
          'author_username': 'zen',
          'author_display_name': 'Zen',
          'text': 'สวยมากกก',
        },
      }, likedByMe: false, savedByMe: false);

      expect(item.topReply, isNotNull);
      expect(item.topReply!.authorNameOrUsername, 'Zen');
      expect(item.topReply!.text, 'สวยมากกก');
    });

    test('top_reply absent (nothing liked yet, or an older fetch path) '
        'leaves topReply null', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 5,
        'comment_count': 3,
      }, likedByMe: false, savedByMe: false);

      expect(item.topReply, isNull);
    });

    test('parses author_is_verified/redropper_is_verified '
        '(WYNOSHomeSpec.md 4.9)', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'wynos',
        'author_display_name': 'WYNOS',
        'author_avatar_url': null,
        'author_is_verified': true,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 0,
        'comment_count': 0,
        'redrop_id': 'r1',
        'redropper_id': 'u2',
        'redropper_username': 'zen',
        'redropper_is_verified': false,
      }, likedByMe: false, savedByMe: false);

      expect(item.authorIsVerified, isTrue);
      expect(item.redropperIsVerified, isFalse);
    });

    test('author_is_verified/redropper_is_verified absent (an older '
        'fetch path) default to false', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 0,
        'comment_count': 0,
      }, likedByMe: false, savedByMe: false);

      expect(item.authorIsVerified, isFalse);
      expect(item.redropperIsVerified, isFalse);
    });
  });

  group('votedPoll (WYN-035)', () {
    test('first-time vote seeds zeroed counts and increments the '
        'chosen option + total', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': 'poll?',
        'image_url': null,
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 0,
        'comment_count': 0,
        'poll_id': 'p1',
        'poll_options': ['Yes', 'No'],
        'poll_expires_at': '2026-01-04T00:00:00Z',
      }, likedByMe: false, savedByMe: false);

      final voted = item.votedPoll(0);
      expect(voted.pollMyVoteIndex, 0);
      expect(voted.pollTotalVotes, 1);
      expect(voted.pollOptionCounts, [1, 0]);
    });
  });

  group('copyWith (WYN-034)', () {
    test('overrides the given fields and keeps everything else, including '
        'redrop_* fields', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 5,
        'comment_count': 2,
        'redrop_count': 1,
        'redrop_id': 'r1',
        'redropper_id': 'u2',
        'redropper_username': 'som',
        'quote_text': 'ดูนี่สิ',
        'top_reply': {
          'author_username': 'zen',
          'author_display_name': null,
          'text': 'เจ๋งดี',
        },
      }, likedByMe: false, savedByMe: false);

      final copy = item.copyWith(likeCount: 6, redroppedByMe: true);

      expect(copy.likeCount, 6);
      expect(copy.redroppedByMe, isTrue);
      // Untouched fields, including the redrop_* ones a naive
      // hand-rolled copy could easily forget to repeat.
      expect(copy.redropId, 'r1');
      expect(copy.redropperId, 'u2');
      expect(copy.redropperUsername, 'som');
      expect(copy.quoteText, 'ดูนี่สิ');
      expect(copy.commentCount, 2);
      // A Like toggle doesn't refetch the top reply -- copyWith must
      // still carry it over as-is rather than silently resetting it.
      expect(copy.topReply?.text, 'เจ๋งดี');
    });
  });

  group('toDrop/toPop', () {
    test('toDrop carries every field over from a drop-type item', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': 'Nam Fah',
        'author_avatar_url': 'https://example.com/a.jpg',
        'created_at': '2026-01-01T00:00:00Z',
        'caption': 'hello',
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': 7,
        'like_count': 5,
        'comment_count': 2,
      }, likedByMe: true, savedByMe: true);

      final drop = item.toDrop();
      expect(drop.id, 'd1');
      expect(drop.imageUrl, item.imageUrl);
      expect(drop.caption, 'hello');
      expect(drop.likeCount, 5);
      expect(drop.likedByMe, isTrue);
      expect(drop.savedByMe, isTrue);
      // WYN-038.
      expect(drop.viewCount, 7);
    });

    test('toDrop defaults viewCount to 0 when view_count is null '
        '(WYN-038)', () {
      final item = HomeFeedItem.fromMap({
        'id': 'd1',
        'content_type': 'drop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': 'https://example.supabase.co/drops/d1.jpg',
        'video_url': null,
        'thumbnail_url': null,
        'duration_seconds': null,
        'view_count': null,
        'like_count': 0,
        'comment_count': 0,
      }, likedByMe: false, savedByMe: false);

      expect(item.toDrop().viewCount, 0);
    });

    test('toPop carries every field over from a pop-type item', () {
      final item = HomeFeedItem.fromMap({
        'id': 'p1',
        'content_type': 'pop',
        'author_id': 'u1',
        'author_username': 'namfah',
        'author_display_name': null,
        'author_avatar_url': null,
        'created_at': '2026-01-01T00:00:00Z',
        'caption': null,
        'image_url': null,
        'video_url': 'https://example.supabase.co/pops/p1.mp4',
        'thumbnail_url': 'https://example.supabase.co/pops/p1_thumb.jpg',
        'duration_seconds': 30,
        'view_count': 100,
        'like_count': 3,
        'comment_count': 1,
      }, likedByMe: false, savedByMe: false);

      final pop = item.toPop();
      expect(pop.id, 'p1');
      expect(pop.videoUrl, item.videoUrl);
      expect(pop.thumbnailUrl, item.thumbnailUrl);
      expect(pop.durationSeconds, 30);
      expect(pop.viewCount, 100);
    });
  });

  group('HomeFeedItem.fromDrop (WYN-038)', () {
    test('carries Drop.viewCount over -- without this, a HomeDropCard '
        'built via fromDrop (e.g. hashtag_feed_screen.dart) would '
        'render the literal string "null" instead of a number', () {
      final drop = Drop(
        id: 'd1',
        authorId: 'u1',
        authorUsername: 'namfah',
        imageUrl: 'https://example.supabase.co/drops/d1.jpg',
        createdAt: DateTime(2026, 1, 1),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
        viewCount: 9,
      );

      expect(HomeFeedItem.fromDrop(drop).viewCount, 9);
    });

    test('defaults to 0 (never null) when the source Drop never had '
        'its real view count wired in', () {
      final drop = Drop(
        id: 'd1',
        authorId: 'u1',
        authorUsername: 'namfah',
        imageUrl: 'https://example.supabase.co/drops/d1.jpg',
        createdAt: DateTime(2026, 1, 1),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );

      expect(HomeFeedItem.fromDrop(drop).viewCount, 0);
    });
  });
}
