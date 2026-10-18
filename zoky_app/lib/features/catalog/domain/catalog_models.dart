import '../../deals/domain/deal_models.dart';

/// Store as shown on a store card. Mirrors the subset of the web's
/// `FoodDirectoryStore` (food_store_directory RPC) that the card renders;
/// the Supabase mapping (num | string money parsing, public cover URL from
/// the `food-public` bucket) arrives with SupabaseStoreRepository (ZOKY-106).
///
/// Rating and delivery time are shown only when the data is real
/// (Founder rule):
/// - [ratingAverage] / [ratingCount]: `rating_average` / `rating_count` of
///   `food_store_directory` (the server aggregate of the store's published
///   reviews, the same numbers `food_store_review_feed` returns as
///   `average` / `count`). The web parses them with `Number(x ?? 0)`, so
///   "no reviews" arrives as 0; [rating] turns that into null.
/// - [etaMinMinutes] / [etaMaxMinutes]: the web's
///   `foodEstimateDeliveryRange(store, distance)` -- the store's
///   `prep_time_min_minutes` / `prep_time_max_minutes` plus travel time from
///   the distance (`food_delivery_availability.distance_km`, ~22 km/h + 5
///   min). The web falls back to 15/30 when the store has not set a prep
///   time; ZOKY keeps null instead so no guessed time is shown.
class ZokyStoreSummary {
  const ZokyStoreSummary({
    required this.id,
    required this.name,
    required this.isOpen,
    required this.deliveryFee,
    this.etaMinMinutes,
    this.etaMaxMinutes,
    this.coverUrl,
    this.coverArt,
    this.isDemo = false,
    this.isAd = false,
    this.promoLabel,
    this.promoName,
    this.promoMinSubtotal = 0,
    this.promoFreeDelivery = false,
    this.ratingAverage = 0,
    this.ratingCount = 0,
    this.distanceKm,
    this.categories = const [],
    this.minimumOrder = 0,
    this.supportsPickup = false,
  });

  final String id;
  final String name;
  final bool isOpen;
  final num deliveryFee;

  /// null = no reliable estimate (see the class doc).
  final int? etaMinMinutes;
  final int? etaMaxMinutes;

  /// Cover photo: an http(s) URL (web: public URL of `cover_path` in the
  /// `food-public` bucket) or a bundled asset path. Wins over [coverArt].
  final String? coverUrl;

  /// Code-drawn cover used while there is no photo (demo data; the repo
  /// has no food images). Shares the deal illustrations.
  final ZokyDealArt? coverArt;

  /// Sample store (demo mode): the UI must label it as such.
  final bool isDemo;
  final bool isAd;

  /// Already-formatted promo text (web: foodPromoLabel), e.g. "ลด 20%".
  final String? promoLabel;

  /// Merchant's promo name (web: `promo_name`), shown under the promo
  /// label on a coupon card when there is no minimum order.
  final String? promoName;

  /// Minimum subtotal for the promo (web: `promo_min_subtotal`); 0 = none.
  final num promoMinSubtotal;

  /// The promo is free delivery (web: `promo_type == "free_delivery"`):
  /// bike icon on the coupon card; not offered in pickup mode.
  final bool promoFreeDelivery;
  final double ratingAverage;
  final int ratingCount;
  final double? distanceKm;
  final List<String> categories;
  final num minimumOrder;

  /// The store accepts "รับเองที่ร้าน" orders (Founder decision "ค",
  /// 2026-10-18). OPEN CONTRACT ITEM: the web directory has no such field
  /// yet (the web is delivery only); the backend field is TBD with the
  /// pickup backend task. Defaults to false so no store claims pickup
  /// without data.
  final bool supportsPickup;

  bool get hasPromo => promoLabel != null && promoLabel!.isNotEmpty;
  bool get isNew => ratingAverage <= 0;

  /// Average review score, or null when the store has no reviews yet.
  double? get rating =>
      ratingCount > 0 && ratingAverage > 0 ? ratingAverage : null;

  /// Both ends of the delivery estimate are known.
  bool get hasEta => etaMinMinutes != null && etaMaxMinutes != null;

  /// Suffix carried by every demo store name, so a sample store is labelled
  /// on every screen that shows its name.
  static const String demoNameSuffix = ' (ร้านตัวอย่าง)';

  /// [name] without [demoNameSuffix], for cards that show a separate
  /// "ตัวอย่าง" badge instead.
  String get nameWithoutDemoSuffix => name.endsWith(demoNameSuffix)
      ? name.substring(0, name.length - demoNameSuffix.length)
      : name;
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
