import 'package:supabase_flutter/supabase_flutter.dart';

import 'category.dart';
import 'product.dart';
import 'product_variant.dart';
import 'store.dart';

const _productSelect = '*, store:stores(name), category:categories(name)';

enum ProductSortBy { newest, priceLowToHigh, priceHighToLow }

/// Wraps the read-only `categories`/`stores`/`products`/`product_variants`
/// reads needed for ZOKY-001 (Marketplace Foundation, browse-only). No
/// insert/update/delete here -- there's no Seller workflow yet to write
/// through (see supabase/schema.sql, ZOKY-001 section).
class ZokyRepository {
  ZokyRepository(this._client);

  final SupabaseClient _client;

  static const newProductsLimit = 10;
  static const recommendedStoresLimit = 10;
  static const gridPageSize = 20;
  static const searchPageSize = 20;

  Future<List<Category>> fetchCategories() async {
    final rows =
        await _client.from('categories').select().order('name', ascending: true);
    return rows.map(Category.fromMap).toList();
  }

  Future<int> countStoreProducts(String storeId) {
    return _client.from('products').count(CountOption.exact).eq('store_id', storeId);
  }

  Future<Store?> fetchStore(String storeId) async {
    final row =
        await _client.from('stores').select().eq('id', storeId).maybeSingle();
    if (row == null) return null;
    final productCount = await countStoreProducts(storeId);
    return Store.fromMap(row, productCount: productCount);
  }

  Future<List<Store>> fetchRecommendedStores({int limit = recommendedStoresLimit}) async {
    final rows = await _client
        .from('stores')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    final stores = <Store>[];
    for (final row in rows) {
      final productCount = await countStoreProducts(row['id'] as String);
      stores.add(Store.fromMap(row, productCount: productCount));
    }
    return stores;
  }

  Future<Product?> fetchProduct(String productId) async {
    final row = await _client
        .from('products')
        .select(_productSelect)
        .eq('id', productId)
        .maybeSingle();
    if (row == null) return null;
    return Product.fromMap(row);
  }

  Future<List<Product>> fetchNewProducts({int limit = newProductsLimit}) async {
    final rows = await _client
        .from('products')
        .select(_productSelect)
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Product.fromMap).toList();
  }

  /// The main ZOKY Home product grid -- newest first, paginated.
  Future<List<Product>> fetchProducts({required int page}) async {
    final from = page * gridPageSize;
    final to = from + gridPageSize - 1;
    final rows = await _client
        .from('products')
        .select(_productSelect)
        .order('created_at', ascending: false)
        .range(from, to);
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> fetchStoreProducts(String storeId) async {
    final rows = await _client
        .from('products')
        .select(_productSelect)
        .eq('store_id', storeId)
        .order('created_at', ascending: false);
    return rows.map(Product.fromMap).toList();
  }

  Future<List<ProductVariant>> fetchProductVariants(String productId) async {
    final rows = await _client
        .from('product_variants')
        .select()
        .eq('product_id', productId)
        .order('variant_type', ascending: true);
    return rows.map(ProductVariant.fromMap).toList();
  }

  /// Products whose name contains [query] (case insensitive), optionally
  /// filtered by category/price range and sorted -- for ZOKY-002's
  /// ZokySearchScreen. `.ilike()` called directly (not folded into an
  /// `.or()` filter DSL string) so the query is parameterized safely by
  /// the query builder, same as ClubRepository.searchClubs (WYN-015).
  Future<List<Product>> searchProducts({
    required String query,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    ProductSortBy sortBy = ProductSortBy.newest,
    required int page,
  }) async {
    final from = page * searchPageSize;
    final to = from + searchPageSize - 1;

    var filtered = _client.from('products').select(_productSelect).ilike('name', '%$query%');
    if (categoryId != null) filtered = filtered.eq('category_id', categoryId);
    if (minPrice != null) filtered = filtered.gte('price', minPrice);
    if (maxPrice != null) filtered = filtered.lte('price', maxPrice);

    final ordered = switch (sortBy) {
      ProductSortBy.newest => filtered.order('created_at', ascending: false),
      ProductSortBy.priceLowToHigh => filtered.order('price', ascending: true),
      ProductSortBy.priceHighToLow => filtered.order('price', ascending: false),
    };

    final rows = await ordered.range(from, to);
    return rows.map(Product.fromMap).toList();
  }

  /// Stores whose name contains [query] (case insensitive), newest first --
  /// for ZOKY-002's Store search tab. Stores have no category column, so
  /// unlike searchProducts there's no category filter here.
  Future<List<Store>> searchStores({required String query, required int page}) async {
    final from = page * searchPageSize;
    final to = from + searchPageSize - 1;

    final rows = await _client
        .from('stores')
        .select()
        .ilike('name', '%$query%')
        .order('created_at', ascending: false)
        .range(from, to);

    final stores = <Store>[];
    for (final row in rows) {
      final productCount = await countStoreProducts(row['id'] as String);
      stores.add(Store.fromMap(row, productCount: productCount));
    }
    return stores;
  }
}
