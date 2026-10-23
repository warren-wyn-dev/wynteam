import '../domain/home_content_models.dart';

/// Read access to Home/food page content managed outside a store (banners,
/// categories). Same interface + Demo pattern as StoreRepository; the
/// Supabase implementation arrives with ZOKY-105/106.
abstract interface class HomeContentRepository {
  /// Home carousel banners. Web: `food_active_home_banners()` (anon +
  /// authenticated), images from the public `food-banners` bucket. Empty
  /// when there are none or the call fails, like the web.
  Future<List<ZokyHomeBanner>> fetchActiveBanners();

  /// Home food category circles, in display order. No web source yet (see
  /// [ZokyFoodCategory]); demo data until the list is decided.
  Future<List<ZokyFoodCategory>> fetchFoodCategories();
}
