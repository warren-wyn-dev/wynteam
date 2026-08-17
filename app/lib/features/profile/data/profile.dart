import '../../../core/text_utils.dart';

/// A WYN user profile row. See supabase/schema.sql (WYN-003 section).
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.coverUrl,
    this.website,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        username: map['username'] as String,
        displayName: map['display_name'] as String?,
        bio: map['bio'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        coverUrl: map['cover_url'] as String?,
        website: map['website'] as String?,
      );

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;

  /// WYN-024 (Profile Identity Fields).
  final String? coverUrl;

  /// A normalized (always has an `http(s)://` scheme when set) link the
  /// user added to their profile. WYN-024.
  final String? website;

  /// What to show as the profile's name: the display name if set, else
  /// "@username" as a fallback (per the WYN-003 design spec).
  String get nameOrUsername =>
      displayNameOrUsername(displayName: displayName, username: username);
}
