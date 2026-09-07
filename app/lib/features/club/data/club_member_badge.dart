/// WYN-129 -- the 3 Founder-approved badge colors. Fixed palette, not a
/// free color picker (Design's Components: "เลือกจาก palette ที่กำหนดไว้
/// ไม่ใช่ color picker อิสระ") -- also enforced at the DB layer by
/// `club_member_badges.color_key`'s CHECK constraint (supabase/schema.sql).
enum ClubBadgeColor { gold, sage, plum }

extension ClubBadgeColorWireValue on ClubBadgeColor {
  String get wireValue => name;
}

ClubBadgeColor clubBadgeColorFromString(String value) => ClubBadgeColor.values
    .firstWhere((c) => c.name == value, orElse: () => ClubBadgeColor.gold);

/// A `club_member_badges` row (WYN-129) -- a purely cosmetic label a
/// Club's Owner/Admin can attach to one member, scoped to that Club
/// only. See supabase/schema.sql. **Never** used for any permission
/// decision -- see `ClubBadgeRepository`'s own doc comment for why this
/// stays in its own isolated file.
class ClubMemberBadge {
  const ClubMemberBadge({
    required this.clubId,
    required this.userId,
    required this.label,
    required this.colorKey,
    required this.createdBy,
    required this.createdAt,
  });

  final String clubId;
  final String userId;
  final String label;
  final ClubBadgeColor colorKey;
  final String createdBy;
  final DateTime createdAt;

  factory ClubMemberBadge.fromMap(Map<String, dynamic> map) => ClubMemberBadge(
        clubId: map['club_id'] as String,
        userId: map['user_id'] as String,
        label: map['label'] as String,
        colorKey: clubBadgeColorFromString(map['color_key'] as String),
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
