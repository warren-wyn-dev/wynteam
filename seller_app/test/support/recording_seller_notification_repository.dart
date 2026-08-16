import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zoky_seller/features/notification/data/seller_notification.dart';
import 'package:zoky_seller/features/notification/data/seller_notification_repository.dart';

/// A SellerNotificationRepository whose network-touching methods are
/// overridden to just return canned data / record what they were called
/// with, instead of making a real Supabase call. Mirrors `app/`'s
/// RecordingNotificationRepository -- see .wyn/learning/PATTERNS.md.
class RecordingSellerNotificationRepository extends SellerNotificationRepository {
  RecordingSellerNotificationRepository({
    List<SellerNotification>? notifications,
    this.unreadCount = 0,
  })  : notifications = notifications ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  /// Returned by [fetchNotifications] for page 0 only (page 1+ returns
  /// empty).
  final List<SellerNotification> notifications;

  final int unreadCount;

  int markAllAsReadCalls = 0;

  @override
  Future<List<SellerNotification>> fetchNotifications({required int page}) async {
    return page == 0 ? notifications : <SellerNotification>[];
  }

  @override
  Future<int> countUnread() async => unreadCount;

  @override
  Future<void> markAllAsRead() async {
    markAllAsReadCalls++;
  }
}
