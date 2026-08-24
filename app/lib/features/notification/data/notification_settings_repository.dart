import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_settings.dart';

/// Wraps `notification_settings` (WYN-044) -- a select for the current
/// user's own row (RLS restricts this to `auth.uid()` already, same
/// shape as BlockRepository's fetchBlockedUsers) and the
/// `set_notification_category_enabled` RPC, which upserts and changes
/// exactly one category at a time so the caller never needs to already
/// know the other 5 categories' current values.
class NotificationSettingsRepository {
  NotificationSettingsRepository(this._client);

  final SupabaseClient _client;

  /// Returns [NotificationSettings.allEnabled] when the user has never
  /// toggled anything (no row yet) -- mirrors
  /// internal.notification_category_enabled()'s own "missing row =
  /// enabled" contract at the DB layer exactly, rather than leaving it
  /// to each caller to remember.
  Future<NotificationSettings> fetchSettings() async {
    final row = await _client
        .from('notification_settings')
        .select(
          'likes_enabled, comments_enabled, follows_enabled, '
          'messages_enabled, club_enabled, system_enabled',
        )
        .maybeSingle();

    if (row == null) return NotificationSettings.allEnabled;
    return NotificationSettings.fromMap(row);
  }

  Future<void> updateCategory(NotificationCategory category, bool enabled) {
    return _client.rpc('set_notification_category_enabled', params: {
      'p_category': category.wireValue,
      'p_enabled': enabled,
    });
  }
}
