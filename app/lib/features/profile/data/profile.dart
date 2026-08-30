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

/// WYN-045: the one shared 3-level vocabulary reused by all three
/// Interaction Privacy Controls (DM/Mention/Comment Permission) --
/// Product deliberately kept a single set of levels across all three
/// instead of a different scale per setting, to keep what the user has
/// to learn to one concept. `everyone` is the default, matching every
/// profile's `dm_permission`/`mention_permission`/`comment_permission`
/// columns' own `not null default 'everyone'` (supabase/schema.sql).
enum InteractionPermission { everyone, peopleIFollow, noOne }

InteractionPermission interactionPermissionFromString(String? value) =>
    switch (value) {
      'people_i_follow' => InteractionPermission.peopleIFollow,
      'no_one' => InteractionPermission.noOne,
      _ => InteractionPermission.everyone,
    };

extension InteractionPermissionDbValue on InteractionPermission {
  String get dbValue => switch (this) {
        InteractionPermission.everyone => 'everyone',
        InteractionPermission.peopleIFollow => 'people_i_follow',
        InteractionPermission.noOne => 'no_one',
      };
}

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
    this.dmPermission = InteractionPermission.everyone,
    this.mentionPermission = InteractionPermission.everyone,
    this.commentPermission = InteractionPermission.everyone,
    this.isVerified = false,
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
        // WYN-045: same "missing key defaults to the least-restrictive
        // value" reasoning as isPrivate above -- a partial map without
        // these keys reads as 'everyone', which also happens to be
        // these columns' own DB default for every profile that has
        // never touched Settings.
        dmPermission:
            interactionPermissionFromString(map['dm_permission'] as String?),
        mentionPermission: interactionPermissionFromString(
            map['mention_permission'] as String?),
        commentPermission: interactionPermissionFromString(
            map['comment_permission'] as String?),
        // WYNOSHomeSpec.md 4.5/4.9: same "missing key defaults to the
        // least-notable value" reasoning as isPrivate above -- a
        // partial map without this key (most ProfileRepository selects
        // don't fetch it) reads as unverified.
        isVerified: map['is_verified'] as bool? ?? false,
      );

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final PlatformRole platformRole;
  final bool isPrivate;
  final InteractionPermission dmPermission;
  final InteractionPermission mentionPermission;
  final InteractionPermission commentPermission;

  /// WYNOSHomeSpec.md 4.5/4.9: same one-account-only semantics as
  /// [HomeFeedItem.authorIsVerified] -- see that field's own doc
  /// comment.
  final bool isVerified;

  /// What to show as the profile's name: the display name if set, else
  /// "@username" as a fallback (per the WYN-003 design spec).
  String get nameOrUsername =>
      displayNameOrUsername(displayName: displayName, username: username);
}
