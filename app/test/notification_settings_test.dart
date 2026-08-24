import 'package:flutter_test/flutter_test.dart';
import 'package:wyn/features/notification/data/notification_settings.dart';

void main() {
  group('NotificationSettings', () {
    test('allEnabled has every category true (mirrors the DB\'s '
        '"missing row = enabled" contract)', () {
      const settings = NotificationSettings.allEnabled;
      for (final category in NotificationCategory.values) {
        expect(settings[category], isTrue);
      }
    });

    test('fromMap reads every column into the matching category', () {
      final settings = NotificationSettings.fromMap({
        'likes_enabled': false,
        'comments_enabled': true,
        'follows_enabled': false,
        'messages_enabled': true,
        'club_enabled': false,
        'system_enabled': true,
      });

      expect(settings.likes, isFalse);
      expect(settings.comments, isTrue);
      expect(settings.follows, isFalse);
      expect(settings.messages, isTrue);
      expect(settings.club, isFalse);
      expect(settings.system, isTrue);
    });

    test('copyWith changes only the targeted category, leaves the other 5',
        () {
      const settings = NotificationSettings.allEnabled;
      final updated = settings.copyWith(NotificationCategory.likes, false);

      expect(updated.likes, isFalse);
      expect(updated.comments, isTrue);
      expect(updated.follows, isTrue);
      expect(updated.messages, isTrue);
      expect(updated.club, isTrue);
      expect(updated.system, isTrue);
    });

    test('operator[] reads back the same category copyWith wrote', () {
      const settings = NotificationSettings.allEnabled;
      final updated = settings.copyWith(NotificationCategory.system, false);
      expect(updated[NotificationCategory.system], isFalse);
      expect(updated[NotificationCategory.club], isTrue);
    });
  });

  group('NotificationCategoryWire', () {
    test('wireValue matches supabase/schema.sql\'s p_category strings exactly',
        () {
      expect(NotificationCategory.likes.wireValue, 'likes');
      expect(NotificationCategory.comments.wireValue, 'comments');
      expect(NotificationCategory.follows.wireValue, 'follows');
      expect(NotificationCategory.messages.wireValue, 'messages');
      expect(NotificationCategory.club.wireValue, 'club');
      expect(NotificationCategory.system.wireValue, 'system');
    });
  });
}
