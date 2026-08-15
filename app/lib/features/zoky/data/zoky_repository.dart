import 'package:supabase_flutter/supabase_flutter.dart';

import 'cart_item.dart';
import 'category.dart';
import 'order.dart';
import 'order_item.dart';
import 'product.dart';
import 'product_variant.dart';
import 'review.dart';
import 'store.dart';

const _productSelect = '*, store:stores(name), category:categories(name)';
const _reviewAuthorSelect = 'author:profiles(username, display_name, avatar_url)';

enum ProductSortBy { newest, priceLowToHigh, priceHighToLow }

/// Thrown by [ZokyRepository.createOrders] when create_orders() (see
/// supabase/schema.sql, ZOKY-003 section) rejects the checkout because
/// a product's current stock can't cover the quantity in the cart --
/// parsed from the RPC's 'INSUFFICIENT_STOCK:<name>' exception message
/// so the UI can name the specific product instead of a vague error.
class InsufficientStockException implements Exception {
  const InsufficientStockException(this.productName);
  final String productName;
}

/// Wraps the read-only `categories`/`stores`/`products`/`product_variants`
/// reads needed for ZOKY-001 (Marketplace Foundation, browse-only). No
/// insert/update/delete here -- there's no Seller workflow yet to write
/// through (see supabase/schema.sql, ZOKY-001 section).
///
/// SELLER-002 note: every read below that lists/shows products to a
/// buyer now filters `is_active = true` at the query level, not via
/// RLS -- `products`' select policy is select-all-authenticated and
/// stays that way, shared by both this repository and
/// seller_app/'s SellerRepository (which *needs* to see a seller's own
/// inactive products in their product list). `is_active` defaults to
/// `true` (see supabase/schema.sql), so every pre-existing product row
/// is unaffected and every ZOKY-001/ZOKY-002 test/behavior stays
/// identical -- see .wyn/tasks/backlog/SELLER-002-product-management.md,
/// Requirements #6.
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
    return _client
        .from('products')
        .count(CountOption.exact)
        .eq('store_id', storeId)
        .eq('is_active', true);
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
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) return null;
    return Product.fromMap(row);
  }

  Future<List<Product>> fetchNewProducts({int limit = newProductsLimit}) async {
    final rows = await _client
        .from('products')
        .select(_productSelect)
        .eq('is_active', true)
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
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .range(from, to);
    return rows.map(Product.fromMap).toList();
  }

  Future<List<Product>> fetchStoreProducts(String storeId) async {
    final rows = await _client
        .from('products')
        .select(_productSelect)
        .eq('store_id', storeId)
        .eq('is_active', true)
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

    var filtered = _client
        .from('products')
        .select(_productSelect)
        .ilike('name', '%$query%')
        .eq('is_active', true);
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

  // -- Cart (ZOKY-003) -------------------------------------------------
  //
  // Plain per-row CRUD scoped by RLS to the caller's own cart_items --
  // no RPC needed here, unlike orders below, since nothing about the
  // cart itself is security/atomicity-critical (the stock a checkout
  // actually needs is re-checked server-side in create_orders()).

  static const ordersPageSize = 20;

  Future<List<CartItem>> fetchCartItems() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('cart_items')
        .select('*, product:products($_productSelect)')
        .eq('user_id', userId)
        .order('created_at', ascending: true);
    return rows.map(CartItem.fromMap).toList();
  }

  /// Adds [quantity] of [productId]/[variantSelection] to the caller's
  /// cart, incrementing the existing line's quantity instead of
  /// inserting a duplicate row when one already exists for the same
  /// product+variant combination (see cart_items_unique_line in
  /// supabase/schema.sql).
  Future<void> addToCart({
    required String productId,
    String variantSelection = '',
    int quantity = 1,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final existing = await _client
        .from('cart_items')
        .select('id, quantity')
        .eq('user_id', userId)
        .eq('product_id', productId)
        .eq('variant_selection', variantSelection)
        .maybeSingle();

    if (existing == null) {
      await _client.from('cart_items').insert({
        'user_id': userId,
        'product_id': productId,
        'variant_selection': variantSelection,
        'quantity': quantity,
      });
    } else {
      await _client
          .from('cart_items')
          .update({'quantity': (existing['quantity'] as int) + quantity})
          .eq('id', existing['id'] as String);
    }
  }

  Future<void> updateCartItemQuantity(String cartItemId, int quantity) {
    return _client.from('cart_items').update({'quantity': quantity}).eq('id', cartItemId);
  }

  Future<void> removeCartItem(String cartItemId) {
    return _client.from('cart_items').delete().eq('id', cartItemId);
  }

  /// Number of distinct cart line items (not the summed quantity) --
  /// what the Cart icon badge on ZOKY Home shows, same convention as
  /// most cart badges.
  Future<int> cartItemCount() {
    final userId = _client.auth.currentUser!.id;
    return _client.from('cart_items').count(CountOption.exact).eq('user_id', userId);
  }

  // -- Checkout & Order (ZOKY-003) --------------------------------------
  //
  // Every write here goes through a security-definer RPC (see
  // supabase/schema.sql) -- orders/order_items have no client-facing
  // insert/update policy at all.

  /// Checks out every item currently in the caller's cart, atomically,
  /// grouped into one Order per store server-side. Throws
  /// [InsufficientStockException] when a product's current stock can't
  /// cover the requested quantity.
  Future<List<String>> createOrders({
    required String recipientName,
    required String recipientPhone,
    required String shippingAddress,
  }) async {
    try {
      final result = await _client.rpc('create_orders', params: {
        'p_recipient_name': recipientName,
        'p_recipient_phone': recipientPhone,
        'p_shipping_address': shippingAddress,
      });
      return (result as List).cast<String>();
    } on PostgrestException catch (e) {
      const prefix = 'INSUFFICIENT_STOCK:';
      if (e.message.startsWith(prefix)) {
        throw InsufficientStockException(e.message.substring(prefix.length));
      }
      rethrow;
    }
  }

  Future<List<Order>> fetchOrders({required int page}) async {
    final userId = _client.auth.currentUser!.id;
    final from = page * ordersPageSize;
    final to = from + ordersPageSize - 1;
    final rows = await _client
        .from('orders')
        .select('*, store:stores(name)')
        .eq('buyer_id', userId)
        .order('created_at', ascending: false)
        .range(from, to);
    return rows.map(Order.fromMap).toList();
  }

  Future<Order?> fetchOrder(String orderId) async {
    final row = await _client
        .from('orders')
        .select('*, store:stores(name)')
        .eq('id', orderId)
        .maybeSingle();
    if (row == null) return null;
    return Order.fromMap(row);
  }

  Future<List<OrderItem>> fetchOrderItems(String orderId) async {
    final rows = await _client.from('order_items').select().eq('order_id', orderId);
    return rows.map(OrderItem.fromMap).toList();
  }

  Future<void> cancelOrder(String orderId) {
    return _client.rpc('cancel_order', params: {'p_order_id': orderId});
  }

  Future<void> confirmOrderReceived(String orderId) {
    return _client.rpc('confirm_order_received', params: {'p_order_id': orderId});
  }

  /// The current marketplace fee percentage, for display only (e.g. the
  /// Checkout summary's estimated total before confirming) -- the
  /// authoritative value used to compute an Order's actual fee is
  /// re-read and snapshotted server-side by create_orders(), never
  /// trusted from a value the client held onto.
  Future<double> fetchMarketplaceFeePercent() async {
    final row = await _client
        .from('platform_config')
        .select('value')
        .eq('key', 'zoky_marketplace_fee_percent')
        .maybeSingle();
    if (row == null) return 10;
    return double.tryParse(row['value'] as String) ?? 10;
  }

  // -- Review (ZOKY-004) -------------------------------------------------
  //
  // Writes go through plain RLS, not an RPC -- unlike orders above, a
  // review is a single-table write with no multi-row business logic;
  // the "delivered order the caller actually owns" gate lives in the
  // insert policy itself (see supabase/schema.sql, ZOKY-004 section).
  // Ratings are never aggregated/cached here -- every read recomputes
  // avg()/count() client-side from the raw rows, per the Design spec's
  // warning against snapshotting (opposite principle from orders' fee).

  static const reviewsPageSize = 20;

  /// order_items the caller bought and had delivered for [productId],
  /// that don't have a review yet -- what ProductDetailScreen uses to
  /// decide its write-review entry point (open the form directly when
  /// there's exactly one, otherwise point at Order List; see the Design
  /// spec's decision on the repeat-purchase edge case).
  Future<List<OrderItem>> fetchReviewableOrderItems(String productId) async {
    final userId = _client.auth.currentUser!.id;
    final deliveredOrderRows = await _client
        .from('orders')
        .select('id')
        .eq('buyer_id', userId)
        .eq('status', 'delivered');
    final deliveredOrderIds = deliveredOrderRows.map((r) => r['id'] as String).toList();
    if (deliveredOrderIds.isEmpty) return [];

    final itemRows = await _client
        .from('order_items')
        .select()
        .eq('product_id', productId)
        .inFilter('order_id', deliveredOrderIds);
    final orderItems = itemRows.map(OrderItem.fromMap).toList();
    if (orderItems.isEmpty) return orderItems;

    final reviewedRows = await _client
        .from('reviews')
        .select('order_item_id')
        .inFilter('order_item_id', orderItems.map((item) => item.id).toList());
    final reviewedIds = reviewedRows.map((r) => r['order_item_id'] as String).toSet();

    return orderItems.where((item) => !reviewedIds.contains(item.id)).toList();
  }

  /// The review already written for [orderItemId], if any -- null means
  /// ZokyOrderDetailScreen should show "เขียนรีวิว" instead of
  /// "แก้ไขรีวิว" for that line item. order_item_id is unique on
  /// [reviews], so at most one row can ever come back.
  Future<Review?> fetchReviewForOrderItem(String orderItemId) async {
    final row = await _client
        .from('reviews')
        .select('*, $_reviewAuthorSelect')
        .eq('order_item_id', orderItemId)
        .maybeSingle();
    if (row == null) return null;
    return Review.fromMap(row);
  }

  Future<Review> addReview({
    required String orderItemId,
    required String productId,
    required int rating,
    String? textContent,
  }) async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client
        .from('reviews')
        .insert({
          'order_item_id': orderItemId,
          'product_id': productId,
          'user_id': userId,
          'rating': rating,
          'text_content': textContent,
        })
        .select('*, $_reviewAuthorSelect')
        .single();
    return Review.fromMap(row);
  }

  Future<void> editReview({
    required String reviewId,
    required int rating,
    String? textContent,
  }) {
    return _client.from('reviews').update({
      'rating': rating,
      'text_content': textContent,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', reviewId);
  }

  Future<void> deleteReview(String reviewId) {
    return _client.from('reviews').delete().eq('id', reviewId);
  }

  /// (average, count) for [productId] -- (0, 0) when there are no
  /// reviews yet, which callers render as "ยังไม่มีรีวิว".
  Future<(double, int)> fetchProductRating(String productId) async {
    final rows = await _client.from('reviews').select('rating').eq('product_id', productId);
    if (rows.isEmpty) return (0.0, 0);
    final ratings = rows.map((r) => r['rating'] as int);
    return (ratings.reduce((a, b) => a + b) / rows.length, rows.length);
  }

  Future<List<Review>> fetchProductReviews(
    String productId, {
    int limit = reviewsPageSize,
    int offset = 0,
  }) async {
    final rows = await _client
        .from('reviews')
        .select('*, $_reviewAuthorSelect')
        .eq('product_id', productId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(Review.fromMap).toList();
  }

  /// (average, count) across every product belonging to [storeId] --
  /// what StoreScreen's header shows in place of ZOKY-001's placeholder.
  Future<(double, int)> fetchStoreRating(String storeId) async {
    final productIds = await _storeProductIds(storeId);
    if (productIds.isEmpty) return (0.0, 0);
    final rows = await _client.from('reviews').select('rating').inFilter('product_id', productIds);
    if (rows.isEmpty) return (0.0, 0);
    final ratings = rows.map((r) => r['rating'] as int);
    return (ratings.reduce((a, b) => a + b) / rows.length, rows.length);
  }

  /// Reviews across every product in [storeId]'s store, newest first,
  /// each carrying its product's name (StoreScreen's Reviews tab
  /// mixes products together, unlike ProductDetailScreen which already
  /// knows the product it's showing).
  Future<List<Review>> fetchStoreReviews(
    String storeId, {
    int limit = reviewsPageSize,
    int offset = 0,
  }) async {
    final productIds = await _storeProductIds(storeId);
    if (productIds.isEmpty) return [];
    final rows = await _client
        .from('reviews')
        .select('*, $_reviewAuthorSelect, product:products(name)')
        .inFilter('product_id', productIds)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(Review.fromMap).toList();
  }

  Future<List<String>> _storeProductIds(String storeId) async {
    final rows = await _client.from('products').select('id').eq('store_id', storeId);
    return rows.map((r) => r['id'] as String).toList();
  }
}
