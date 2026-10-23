import '../../catalog/domain/catalog_models.dart';
import '../../deals/domain/deal_models.dart';

/// A Home carousel banner. Mirrors one row of the web's
/// `food_active_home_banners` RPC (web/lib/food-home-banners.ts,
/// `FoodHomeBanner`), whose source table is `food_home_banners`:
/// - [id], [title], [subtitle]: `id`, `title` (2-90 chars), `subtitle`
///   (<= 180 chars, nullable)
/// - [imagePath]: `image_path` in the public `food-banners` bucket
///   (`banners/<uuid>.png|jpg|jpeg|webp`)
/// - [destinationStoreId]: `destination_store_id` (nullable; the web makes
///   the banner a button only when that store is in the directory)
/// - [sortOrder], [startsAt], [endsAt]: `sort_order`, `starts_at`,
///   `ends_at` of the table. The RPC already returns only active banners
///   inside their window, ordered by `sort_order, created_at desc`, max 8;
///   the app keeps the fields so the demo data obeys the same rules.
///
/// App-only fields (not in the web RPC yet):
/// - [dealId]: opens a deal sheet instead of a store. The web banner has
///   no promo target; only demo banners use it (open question for the
///   Supabase mapping).
/// - [art]: code-drawn illustration while there is no [imagePath] photo.
/// - [isDemo]: sample banner; the UI must label it "ตัวอย่าง".
class ZokyHomeBanner {
  const ZokyHomeBanner({
    required this.id,
    required this.title,
    this.subtitle,
    this.imagePath,
    this.destinationStoreId,
    this.dealId,
    this.art,
    this.sortOrder = 100,
    this.startsAt,
    this.endsAt,
    this.isDemo = false,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? imagePath;
  final String? destinationStoreId;
  final String? dealId;
  final ZokyDealArt? art;
  final int sortOrder;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final bool isDemo;

  /// Same window rule as the RPC: started and not yet ended.
  bool isActiveAt(DateTime now) =>
      (startsAt == null || !startsAt!.isAfter(now)) &&
      (endsAt == null || endsAt!.isAfter(now));

  /// What a tap opens: a store first (the web's only target), then a deal.
  bool get hasTarget => destinationStoreId != null || dealId != null;
}

/// A food category circle on Home ("ตามสั่ง", "ก๋วยเตี๋ยว", ...).
///
/// The web has no curated category list: each directory store carries
/// `categories` (food_store_directory = the distinct `category` values of
/// the store's menu items, free text set by the merchant), and its
/// filters (parity C04) run client-side on directory rows. A category here
/// is therefore a label plus the menu-category words it stands for;
/// [matches] runs client-side on the same directory rows.
class ZokyFoodCategory {
  const ZokyFoodCategory({
    required this.id,
    required this.label,
    required this.art,
    required this.terms,
  });

  final String id;
  final String label;
  final ZokyDealArt art;

  /// Menu-category words (substring, case-insensitive) of this category.
  final List<String> terms;

  /// True when any of the store's menu categories contains a [terms] word.
  bool matches(ZokyStoreSummary store) => store.categories.any((category) {
    final value = category.toLowerCase();
    return terms.any((term) => value.contains(term.toLowerCase()));
  });
}
