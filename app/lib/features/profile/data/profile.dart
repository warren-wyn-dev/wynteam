import '../../../core/text_utils.dart';

/// A WYN user profile row. See supabase/schema.sql (WYN-003 section).
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        username: map['username'] as String,
        displayName: map['display_name'] as String?,
        bio: map['bio'] as String?,
        avatarUrl: map['avatar_url'] as String?,
      );

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;

  /// What to show as the profile's name: the display name if set, else
  /// "@username" as a fallback (per the WYN-003 design spec).
  String get nameOrUsername =>
      displayNameOrUsername(displayName: displayName, username: username);
}
