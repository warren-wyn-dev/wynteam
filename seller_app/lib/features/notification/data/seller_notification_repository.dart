import 'package:supabase_flutter/supabase_flutter.dart';

import 'seller_notification.dart';

/// Wraps the `notifications` table reads/writes for a seller -- mirrors
/// `app/`'s `NotificationRepository` (WYN-012/WYN-015), scoped to just
/// the 2 types a seller can ever receive (see SellerNotification's doc
/// comment). Rows are only ever created by the `notify_new_order`/
/// `notify_order_cancelled` triggers in supabase/schema.sql (ZOKY-005
/// R1) -- there's no create/insert method here, same reasoning as
/// `app/`'s repository.
class SellerNotificationRepository {
  SellerNotificationRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 30;

  /// `.inFilter('type', ...)` rather than trusting [SellerNotification.
  /// fromMap] to reject anything else -- a store owner's profile can
  /// also be the recipient of ordinary WYN Social notifications (same
  /// `notifications` table, same recipient_id, shared across both
  /// apps), which this app has no UI to render at all. Filtering the
  /// query itself, not just the model, keeps this list from ever
  /// throwing on a row it was never meant to show.
  Future<List<SellerNotification>> fetchNotifications({required int page}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('notifications')
        .select(
          'id, type, order_id, is_read, created_at, '
          'actor:profiles!notifications_actor_id_fkey(username, display_name)',
        )
        .inFilter('type', ['new_order', 'order_cancelled'])
        .order('created_at', ascending: false)
        .range(from, to);

    return rows.map((row) => SellerNotification.fromMap(row)).toList();
  }

  Future<int> countUnread() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('notifications')
        .count(CountOption.exact)
        .eq('recipient_id', userId)
        .eq('is_read', false)
        .inFilter('type', ['new_order', 'order_cancelled']);
    return response;
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false)
        .inFilter('type', ['new_order', 'order_cancelled']);
  }
}
