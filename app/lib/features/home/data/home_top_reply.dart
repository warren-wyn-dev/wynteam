import '../../../core/text_utils.dart';

/// [HomeFeedItem.topReply] -- the highest-engagement top-level comment
/// on a Home feed row, per `public.home_feed.top_reply` (see
/// supabase/schema.sql, WYNOSHomeSpec.md 4.10). Null when no comment on
/// the post has ever been liked (nothing "worth surfacing" yet, per
/// that section's own trigger rule).
class HomeTopReply {
  const HomeTopReply({
    required this.authorUsername,
    this.authorDisplayName,
    required this.text,
  });

  final String authorUsername;
  final String? authorDisplayName;
  final String text;

  String get authorNameOrUsername => displayNameOrUsername(
        displayName: authorDisplayName,
        username: authorUsername,
      );

  factory HomeTopReply.fromMap(Map<String, dynamic> map) => HomeTopReply(
        authorUsername: map['author_username'] as String? ?? '',
        authorDisplayName: map['author_display_name'] as String?,
        text: map['text'] as String? ?? '',
      );

  /// Parses the `top_reply` jsonb column -- null/missing (no qualifying
  /// comment, or an older fetch path that doesn't select it) both
  /// become null here.
  static HomeTopReply? fromHomeFeedMap(Map<String, dynamic> map) {
    final raw = map['top_reply'] as Map<String, dynamic>?;
    if (raw == null) return null;
    return HomeTopReply.fromMap(raw);
  }
}
