/// The 6 opt-out categories WYN-044 gates notification delivery by --
/// see supabase/schema.sql's WYN-044 section for the full mapping of
/// which of the 24 `NotificationType` values (notification.dart) falls
/// under each. `likes` also covers `redrop` (folded in rather than
/// given a 7th category -- see .wyn/tasks/backlog/
/// WYN-044-notification-settings.md's Requirement 1). Moderation/
/// appeal and ZOKY order types are never gated by any of these and so
/// have no entry here at all.
enum NotificationCategory {
  likes,
  comments,
  follows,
  messages,
  club,
  system,
}

extension NotificationCategoryWire on NotificationCategory {
  /// Matches internal.notification_category_enabled()'s p_category
  /// argument and set_notification_category_enabled()'s p_category
  /// argument exactly (see supabase/schema.sql) -- both reject any
  /// string outside this set.
  String get wireValue => switch (this) {
        NotificationCategory.likes => 'likes',
        NotificationCategory.comments => 'comments',
        NotificationCategory.follows => 'follows',
        NotificationCategory.messages => 'messages',
        NotificationCategory.club => 'club',
        NotificationCategory.system => 'system',
      };
}

/// One user's full set of category toggles. Every field defaults to
/// `true` -- mirrors the DB's own "missing row = every category
/// enabled" contract (internal.notification_category_enabled()'s
/// coalesce(..., true)) so a user who has never opened this screen
/// sees every switch already on, matching what they've actually been
/// receiving.
class NotificationSettings {
  const NotificationSettings({
    this.likes = true,
    this.comments = true,
    this.follows = true,
    this.messages = true,
    this.club = true,
    this.system = true,
  });

  /// The default the app renders (a) before the initial fetch resolves
  /// and (b) if that fetch fails outright -- fail-open, matching the
  /// "no row = enabled" DB contract exactly rather than guessing at
  /// disabled, so a network hiccup can never look like the user turned
  /// their own notifications off. See the Design spec's Screen 2 states.
  static const allEnabled = NotificationSettings();

  final bool likes;
  final bool comments;
  final bool follows;
  final bool messages;
  final bool club;
  final bool system;

  bool operator [](NotificationCategory category) => switch (category) {
        NotificationCategory.likes => likes,
        NotificationCategory.comments => comments,
        NotificationCategory.follows => follows,
        NotificationCategory.messages => messages,
        NotificationCategory.club => club,
        NotificationCategory.system => system,
      };

  NotificationSettings copyWith(NotificationCategory category, bool value) {
    return NotificationSettings(
      likes: category == NotificationCategory.likes ? value : likes,
      comments: category == NotificationCategory.comments ? value : comments,
      follows: category == NotificationCategory.follows ? value : follows,
      messages: category == NotificationCategory.messages ? value : messages,
      club: category == NotificationCategory.club ? value : club,
      system: category == NotificationCategory.system ? value : system,
    );
  }

  /// Row shape: `notification_settings` has one row per user only once
  /// they've toggled something at least once (lazy upsert) -- a `null`
  /// map here means no row exists yet, which the caller should treat
  /// as [allEnabled], not as an error.
  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      likes: map['likes_enabled'] as bool,
      comments: map['comments_enabled'] as bool,
      follows: map['follows_enabled'] as bool,
      messages: map['messages_enabled'] as bool,
      club: map['club_enabled'] as bool,
      system: map['system_enabled'] as bool,
    );
  }
}
