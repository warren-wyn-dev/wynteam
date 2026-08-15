import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wyn/features/zoky/data/cart_item.dart';
import 'package:wyn/features/zoky/data/category.dart';
import 'package:wyn/features/zoky/data/order.dart';
import 'package:wyn/features/zoky/data/order_item.dart';
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
    List<Product>? searchProductResults,
    List<Store>? searchStoreResults,
    List<CartItem>? cartItems,
    this.marketplaceFeePercent = 10,
    List<String>? createOrdersResult,
    this.createOrdersException,
    this.cancelOrderException,
    this.confirmOrderReceivedException,
    List<Order>? orders,
    this.order,
    List<OrderItem>? orderItems,
  })  : categories = categories ?? [],
        newProducts = newProducts ?? [],
        recommendedStores = recommendedStores ?? [],
        gridProducts = gridProducts ?? [],
        storeProducts = storeProducts ?? [],
        productVariants = productVariants ?? [],
        searchProductResults = searchProductResults ?? [],
        searchStoreResults = searchStoreResults ?? [],
        cartItems = cartItems ?? [],
        createOrdersResult = createOrdersResult ?? [],
        orders = orders ?? [],
        orderItems = orderItems ?? [],
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

  /// Returned by [searchProducts] for page 0 only (page 1+ returns empty).
  final List<Product> searchProductResults;

  /// Returned by [searchStores] for page 0 only (page 1+ returns empty).
  final List<Store> searchStoreResults;

  /// The arguments [searchProducts] was last called with -- lets tests
  /// assert the filter/sort/category state was actually passed through.
  String? lastSearchProductsQuery;
  String? lastSearchProductsCategoryId;
  double? lastSearchProductsMinPrice;
  double? lastSearchProductsMaxPrice;
  ProductSortBy? lastSearchProductsSortBy;

  String? lastSearchStoresQuery;

  // -- Cart (ZOKY-003) --------------------------------------------------

  /// Mutable so tests can assert [fetchCartItems] reflects an add/
  /// remove/quantity-change the test triggered through the widget.
  final List<CartItem> cartItems;

  String? lastAddToCartProductId;
  String? lastAddToCartVariantSelection;
  int? lastAddToCartQuantity;

  String? lastUpdateCartItemQuantityId;
  int? lastUpdateCartItemQuantityValue;

  String? lastRemoveCartItemId;

  double marketplaceFeePercent;

  // -- Order (ZOKY-003) --------------------------------------------------

  /// Returned by [createOrders] on success.
  final List<String> createOrdersResult;

  /// Thrown by [createOrders] when set (e.g.
  /// `InsufficientStockException('เสื้อยืด')`), instead of returning
  /// [createOrdersResult].
  final Exception? createOrdersException;

  final Exception? cancelOrderException;
  final Exception? confirmOrderReceivedException;

  String? lastCreateOrdersRecipientName;
  String? lastCreateOrdersRecipientPhone;
  String? lastCreateOrdersShippingAddress;

  String? lastCancelOrderId;
  String? lastConfirmOrderReceivedId;

  /// When set, [createOrders] awaits this instead of resolving/throwing
  /// immediately -- lets a test control exactly when the call completes
  /// (e.g. via a Completer) to assert the submit button's disabled/
  /// loading state mid-flight, not just before/after.
  Future<List<String>> Function()? createOrdersOverride;

  /// Returned by [fetchOrders] for page 0 only (page 1+ returns empty).
  final List<Order> orders;

  /// Returned by [fetchOrder] regardless of the id passed -- mirrors
  /// [store]/[product]'s single-value simplicity.
  final Order? order;

  final List<OrderItem> orderItems;

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

  @override
  Future<List<Product>> searchProducts({
    required String query,
    String? categoryId,
    double? minPrice,
    double? maxPrice,
    ProductSortBy sortBy = ProductSortBy.newest,
    required int page,
  }) async {
    lastSearchProductsQuery = query;
    lastSearchProductsCategoryId = categoryId;
    lastSearchProductsMinPrice = minPrice;
    lastSearchProductsMaxPrice = maxPrice;
    lastSearchProductsSortBy = sortBy;
    return page == 0 ? searchProductResults : [];
  }

  @override
  Future<List<Store>> searchStores({required String query, required int page}) async {
    lastSearchStoresQuery = query;
    return page == 0 ? searchStoreResults : [];
  }

  @override
  Future<List<CartItem>> fetchCartItems() async => cartItems;

  @override
  Future<void> addToCart({
    required String productId,
    String variantSelection = '',
    int quantity = 1,
  }) async {
    lastAddToCartProductId = productId;
    lastAddToCartVariantSelection = variantSelection;
    lastAddToCartQuantity = quantity;
  }

  @override
  Future<void> updateCartItemQuantity(String cartItemId, int quantity) async {
    lastUpdateCartItemQuantityId = cartItemId;
    lastUpdateCartItemQuantityValue = quantity;
  }

  @override
  Future<void> removeCartItem(String cartItemId) async {
    lastRemoveCartItemId = cartItemId;
  }

  @override
  Future<int> cartItemCount() async => cartItems.length;

  @override
  Future<double> fetchMarketplaceFeePercent() async => marketplaceFeePercent;

  @override
  Future<List<String>> createOrders({
    required String recipientName,
    required String recipientPhone,
    required String shippingAddress,
  }) async {
    lastCreateOrdersRecipientName = recipientName;
    lastCreateOrdersRecipientPhone = recipientPhone;
    lastCreateOrdersShippingAddress = shippingAddress;
    if (createOrdersOverride != null) return createOrdersOverride!();
    if (createOrdersException != null) throw createOrdersException!;
    return createOrdersResult;
  }

  @override
  Future<List<Order>> fetchOrders({required int page}) async => page == 0 ? orders : [];

  @override
  Future<Order?> fetchOrder(String orderId) async => order;

  @override
  Future<List<OrderItem>> fetchOrderItems(String orderId) async => orderItems;

  @override
  Future<void> cancelOrder(String orderId) async {
    lastCancelOrderId = orderId;
    if (cancelOrderException != null) throw cancelOrderException!;
  }

  @override
  Future<void> confirmOrderReceived(String orderId) async {
    lastConfirmOrderReceivedId = orderId;
    if (confirmOrderReceivedException != null) throw confirmOrderReceivedException!;
  }
}
