/// A WYN Club channel row (WYN-127) -- a Discord-style room within a
/// Club. `club_posts.channel_id` scopes every post to exactly one of
/// these. Every Club always has at least one channel ("ทั่วไป", created
/// automatically by `clubs_add_default_channel()` -- see
/// supabase/schema.sql).
class ClubChannel {
  const ClubChannel({
    required this.id,
    required this.clubId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.categoryId,
  });

  final String id;
  final String clubId;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  /// WYN-133 (requirement 7) -- which [ClubChannelCategory] this channel
  /// is grouped under, if any. `null` means "ไม่มีกลุ่ม" -- exactly the
  /// pre-WYN-133 state every existing channel starts in.
  final String? categoryId;

  factory ClubChannel.fromMap(Map<String, dynamic> map) => ClubChannel(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        name: map['name'] as String,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        categoryId: map['category_id'] as String?,
      );
}

/// WYN-133 (requirement 7) -- a Discord-style named grouping of a Club's
/// [ClubChannel]s, e.g. "ทั่วไป"/"ฟีดแบ็กแอป". Purely organizational:
/// deleting one never deletes its channels (see
/// `public.club_channel_categories`'s `on delete set null` in
/// supabase/schema.sql) -- they just fall back to "ไม่มีกลุ่ม".
class ClubChannelCategory {
  const ClubChannelCategory({
    required this.id,
    required this.clubId,
    required this.name,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String clubId;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  factory ClubChannelCategory.fromMap(Map<String, dynamic> map) => ClubChannelCategory(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        name: map['name'] as String,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
