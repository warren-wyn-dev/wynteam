import '../domain/deal_models.dart';

/// Read access to the deals shown on Home ("ดีลเด็ดวันนี้").
///
/// Same pattern as StoreRepository: an interface with a Demo
/// implementation now and a Supabase one later, built from what the web
/// already reads:
/// - `food_store_directory` rows with `promo_name` (web "fx-deal" cards:
///   promoStores in wynos-food-developer-app.tsx)
/// - `food_platform_campaign_badges` (store_id, campaign_name)
/// - `food_active_home_banners` (title, subtitle, image_path,
///   destination_store_id)
/// The server decides which deals are live; the app only displays them.
abstract interface class PromotionRepository {
  Future<List<ZokyDeal>> fetchTodayDeals();
}
