/// A ZOKY store row (`public.stores`), joined with a live product count.
/// See supabase/schema.sql (ZOKY-001 section).
class Store {
  const Store({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    required this.createdAt,
    required this.productCount,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final DateTime createdAt;
  final int productCount;

  /// [productCount] isn't embeddable in the same select in a form the
  /// client can trust, so ZokyRepository fills it in from a dedicated
  /// count lookup -- same approach as Club.fromMap's memberCount.
  factory Store.fromMap(
    Map<String, dynamic> map, {
    required int productCount,
  }) {
    return Store(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      logoUrl: map['logo_url'] as String?,
      bannerUrl: map['banner_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      productCount: productCount,
    );
  }
}
