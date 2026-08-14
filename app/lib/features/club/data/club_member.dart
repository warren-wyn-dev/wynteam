import '../../../core/text_utils.dart';

/// The 4-tier Club role system (WYN-014) -- the project's first
/// role-based permission concept (Follow, WYN-008, is a plain boolean
/// with no role). Order matches ascending permission level.
enum ClubMemberRole { member, moderator, admin, owner }

/// Whether a join request has been approved yet. `banned` blocks
/// rejoining -- see the club_members insert policy in supabase/schema.sql.
enum ClubMemberStatus { pending, approved, banned }

ClubMemberRole clubMemberRoleFromString(String value) => ClubMemberRole.values
    .firstWhere((r) => r.name == value, orElse: () => ClubMemberRole.member);

ClubMemberStatus clubMemberStatusFromString(String value) =>
    ClubMemberStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ClubMemberStatus.pending,
    );

extension ClubMemberRolePermissions on ClubMemberRole {
  /// Owner/Admin/Moderator can delete others' posts, pin/unpin posts, and
  /// remove/ban general members -- see the Product spec's Admin System
  /// section.
  bool get canModeratePosts =>
      this == ClubMemberRole.owner ||
      this == ClubMemberRole.admin ||
      this == ClubMemberRole.moderator;

  /// Only Owner/Admin approve join requests, edit Club info, and change
  /// privacy.
  bool get canManageClub =>
      this == ClubMemberRole.owner || this == ClubMemberRole.admin;
}

/// A `club_members` row joined with the member's profile -- for the
/// Members tab list. See supabase/schema.sql (WYN-014 section).
class ClubMember {
  const ClubMember({
    required this.clubId,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  final String clubId;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final ClubMemberRole role;
  final ClubMemberStatus status;
  final DateTime createdAt;

  String get nameOrUsername =>
      displayNameOrUsername(displayName: displayName, username: username);

  factory ClubMember.fromMap(Map<String, dynamic> map) {
    final profile = map['profile'] as Map<String, dynamic>?;

    return ClubMember(
      clubId: map['club_id'] as String,
      userId: map['user_id'] as String,
      username: profile?['username'] as String? ?? '',
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      role: clubMemberRoleFromString(map['role'] as String),
      status: clubMemberStatusFromString(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
