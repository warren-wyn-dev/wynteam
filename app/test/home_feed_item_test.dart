import 'package:flutter_test/flutter_test.dart';

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
        'view_count': null,
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
}
