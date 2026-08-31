import '../../../core/text_utils.dart';

/// One entry in [HomeFeedItem.likedBy] -- the first 3 people (most-recent
/// first) who liked a Home feed row, per `public.home_feed.liked_by`
/// (see supabase/schema.sql, WYNOSHomeSpec.md 4.8 section). Backs the
/// stacked-avatar "ถูกใจโดย ..." row -- a lighter-weight type than
/// [Profile] since the view only ever embeds these 4 fields per liker.
class HomeLiker {
  const HomeLiker({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  String get nameOrUsername =>
      displayNameOrUsername(displayName: displayName, username: username);

  factory HomeLiker.fromMap(Map<String, dynamic> map) => HomeLiker(
        id: map['id'] as String,
        username: map['username'] as String? ?? '',
        displayName: map['display_name'] as String?,
        avatarUrl: map['avatar_url'] as String?,
      );

  /// Parses the `liked_by` jsonb array column -- null/missing (an older
  /// query path that doesn't select it) and an empty array both become
  /// an empty list, same "hidden until real data exists" posture as
  /// every other optional home_feed embed.
  static List<HomeLiker> listFromMap(Map<String, dynamic> map) {
    final raw = map['liked_by'] as List<dynamic>?;
    if (raw == null) return const [];
    return raw
        .map((entry) => HomeLiker.fromMap(entry as Map<String, dynamic>))
        .toList();
  }
}
