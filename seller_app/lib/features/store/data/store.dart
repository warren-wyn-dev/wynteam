/// A seller's store row (`public.stores`). Duplicated from
/// `app/lib/features/zoky/data/store.dart` (WYN Social / ZOKY
/// Marketplace's `Store` model, same table) since this is a separate
/// Flutter binary -- see .wyn/company/DECISIONS.md, 2026-08-15.
///
/// Unlike the Customer-facing `Store` model, this one has no
/// [productCount] field: nothing in SELLER-001 needs a live product
/// count (that's SELLER-002's concern), and adding it here would mean
/// an extra query every time `SellerRepository.fetchMyStore()` runs for
/// no reason this task needs.
class Store {
  const Store({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.logoUrl,
    this.bannerUrl,
    this.address,
    this.contactPhone,
    this.businessHours,
    required this.createdAt,
  });

  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String? address;
  final String? contactPhone;
  final String? businessHours;
  final DateTime createdAt;

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      logoUrl: map['logo_url'] as String?,
      bannerUrl: map['banner_url'] as String?,
      address: map['address'] as String?,
      contactPhone: map['contact_phone'] as String?,
      businessHours: map['business_hours'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
