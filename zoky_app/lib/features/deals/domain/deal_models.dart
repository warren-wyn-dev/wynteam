import '../../../core/format/money.dart';

/// Discount kind. Mirrors the web's `promo_type` (food_store_directory) and
/// `campaign_type` (food_platform_campaigns: 'percentage' | 'fixed' |
/// 'free_delivery'); [other] covers free-text promos such as "1 แถม 1",
/// which the web shows by name (foodPromoLabel falls back to promo_name).
enum ZokyDealType { percentage, fixed, freeDelivery, other }

/// Which code-drawn illustration a deal shows while there is no photo
/// (the repo has no food images). Replaced by [ZokyDeal.imagePath] later.
enum ZokyDealArt { bubbleTea, friedChicken, burger, noodleBowl }

/// A deal on the Home "ดีลเด็ดวันนี้" row.
///
/// Field mapping to the web data (see deals/data/promotion_repository.dart):
/// - [name], [type], [value], [minSubtotal]: `promo_name`, `promo_type`,
///   `promo_value`, `promo_min_subtotal` of `food_store_directory`
///   (= `name`, `campaign_type`, `discount_value`, `min_subtotal` of a
///   `food_platform_campaigns` row)
/// - [storeId], [storeName]: the directory store (`id`, `name`), or the
///   `store_id` of `food_platform_campaign_badges`
/// - [description]: `subtitle` of `food_active_home_banners` (short copy)
/// - [imagePath]: `image_path` of a home banner (`food-banners` bucket)
///
/// [isDemo] is true for every sample deal: the UI must then say so and must
/// never present it as a real promotion.
class ZokyDeal {
  const ZokyDeal({
    required this.id,
    required this.name,
    required this.type,
    required this.description,
    required this.art,
    this.value = 0,
    this.minSubtotal = 0,
    this.storeId,
    this.storeName,
    this.imagePath,
    this.isDemo = false,
  });

  final String id;
  final String name;
  final ZokyDealType type;
  final num value;
  final num minSubtotal;
  final String description;
  final ZokyDealArt art;
  final String? storeId;
  final String? storeName;
  final String? imagePath;
  final bool isDemo;

  /// Bold card headline, same rules as the web's foodPromoLabel().
  String get headline => switch (type) {
    ZokyDealType.freeDelivery => 'ส่งฟรี',
    ZokyDealType.percentage => 'ลด ${value % 1 == 0 ? value.toInt() : value}%',
    ZokyDealType.fixed => 'ลด ${formatBaht(value)}',
    ZokyDealType.other => name,
  };

  /// Web deal card copy: "เมื่อสั่งครบ ฿199", null when there is no minimum.
  String? get minimumLabel =>
      minSubtotal > 0 ? 'เมื่อสั่งครบ ${formatBaht(minSubtotal)}' : null;
}
