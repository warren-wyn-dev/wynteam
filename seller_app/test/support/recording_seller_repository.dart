import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zoky_seller/features/order/data/order.dart';
import 'package:zoky_seller/features/order/data/order_item.dart';
import 'package:zoky_seller/features/product/data/category.dart';
import 'package:zoky_seller/features/product/data/product.dart';
import 'package:zoky_seller/features/product/data/product_variant.dart';
import 'package:zoky_seller/features/store/data/seller_repository.dart';
import 'package:zoky_seller/features/store/data/store.dart';

/// A SellerRepository whose network-touching methods are overridden to
/// just return canned data instead of making a real Supabase call.
/// Mirrors RecordingZokyRepository (ZOKY Marketplace,
/// `app/test/support/recording_zoky_repository.dart`) -- see
/// .wyn/learning/PATTERNS.md.
class RecordingSellerRepository extends SellerRepository {
  RecordingSellerRepository({
    this.myStore,
    this.createStoreResult,
    this.createStoreException,
    this.orderCounts = (0, 0),
    this.salesSummary = (0.0, 0.0, 0.0),
    List<(String, int)>? bestSellingProducts,
    List<Category>? categories,
    List<Product>? products,
    List<ProductVariant>? productVariants,
    this.createProductResult,
    this.createProductException,
    this.updateProductResult,
    this.updateProductException,
    this.setProductActiveException,
    this.adjustProductStockResult = 0,
    this.adjustProductStockException,
    this.adjustVariantStockResult = 0,
    this.adjustVariantStockException,
    List<Order>? storeOrders,
    this.storeOrder,
    List<OrderItem>? storeOrderItems,
    this.sellerStartProcessingException,
    this.sellerMarkReadyToShipException,
    this.sellerShipOrderException,
    this.sellerCancelOrderException,
    this.sellerMarkRefundedException,
  })  : bestSellingProducts = bestSellingProducts ?? const [],
        categories = categories ?? const [],
        products = products ?? const [],
        productVariants = productVariants ?? const [],
        storeOrders = storeOrders ?? const [],
        storeOrderItems = storeOrderItems ?? const [],
        super(SupabaseClient('https://example.supabase.co', 'test-key'));

  final Store? myStore;
  final Store? createStoreResult;
  final Object? createStoreException;
  final (int, int) orderCounts;
  final (double, double, double) salesSummary;
  final List<(String, int)> bestSellingProducts;

  int createStoreCalls = 0;
  final List<String> createStoreNameArgs = [];
  final List<String?> createStoreDescriptionArgs = [];

  @override
  Future<Store?> fetchMyStore() async => myStore;

  @override
  Future<Store> createStore({required String name, String? description}) async {
    createStoreCalls++;
    createStoreNameArgs.add(name);
    createStoreDescriptionArgs.add(description);
    if (createStoreException != null) throw createStoreException!;
    return createStoreResult ??
        Store(
          id: 'new-store',
          ownerId: 'u1',
          name: name,
          description: description,
          createdAt: DateTime(2026, 1, 1),
        );
  }

  @override
  Future<(int, int)> fetchOrderCounts(String storeId) async => orderCounts;

  @override
  Future<(double, double, double)> fetchSalesSummary(String storeId) async =>
      salesSummary;

  @override
  Future<List<(String, int)>> fetchBestSellingProducts(
    String storeId, {
    int limit = 5,
  }) async =>
      bestSellingProducts.take(limit).toList();

  // -- Product Management (SELLER-002) -----------------------------------

  final List<Category> categories;

  /// Returned by [fetchProducts] for page 0 only (page 1+ returns
  /// empty) -- filter/query/store args are recorded below rather than
  /// actually applied, same simplification RecordingZokyRepository
  /// already uses for its own search methods.
  final List<Product> products;

  final List<ProductVariant> productVariants;

  ProductStatusFilter? lastFetchProductsFilter;
  String? lastFetchProductsQuery;
  String? lastFetchProductsStoreId;

  final Product? createProductResult;
  final Object? createProductException;
  int createProductCalls = 0;

  final Product? updateProductResult;
  final Object? updateProductException;
  int updateProductCalls = 0;
  List<VariantInput>? lastUpdateProductVariants;

  final Object? setProductActiveException;
  String? lastSetProductActiveId;
  bool? lastSetProductActiveValue;

  final int adjustProductStockResult;
  final Object? adjustProductStockException;
  String? lastAdjustProductStockId;
  int? lastAdjustProductStockDelta;

  final int adjustVariantStockResult;
  final Object? adjustVariantStockException;
  String? lastAdjustVariantStockId;
  int? lastAdjustVariantStockDelta;

  @override
  Future<List<Category>> fetchCategories() async => categories;

  @override
  Future<List<ProductVariant>> fetchProductVariants(String productId) async =>
      productVariants;

  @override
  Future<List<Product>> fetchProducts({
    required String storeId,
    ProductStatusFilter filter = ProductStatusFilter.all,
    String query = '',
    required int page,
  }) async {
    lastFetchProductsFilter = filter;
    lastFetchProductsQuery = query;
    lastFetchProductsStoreId = storeId;
    return page == 0 ? products : [];
  }

  @override
  Future<Product> createProduct({
    required String storeId,
    required String name,
    required double price,
    double? originalPrice,
    String? categoryId,
    String? description,
    String? sku,
    required int initialStock,
    required List<Uint8List> images,
    required List<String> imageExtensions,
    List<VariantInput> variants = const [],
  }) async {
    createProductCalls++;
    if (createProductException != null) throw createProductException!;
    return createProductResult ??
        Product(
          id: 'new-product',
          storeId: storeId,
          storeName: '',
          name: name,
          price: price,
          originalPrice: originalPrice,
          stock: initialStock,
          imageUrls: const ['https://example.supabase.co/products/new.jpg'],
          isActive: true,
          sku: sku,
          createdAt: DateTime(2026, 1, 1),
        );
  }

  @override
  Future<Product> updateProduct({
    required String productId,
    required String name,
    required double price,
    double? originalPrice,
    String? categoryId,
    String? description,
    String? sku,
    required List<String> imageUrls,
    required List<Uint8List> newImages,
    required List<String> newImageExtensions,
    List<VariantInput> variants = const [],
  }) async {
    updateProductCalls++;
    lastUpdateProductVariants = variants;
    if (updateProductException != null) throw updateProductException!;
    return updateProductResult ??
        Product(
          id: productId,
          storeId: 'store-1',
          storeName: '',
          name: name,
          price: price,
          originalPrice: originalPrice,
          stock: 0,
          imageUrls: imageUrls.isEmpty
              ? const ['https://example.supabase.co/products/p1.jpg']
              : imageUrls,
          isActive: true,
          sku: sku,
          createdAt: DateTime(2026, 1, 1),
        );
  }

  @override
  Future<void> setProductActive(String productId, bool isActive) async {
    lastSetProductActiveId = productId;
    lastSetProductActiveValue = isActive;
    if (setProductActiveException != null) throw setProductActiveException!;
  }

  @override
  Future<int> adjustProductStock(String productId, int delta) async {
    lastAdjustProductStockId = productId;
    lastAdjustProductStockDelta = delta;
    if (adjustProductStockException != null) throw adjustProductStockException!;
    return adjustProductStockResult;
  }

  @override
  Future<int> adjustVariantStock(String variantId, int delta) async {
    lastAdjustVariantStockId = variantId;
    lastAdjustVariantStockDelta = delta;
    if (adjustVariantStockException != null) throw adjustVariantStockException!;
    return adjustVariantStockResult;
  }

  // -- Order Management (SELLER-003) ---------------------------------------

  /// Returned by [fetchStoreOrders] for page 0 only (page 1+ returns
  /// empty) -- filter/store args are recorded below rather than
  /// actually applied, same simplification [fetchProducts] above uses.
  final List<Order> storeOrders;

  /// Returned by [fetchStoreOrder] regardless of the id passed.
  final Order? storeOrder;

  final List<OrderItem> storeOrderItems;

  String? lastFetchStoreOrdersStoreId;
  OrderStatus? lastFetchStoreOrdersFilter;

  final Object? sellerStartProcessingException;
  int sellerStartProcessingCalls = 0;
  String? lastSellerStartProcessingId;

  final Object? sellerMarkReadyToShipException;
  int sellerMarkReadyToShipCalls = 0;
  String? lastSellerMarkReadyToShipId;

  final Object? sellerShipOrderException;
  int sellerShipOrderCalls = 0;
  String? lastSellerShipOrderId;
  String? lastSellerShipOrderProvider;
  String? lastSellerShipOrderTracking;

  final Object? sellerCancelOrderException;
  int sellerCancelOrderCalls = 0;
  String? lastSellerCancelOrderId;

  final Object? sellerMarkRefundedException;
  int sellerMarkRefundedCalls = 0;
  String? lastSellerMarkRefundedId;

  @override
  Future<List<Order>> fetchStoreOrders({
    required String storeId,
    OrderStatus? filter,
    required int page,
  }) async {
    lastFetchStoreOrdersStoreId = storeId;
    lastFetchStoreOrdersFilter = filter;
    return page == 0 ? storeOrders : [];
  }

  @override
  Future<Order?> fetchStoreOrder(String orderId) async => storeOrder;

  @override
  Future<List<OrderItem>> fetchStoreOrderItems(String orderId) async => storeOrderItems;

  @override
  Future<void> sellerStartProcessing(String orderId) async {
    sellerStartProcessingCalls++;
    lastSellerStartProcessingId = orderId;
    if (sellerStartProcessingException != null) throw sellerStartProcessingException!;
  }

  @override
  Future<void> sellerMarkReadyToShip(String orderId) async {
    sellerMarkReadyToShipCalls++;
    lastSellerMarkReadyToShipId = orderId;
    if (sellerMarkReadyToShipException != null) throw sellerMarkReadyToShipException!;
  }

  @override
  Future<void> sellerShipOrder(
    String orderId,
    String shippingProvider,
    String trackingNumber,
  ) async {
    sellerShipOrderCalls++;
    lastSellerShipOrderId = orderId;
    lastSellerShipOrderProvider = shippingProvider;
    lastSellerShipOrderTracking = trackingNumber;
    if (sellerShipOrderException != null) throw sellerShipOrderException!;
  }

  @override
  Future<void> sellerCancelOrder(String orderId) async {
    sellerCancelOrderCalls++;
    lastSellerCancelOrderId = orderId;
    if (sellerCancelOrderException != null) throw sellerCancelOrderException!;
  }

  @override
  Future<void> sellerMarkRefunded(String orderId) async {
    sellerMarkRefundedCalls++;
    lastSellerMarkRefundedId = orderId;
    if (sellerMarkRefundedException != null) throw sellerMarkRefundedException!;
  }
}
