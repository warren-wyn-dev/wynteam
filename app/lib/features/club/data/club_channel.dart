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
  });

  final String id;
  final String clubId;
  final String name;
  final String createdBy;
  final DateTime createdAt;

  factory ClubChannel.fromMap(Map<String, dynamic> map) => ClubChannel(
        id: map['id'] as String,
        clubId: map['club_id'] as String,
        name: map['name'] as String,
        createdBy: map['created_by'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
