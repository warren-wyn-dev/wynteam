import 'package:supabase_flutter/supabase_flutter.dart';

/// The 7 categories from Master Spec section 21 / the WYN-044 Product
/// spec's mapping table, in the same order NotificationSettingsScreen
/// renders them. Every category defaults to `true` (enabled) --
/// matches `notification_settings`' own `not null default true`
/// columns and `internal.notification_enabled()`'s "no row = every
/// category enabled" behavior at the DB layer (see supabase/
/// schema.sql, WYN-044 section). A plain immutable value type, not a
/// Dart record, so [copyWithCategory] can look the category key up by
/// name once instead of every call site needing its own switch.
class NotificationSettings {
  const NotificationSettings({
    this.likes = true,
    this.comments = true,
    this.follows = true,
    this.messages = true,
    this.club = true,
    this.trending = true,
    this.system = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const NotificationSettings();
    return NotificationSettings(
      likes: map['likes'] as bool? ?? true,
      comments: map['comments'] as bool? ?? true,
      follows: map['follows'] as bool? ?? true,
      messages: map['messages'] as bool? ?? true,
      club: map['club'] as bool? ?? true,
      trending: map['trending'] as bool? ?? true,
      system: map['system'] as bool? ?? true,
    );
  }

  final bool likes;
  final bool comments;
  final bool follows;
  final bool messages;
  final bool club;
  final bool trending;
  final bool system;

  /// Returns a copy with [category] (one of the 7 DB column names
  /// above) set to [value] -- everything else unchanged. Unknown
  /// category names are a no-op rather than a thrown error, since the
  /// only caller is [NotificationSettingsScreen], which only ever
  /// passes one of the 7 known keys.
  NotificationSettings copyWithCategory(String category, bool value) {
    return NotificationSettings(
      likes: category == 'likes' ? value : likes,
      comments: category == 'comments' ? value : comments,
      follows: category == 'follows' ? value : follows,
      messages: category == 'messages' ? value : messages,
      club: category == 'club' ? value : club,
      trending: category == 'trending' ? value : trending,
      system: category == 'system' ? value : system,
    );
  }
}

/// Fetches/upserts the current user's own `notification_settings` row
/// (WYN-044). No `userId` parameter anywhere -- RLS already scopes
/// every query to `auth.uid()`, same "someone else's settings isn't a
/// concept the backend allows at all" reasoning as SavedRepository
/// (WYN-013).
class NotificationSettingsRepository {
  NotificationSettingsRepository(this._client);

  final SupabaseClient _client;

  /// A user who has never opened NotificationSettingsScreen and
  /// toggled anything has no row here at all -- that's not an error,
  /// it's this feature's normal opt-out-model starting state, so every
  /// category comes back enabled either way ([NotificationSettings]'s
  /// own defaults double as the "no row" case).
  Future<NotificationSettings> fetch() async {
    final row =
        await _client.from('notification_settings').select().maybeSingle();
    return NotificationSettings.fromMap(row);
  }

  /// Upserts a single category's new value. `onConflict: 'user_id'` so
  /// the very first toggle a user ever makes both creates the row
  /// (using the table's own defaults for the other 6 categories) and
  /// sets this one category, in a single call -- no separate "create
  /// the row" step needed.
  Future<void> upsertCategory({
    required String category,
    required bool value,
  }) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('notification_settings').upsert(
      {'user_id': userId, category: value},
      onConflict: 'user_id',
    );
  }
}
