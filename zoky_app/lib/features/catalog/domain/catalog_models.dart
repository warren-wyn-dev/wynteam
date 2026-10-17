/// Store as shown on a store card. Mirrors the subset of the web's
/// `FoodDirectoryStore` (food_store_directory RPC) that the card renders;
/// the Supabase mapping (num | string money parsing, public cover URL from
/// the `food-public` bucket) arrives with SupabaseStoreRepository (ZOKY-106).
class ZokyStoreSummary {
  const ZokyStoreSummary({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.deliveryFee,
    required this.etaMinMinutes,
    required this.etaMaxMinutes,
    this.coverUrl,
    this.isAd = false,
    this.promoLabel,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.distanceKm,
    this.categories = const [],
    this.minimumOrder = 0,
  });

  final String id;
  final String name;
  final bool isOpen;
  final num deliveryFee;
  final int etaMinMinutes;
  final int etaMaxMinutes;
  final String? coverUrl;
  final bool isAd;

  /// Already-formatted promo text (web: foodPromoLabel), e.g. "ลด 20%".
  final String? promoLabel;
  final double ratingAverage;
  final int ratingCount;
  final double? distanceKm;
  final List<String> categories;
  final num minimumOrder;

  bool get hasPromo => promoLabel != null && promoLabel!.isNotEmpty;
  bool get isNew => ratingAverage <= 0;
}

/// Menu item as shown in a store's menu list. Mirrors the subset of the
/// web's `FoodCustomerMenuItem` the row renders.
class ZokyMenuItem {
  const ZokyMenuItem({
    required this.id,
    required this.storeId,
    required this.category,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.isAvailable = true,
    this.remainingStock,
  });

  final String id;
  final String storeId;
  final String category;
  final String name;
  final String? description;
  final num price;
  final String? imageUrl;
  final bool isAvailable;

  /// null = unlimited (web: remaining_stock).
  final int? remainingStock;

  bool get isSoldOut =>
      !isAvailable || (remainingStock != null && remainingStock! <= 0);
}
