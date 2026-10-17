import '../domain/catalog_models.dart';

/// Read access to the store catalog.
///
/// Unlike app/ (concrete repositories + subclassed test doubles), ZOKY needs
/// two real implementations -- Supabase (ZOKY-106, calling the same
/// `food_store_directory` / `food_stores` / `food_menu_items` /
/// `food_menu_stock_remaining` the web uses) and Demo (the iPad web preview,
/// which has no backend) -- so this is an interface. See
/// .wyn/docs/engineering/zoky-app-architecture.md section 6.
abstract interface class StoreRepository {
  /// Web: fetchFoodStoreDirectory(client, query) -> food_store_directory.
  Future<List<ZokyStoreSummary>> fetchDirectory({String query = ''});

  /// Home "ร้านอาหารแนะนำ". Web: `food_active_featured_stores` (store_id +
  /// priority, admin-managed featured placements) mapped onto the
  /// directory in the order the RPC returns them; placements whose store is
  /// not in the directory (unpublished, hidden) are dropped. Empty when
  /// nothing is featured -- the web then hides its "ร้านแนะนำ" section.
  Future<List<ZokyStoreSummary>> fetchRecommended();

  /// Web: food_menu_items for one published store (+ stock remaining).
  Future<List<ZokyMenuItem>> fetchMenu(String storeId);
}
