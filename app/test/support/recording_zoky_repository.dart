import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/zoky/data/category.dart';
import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/data/product_variant.dart';
import 'package:wyn/features/zoky/data/store.dart';
import 'package:wyn/features/zoky/data/zoky_repository.dart';

/// A ZokyRepository whose network-touching methods are overridden to just
/// return canned data instead of making a real Supabase call. Mirrors
/// RecordingClubRepository -- see .wyn/learning/PATTERNS.md.
class RecordingZokyRepository extends ZokyRepository {
  RecordingZokyRepository({
    List<Category>? categories,
    List<Product>? newProducts,
    List<Store>? recommendedStores,
    List<Product>? gridProducts,
    this.product,
    this.store,
    List<Product>? storeProducts,
    List<ProductVariant>? productVariants,
    this.storeProductCount = 0,
  })  : categories = categories ?? [],
        newProducts = newProducts ?? [],
        recommendedStores = recommendedStores ?? [],
        gridProducts = gridProducts ?? [],
        storeProducts = storeProducts ?? [],
        productVariants = productVariants ?? [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  final List<Category> categories;
  final List<Product> newProducts;
  final List<Store> recommendedStores;

  /// Returned by [fetchProducts] for page 0 only (page 1+ returns empty).
  final List<Product> gridProducts;

  final Product? product;
  final Store? store;
  final List<Product> storeProducts;
  final List<ProductVariant> productVariants;
  final int storeProductCount;

  @override
  Future<List<Category>> fetchCategories() async => categories;

  @override
  Future<List<Product>> fetchNewProducts({int limit = ZokyRepository.newProductsLimit}) async =>
      newProducts;

  @override
  Future<List<Store>> fetchRecommendedStores({
    int limit = ZokyRepository.recommendedStoresLimit,
  }) async =>
      recommendedStores;

  @override
  Future<List<Product>> fetchProducts({required int page}) async =>
      page == 0 ? gridProducts : [];

  @override
  Future<Product?> fetchProduct(String productId) async => product;

  @override
  Future<Store?> fetchStore(String storeId) async => store;

  @override
  Future<int> countStoreProducts(String storeId) async => storeProductCount;

  @override
  Future<List<Product>> fetchStoreProducts(String storeId) async => storeProducts;

  @override
  Future<List<ProductVariant>> fetchProductVariants(String productId) async =>
      productVariants;
}
