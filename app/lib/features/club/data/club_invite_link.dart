/// One row of `public.club_invite_links` (WYN-136) -- see
/// supabase/schema.sql's WYN-136 section. Only ever fetched by an
/// Owner/Admin of [clubId] (that table's own SELECT policy), so there is
/// no separate "am I allowed to see this" check needed client-side.
class ClubInviteLink {
  const ClubInviteLink({
    required this.id,
    required this.clubId,
    required this.code,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
    this.maxUses,
    this.useCount = 0,
    this.revokedAt,
  });

  final String id;
  final String clubId;
  final String code;
  final String createdBy;
  final DateTime createdAt;

  /// Null means "no expiration" -- one of the 4 choices
  /// `create_club_invite_link()`'s own `p_expires_in_days` accepts
  /// (null/1/7/30).
  final DateTime? expiresAt;

  /// Null means "unlimited" -- one of the 4 choices
  /// `create_club_invite_link()`'s own `p_max_uses` accepts
  /// (null/10/50/100).
  final int? maxUses;
  final int useCount;
  final DateTime? revokedAt;

  bool get isRevoked => revokedAt != null;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isExhausted => maxUses != null && useCount >= maxUses!;

  /// True only for a link an Owner/Admin can still hand out -- a
  /// revoked/expired/exhausted link stays in the list (Design doc: "ให้
  /// Owner เห็นประวัติ") but renders visibly inactive.
  bool get isActive => !isRevoked && !isExpired && !isExhausted;

  factory ClubInviteLink.fromMap(Map<String, dynamic> map) => ClubInviteLink(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        code: map['code'] as String,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        expiresAt: map['expires_at'] == null
            ? null
            : DateTime.parse(map['expires_at'] as String),
        maxUses: map['max_uses'] as int?,
        useCount: map['use_count'] as int? ?? 0,
        revokedAt: map['revoked_at'] == null
            ? null
            : DateTime.parse(map['revoked_at'] as String),
      );
}

/// `preview_club_invite_link()`'s own `status` column (WYN-136) -- see
/// that RPC's doc comment in supabase/schema.sql for exactly which
/// condition maps to which value.
enum ClubInviteLinkStatus { valid, expired, revoked, exhausted, notFound }

ClubInviteLinkStatus _statusFromWireValue(String value) => switch (value) {
      'valid' => ClubInviteLinkStatus.valid,
      'expired' => ClubInviteLinkStatus.expired,
      'revoked' => ClubInviteLinkStatus.revoked,
      'exhausted' => ClubInviteLinkStatus.exhausted,
      _ => ClubInviteLinkStatus.notFound,
    };

/// The result of `preview_club_invite_link(code)` (WYN-136) -- every
/// field except [status] is null whenever [status] isn't
/// [ClubInviteLinkStatus.valid] (that RPC's own `left join`: no club to
/// show once the link itself doesn't check out). [clubIconUrl] is
/// already a signed URL by the time this is constructed --
/// `ClubRepository.previewInviteLink()` signs the RPC's own raw storage
/// path before handing this back, same as every other Club icon read in
/// this app.
class ClubInvitePreview {
  const ClubInvitePreview({
    required this.status,
    this.clubId,
    this.clubName,
    this.clubPrivacy,
    this.clubIconUrl,
  });

  final ClubInviteLinkStatus status;
  final String? clubId;
  final String? clubName;

  /// Wire value ('public'/'private'), not `ClubPrivacy` -- kept as the
  /// raw string here so this model has no dependency on club.dart;
  /// `ClubInvitePreviewScreen` converts it at render time the same way
  /// `Club.fromMap` does.
  final String? clubPrivacy;
  final String? clubIconUrl;

  factory ClubInvitePreview.fromMap(Map<String, dynamic> map,
          {String? signedIconUrl}) =>
      ClubInvitePreview(
        status: _statusFromWireValue(map['status'] as String),
        clubId: map['club_id'] as String?,
        clubName: map['club_name'] as String?,
        clubPrivacy: map['club_privacy'] as String?,
        clubIconUrl: signedIconUrl,
      );
}
