/// Fixed category list for CreateClubScreen's dropdown -- per the
/// Product spec (Founder's WYN CLUB brief), not user-extensible in V1.
const clubCategories = [
  'Technology',
  'Gaming',
  'Education',
  'Lifestyle',
  'Food',
  'Sports',
  'Entertainment',
  'Business',
  'Marketplace',
];

enum ClubPrivacy { public, private }

ClubPrivacy clubPrivacyFromString(String value) =>
    value == 'private' ? ClubPrivacy.private : ClubPrivacy.public;

/// A WYN Club row, joined with a live member count. See
/// supabase/schema.sql (WYN-014 section).
class Club {
  const Club({
    required this.id,
    required this.name,
    this.description,
    this.rules,
    this.iconUrl,
    this.coverUrl,
    this.category,
    required this.privacy,
    required this.ownerId,
    required this.createdAt,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String? description;
  final String? rules;
  final String? iconUrl;
  final String? coverUrl;
  final String? category;
  final ClubPrivacy privacy;
  final String ownerId;
  final DateTime createdAt;
  final int memberCount;

  /// [memberCount] isn't embeddable in the same select in a form the
  /// client can trust (an approved-only count needs a separate filtered
  /// query), so ClubRepository fills it in from a dedicated count lookup.
  factory Club.fromMap(
    Map<String, dynamic> map, {
    required int memberCount,
  }) {
    return Club(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      rules: map['rules'] as String?,
      iconUrl: map['icon_url'] as String?,
      coverUrl: map['cover_url'] as String?,
      category: map['category'] as String?,
      privacy: clubPrivacyFromString(map['privacy'] as String),
      ownerId: map['owner_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      memberCount: memberCount,
    );
  }
}
