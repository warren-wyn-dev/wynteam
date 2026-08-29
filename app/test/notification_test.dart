import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/notification/data/notification.dart';

void main() {
  group('WynNotification.fromMap', () {
    test(
        'parses a populated embedded actor (every notification type except '
        'the 2 moderation types)', () {
      final notification = WynNotification.fromMap({
        'id': 'n1',
        'type': 'follow',
        'actor': {
          'id': 'u1',
          'username': 'namfah',
          'display_name': 'Nam Fah',
          'avatar_url': 'https://example.com/a.jpg',
        },
        'drop_id': null,
        'pop_id': null,
        'club_id': null,
        'club_post_id': null,
        'order_id': null,
        'reason': null,
        'is_read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(notification.actorId, 'u1');
      expect(notification.actorUsername, 'namfah');
      expect(notification.actorDisplayName, 'Nam Fah');
      expect(notification.actorAvatarUrl, 'https://example.com/a.jpg');
      expect(notification.actorNameOrUsername, 'Nam Fah');
    });

    // WYN-029 fix (.wyn/tasks/bugs/WYN-029-moderation-actor-identity-leak.md):
    // apply_moderation_action() now inserts actor_id = NULL for
    // moderation_warning/moderation_content_removed, so PostgREST's
    // embedded-resource syntax degrades to a null `actor` key on the raw
    // row instead of a populated object -- fromMap must not crash on
    // that, unlike the `as Map<String, dynamic>` cast this replaced.
    test(
        'does not crash when actor is null (moderation_warning/'
        'moderation_content_removed with a null actor_id) and leaves every '
        'actor field null', () {
      final notification = WynNotification.fromMap({
        'id': 'n2',
        'type': 'moderation_warning',
        'actor': null,
        'drop_id': null,
        'pop_id': null,
        'club_id': null,
        'club_post_id': null,
        'order_id': null,
        'reason': 'สแปมซ้ำหลายครั้ง',
        'is_read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(notification.actorId, isNull);
      expect(notification.actorUsername, isNull);
      expect(notification.actorDisplayName, isNull);
      expect(notification.actorAvatarUrl, isNull);
      // The real leak this bug was about: proves there is no way left to
      // recover the reviewer's identity through this object at all, not
      // just that one screen chooses not to render it.
      expect(notification.actorNameOrUsername, '');
    });

    test('does not crash when the actor key is entirely absent from the map',
        () {
      final notification = WynNotification.fromMap({
        'id': 'n3',
        'type': 'moderation_content_removed',
        'drop_id': null,
        'pop_id': null,
        'club_id': null,
        'club_post_id': null,
        'order_id': null,
        'reason': 'เนื้อหาผิดกฎหมาย',
        'is_read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(notification.actorId, isNull);
      expect(notification.actorUsername, isNull);
      expect(notification.actorNameOrUsername, '');
    });

    // WYN-043: schema.sql's notifications_type_check has allowed 'redrop'
    // since WYN-034 (notify_redrop() inserts it on every ReDrop), but
    // _typeFromString never had a case for it -- this is the exact line
    // that threw ArgumentError('Unknown notification type: redrop') for
    // any real redrop row, with no try/catch anywhere upstream in
    // NotificationRepository.fetchNotifications to contain it. Proven
    // red->green: reverting the 'redrop' case in _typeFromString and
    // re-running this test reproduces that exact ArgumentError; restoring
    // it passes again.
    test('parses type: "redrop" (WYN-034/043) without throwing', () {
      final notification = WynNotification.fromMap({
        'id': 'n4',
        'type': 'redrop',
        'actor': {
          'id': 'u1',
          'username': 'namfah',
          'display_name': null,
          'avatar_url': null,
        },
        'drop_id': 'd1',
        'pop_id': null,
        'club_id': null,
        'club_post_id': null,
        'order_id': null,
        'reason': null,
        'is_read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(notification.type, NotificationType.redrop);
      expect(notification.dropId, 'd1');
    });

    // WYN-043: send_system_notification() always inserts actor_id = NULL
    // (mirrors the moderation types' null-actor shape above) and puts its
    // message in `reason`.
    test(
        'parses type: "system" (WYN-043) with a null actor and the '
        'admin\'s message in reason', () {
      final notification = WynNotification.fromMap({
        'id': 'n5',
        'type': 'system',
        'actor': null,
        'drop_id': null,
        'pop_id': null,
        'club_id': null,
        'club_post_id': null,
        'order_id': null,
        'reason': 'ระบบจะปิดปรับปรุงคืนนี้',
        'is_read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(notification.type, NotificationType.system);
      expect(notification.actorId, isNull);
      expect(notification.reason, 'ระบบจะปิดปรับปรุงคืนนี้');
    });

    // 02-notifications.tsx's preview line (2026-08-29) -- the referenced
    // Drop/Pop's own caption, embedded via NotificationRepository's
    // `drop:drops(caption)`/`pop:pops(caption)` select.
    test(
        'parses contentPreview from the embedded drop\'s caption for a '
        'drop-typed notification', () {
      final notification = WynNotification.fromMap({
        'id': 'n6',
        'type': 'like_drop',
        'actor': {
          'id': 'u1',
          'username': 'namfah',
          'display_name': null,
          'avatar_url': null,
        },
        'drop_id': 'd1',
        'pop_id': null,
        'club_id': null,
        'club_post_id': null,
        'order_id': null,
        'reason': null,
        'drop': {'caption': 'สวัสดีชาว WYNOS'},
        'pop': null,
        'is_read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(notification.contentPreview, 'สวัสดีชาว WYNOS');
    });

    test(
        'parses contentPreview from the embedded pop\'s caption for a '
        'pop-typed notification', () {
      final notification = WynNotification.fromMap({
        'id': 'n7',
        'type': 'like_pop',
        'actor': {
          'id': 'u1',
          'username': 'namfah',
          'display_name': null,
          'avatar_url': null,
        },
        'drop_id': null,
        'pop_id': 'p1',
        'club_id': null,
        'club_post_id': null,
        'order_id': null,
        'reason': null,
        'drop': null,
        'pop': {'caption': 'คลิปนี้ฮามาก'},
        'is_read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(notification.contentPreview, 'คลิปนี้ฮามาก');
    });

    test(
        'contentPreview is null when the row has no drop/pop embed (e.g. '
        'follow) or the referenced post has no caption', () {
      final notification = WynNotification.fromMap({
        'id': 'n8',
        'type': 'follow',
        'actor': {
          'id': 'u1',
          'username': 'namfah',
          'display_name': null,
          'avatar_url': null,
        },
        'drop_id': null,
        'pop_id': null,
        'club_id': null,
        'club_post_id': null,
        'order_id': null,
        'reason': null,
        'is_read': false,
        'created_at': '2026-01-01T00:00:00Z',
      });

      expect(notification.contentPreview, isNull);
    });
  });

  group('actorNameOrUsername', () {
    final createdAt = DateTime(2026, 1, 1);

    test('falls back to @username when actorDisplayName is null', () {
      final notification = WynNotification(
        id: 'n1',
        type: NotificationType.follow,
        actorId: 'u1',
        actorUsername: 'namfah',
        isRead: false,
        createdAt: createdAt,
      );
      expect(notification.actorNameOrUsername, '@namfah');
    });

    test('uses actorDisplayName when set', () {
      final notification = WynNotification(
        id: 'n1',
        type: NotificationType.follow,
        actorId: 'u1',
        actorUsername: 'namfah',
        actorDisplayName: 'Nam Fah',
        isRead: false,
        createdAt: createdAt,
      );
      expect(notification.actorNameOrUsername, 'Nam Fah');
    });

    test('returns empty string, not a crash, when actorUsername is null', () {
      final notification = WynNotification(
        id: 'n1',
        type: NotificationType.moderationWarning,
        isRead: false,
        createdAt: createdAt,
      );
      expect(notification.actorNameOrUsername, '');
    });
  });
}
