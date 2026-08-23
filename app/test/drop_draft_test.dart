import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop_draft.dart';

void main() {
  group('DropDraft.fromMap', () {
    test('parses an image-mode draft', () {
      final draft = DropDraft.fromMap({
        'id': 'd1',
        'image_url': 'https://example.com/draft.jpg',
        'caption': 'ยังคิดแคปชันไม่ออก',
        'poll_options': null,
        'poll_duration_days': null,
        'updated_at': '2026-01-01T00:00:00Z',
      });

      expect(draft.id, 'd1');
      expect(draft.imageUrl, 'https://example.com/draft.jpg');
      expect(draft.caption, 'ยังคิดแคปชันไม่ออก');
      expect(draft.isPoll, isFalse);
      expect(draft.pollOptions, isNull);
    });

    test('parses a poll-mode draft, including an incomplete (empty '
        'string) option', () {
      final draft = DropDraft.fromMap({
        'id': 'd2',
        'image_url': null,
        'caption': 'กินอะไรดี',
        'poll_options': ['พิซซ่า', ''],
        'poll_duration_days': 3,
        'updated_at': '2026-01-02T00:00:00Z',
      });

      expect(draft.imageUrl, isNull);
      expect(draft.isPoll, isTrue);
      expect(draft.pollOptions, ['พิซซ่า', '']);
      expect(draft.pollDurationDays, 3);
      expect(draft.updatedAt, DateTime.parse('2026-01-02T00:00:00Z'));
    });

    test('a draft with no image and no poll parses with both null', () {
      final draft = DropDraft.fromMap({
        'id': 'd3',
        'image_url': null,
        'caption': 'แค่ความคิด',
        'poll_options': null,
        'poll_duration_days': null,
        'updated_at': '2026-01-03T00:00:00Z',
      });

      expect(draft.isPoll, isFalse);
      expect(draft.imageUrl, isNull);
    });
  });
}
