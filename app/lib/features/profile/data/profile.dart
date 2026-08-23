import '../../../core/text_utils.dart';

/// A platform-wide role (WYN-029) -- `user` is every ordinary account's
/// default. `moderator`/`admin` are set exclusively via direct Supabase
/// access this round (never through any client-facing insert/update
/// path -- see supabase/schema.sql's guard trigger on this column), so
/// there is no UI anywhere in the app to change this for yourself or
/// anyone else.
enum PlatformRole { user, moderator, admin }

PlatformRole platformRoleFromString(String? value) => switch (value) {
      'admin' => PlatformRole.admin,
      'moderator' => PlatformRole.moderator,
      _ => PlatformRole.user,
    };

/// A WYN user profile row. See supabase/schema.sql (WYN-003 section,
/// platformRole added by WYN-029).
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.platformRole = PlatformRole.user,
    this.isPrivate = false,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        username: map['username'] as String,
        displayName: map['display_name'] as String?,
        bio: map['bio'] as String?,
        avatarUrl: map['avatar_url'] as String?,
        platformRole: platformRoleFromString(map['platform_role'] as String?),
        // WYN-039: defaults to false so any pre-existing call site that
        // builds a Profile from a partial map (not a full `drops.select
        // author:profiles(*)` embed) never accidentally reads a private
        // account as public -- see ProfileRepository/FollowRepository.
        isPrivate: map['is_private'] as bool? ?? false,
      );

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final PlatformRole platformRole;
  final bool isPrivate;

  /// What to show as the profile's name: the display name if set, else
  /// "@username" as a fallback (per the WYN-003 design spec).
  String get nameOrUsername =>
      displayNameOrUsername(displayName: displayName, username: username);
}
