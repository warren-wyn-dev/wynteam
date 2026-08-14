import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/notification/data/notification.dart';
import 'package:wyn/features/notification/data/notification_repository.dart';

/// A NotificationRepository whose network-touching methods are overridden
/// to just return canned data / record what they were called with,
/// instead of making a real Supabase call. Mirrors RecordingFollowRepository
/// -- see .wyn/learning/PATTERNS.md.
class RecordingNotificationRepository extends NotificationRepository {
  RecordingNotificationRepository({
    List<WynNotification>? notifications,
    this.unreadCount = 0,
  })  : notifications = notifications ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchNotifications] for page 0 only (page 1+ returns
  /// empty).
  final List<WynNotification> notifications;

  final int unreadCount;

  int markAllAsReadCalls = 0;

  @override
  Future<List<WynNotification>> fetchNotifications({required int page}) async {
    return page == 0 ? notifications : <WynNotification>[];
  }

  @override
  Future<int> countUnread() async => unreadCount;

  @override
  Future<void> markAllAsRead() async {
    markAllAsReadCalls++;
  }
}
