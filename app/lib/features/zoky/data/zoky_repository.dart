import 'package:supabase_flutter/supabase_flutter.dart';

import 'cart_item.dart';
import 'category.dart';
import 'order.dart';
import 'order_item.dart';
import 'product.dart';
import 'product_variant.dart';
import 'store.dart';

const _productSelect = '*, store:stores(name), category:categories(name)';

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
}
