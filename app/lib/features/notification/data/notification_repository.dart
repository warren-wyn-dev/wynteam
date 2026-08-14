import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification.dart';

/// Wraps the `notifications` table reads/writes needed for WYN-012. Rows
/// are only ever created by the DB triggers in supabase/schema.sql (WYN-012
/// section) -- there's no create/insert method here at all, since a client
/// inserting a notification directly would also be rejected by RLS (no
/// insert policy grants it). `!notifications_actor_id_fkey` disambiguates
/// which of `notifications`' two FKs to `profiles` (recipient_id,
/// actor_id) this embed follows -- same PostgREST convention as
/// FollowRepository (WYN-008).
class NotificationRepository {
  NotificationRepository(this._client);

  final SupabaseClient _client;

  static const pageSize = 30;

  Future<List<WynNotification>> fetchNotifications({required int page}) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final rows = await _client
        .from('notifications')
        .select(
          'id, type, drop_id, pop_id, is_read, created_at, '
          'actor:profiles!notifications_actor_id_fkey(id, username, display_name, avatar_url)',
        )
        .order('created_at', ascending: false)
        .range(from, to);

    return rows.map((row) => WynNotification.fromMap(row)).toList();
  }

  Future<int> countUnread() async {
    final userId = _client.auth.currentUser!.id;
    final response = await _client
        .from('notifications')
        .count(CountOption.exact)
        .eq('recipient_id', userId)
        .eq('is_read', false);
    return response;
  }

  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser!.id;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }
}
