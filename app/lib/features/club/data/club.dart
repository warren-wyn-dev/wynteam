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

  /// Beta4 §8.1: **the** Club Identity Image -- see [identityImageUrl].
  /// Read through that getter, not directly.
  final String? iconUrl;

  /// Legacy second image slot. Beta4 §8.1 forbids a Club having two
  /// images ("ห้าม: Cover Image แยก / Background Image แยก / อัปโหลด
  /// สองรูปสำหรับ Club เดียว"), so nothing writes this any more and
  /// nothing reads it except [identityImageUrl]'s fallback, which is
  /// what keeps Clubs created before Beta4 showing the picture their
  /// owner actually chose. Kept as a field (and as a column) rather
  /// than dropped: deleting it would blank every existing Club's image,
  /// and a destructive migration is not something Beta4's scope covers.
  final String? coverUrl;

  final String? category;
  final ClubPrivacy privacy;
  final String ownerId;
  final DateTime createdAt;
  final int memberCount;

  /// The one image that represents this Club, wherever a Club is shown:
  /// its page, its card in Explore, the recommendation rows, "Club ของ
  /// ฉัน", the mini cards.
  ///
  /// Beta4 §8.1: "Club ใช้รูปเพียง 1 รูป ... ให้มี Club Identity Image
  /// เพียงหนึ่งเดียว สามารถนำรูปนี้ไปแสดงใน UI ของ Club ตามความเหมาะสม".
  ///
  /// The database has carried two image columns since WYN-014, and the
  /// UI had drifted into using them as two unrelated pictures: the
  /// create/edit forms only ever uploaded `cover_url`, while the Club
  /// page header, "Club ของฉัน", the ranked rows and the mini cards all
  /// read `icon_url` -- a column nothing in the product could set. The
  /// visible result was that every Club showed its photo on a discovery
  /// card and a grey letter-avatar everywhere else, from one upload.
  ///
  /// Reading order is icon-then-cover because Beta4 writes the single
  /// upload to `icon_url` (the column the majority of surfaces already
  /// read), while `cover_url` is where every pre-Beta4 Club's image
  /// still lives. Null when the owner never picked one, which is
  /// allowed -- callers fall back to the Club's initial, same as an
  /// avatar-less profile.
  String? get identityImageUrl => iconUrl ?? coverUrl;

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
