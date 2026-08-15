import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/text_utils.dart';
import '../../order/data/order.dart';
import '../../order/data/order_item.dart';
import '../../product/data/category.dart';
import '../../product/data/product.dart';
import '../../product/data/product_variant.dart';
import 'store.dart';

const _productSelect = '*, store:stores(name), category:categories(name)';

/// Which subset of a seller's own products `SellerRepository.
/// fetchProducts` returns -- mirrors `SellerProductListScreen`'s 4
/// filter chips. See .wyn/tasks/backlog/SELLER-002-product-management.md,
/// Requirements #2.
enum ProductStatusFilter { all, active, inactive, outOfStock }

/// Thrown by [SellerRepository.adjustProductStock]/[adjustVariantStock]
/// when `adjust_product_stock`/`adjust_variant_stock` (see
/// supabase/schema.sql, SELLER-002 section) rejects the adjustment
/// because it would take stock negative -- parsed from the RPC's
/// 'INSUFFICIENT_STOCK' exception message so the UI can show
/// "สต็อกไม่พอ" instead of a raw Postgres error (per the Design spec's
/// StockAdjustmentSheet States).
class InsufficientStockException implements Exception {
  const InsufficientStockException();
}

/// One period's Gross Sales / ZOKY Fee / Net Revenue, for `status =
/// 'delivered'` orders only -- see [SellerFinanceBreakdown]. `net` is
/// always `gross - fee` exactly (equivalently `sum(subtotal)`), since
/// every order snapshots `total = subtotal + fee_amount` at checkout
/// time (ZOKY-003). See .wyn/tasks/backlog/SELLER-005-finance.md,
/// Requirements #1.
class FinancePeriodTotals {
  const FinancePeriodTotals({
    required this.gross,
    required this.fee,
    required this.net,
  });

  /// sum(orders.total) -- numerically identical to `fetchSalesSummary`'s
  /// corresponding period for the same store (same column, same filter).
  final double gross;

  /// sum(orders.fee_amount).
  final double fee;

  /// sum(orders.subtotal) -- equals `gross - fee`.
  final double net;

  static const zero = FinancePeriodTotals(gross: 0, fee: 0, net: 0);
}

/// Gross/Fee/Net split across the same 3 periods `fetchSalesSummary`
/// already reports (today/thisMonth/allTime) -- see
/// [SellerRepository.fetchFinanceBreakdown]. `allTime.net` doubles as
/// the seller's cumulative Balance (Product spec Requirements #5):
/// callers must not query it separately.
class SellerFinanceBreakdown {
  const SellerFinanceBreakdown({
    required this.today,
    required this.thisMonth,
    required this.allTime,
  });

  final FinancePeriodTotals today;
  final FinancePeriodTotals thisMonth;
  final FinancePeriodTotals allTime;
}

/// Wraps every store/order read+write SELLER-001 needs. Every method
/// here relies on RLS to actually enforce ownership (see
/// supabase/schema.sql, SELLER-001 section) -- the `.eq('store_id', ...)`
/// filters below are for correctness/efficiency of the query itself,
/// not the security boundary. A seller can never see another store's
/// orders/order_items even if [storeId] were tampered with client-side,
/// because the RLS policies scope through `stores.owner_id = auth.uid()`
/// regardless of what the client asks for.
///
/// Every number here is computed live from the current rows every call
/// -- nothing is cached/denormalized, same principle as ZOKY-004's
/// rating average (see .wyn/tasks/backlog/SELLER-001-foundation.md,
/// Requirements: "ทุกค่าคำนวณจาก query สดทุกครั้ง").
class SellerRepository {
  SellerRepository(this._client);

  final SupabaseClient _client;

  /// The caller's own store, or null if they haven't registered one
  /// yet. V1 assumes 1 seller -> 1 store (see Product spec's Risks) --
  /// there's no unique constraint on `stores.owner_id` at the DB level,
  /// so this takes the first row rather than crashing if that
  /// assumption is ever violated in the future.
  Future<Store?> fetchMyStore() async {
    final userId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('stores')
        .select()
        .eq('owner_id', userId)
        .limit(1);
    if (rows.isEmpty) return null;
    return Store.fromMap(rows.first);
  }

  Future<Store> createStore({required String name, String? description}) async {
    final userId = _client.auth.currentUser!.id;
    final trimmedDescription = description?.trim();
    final row = await _client
        .from('stores')
        .insert({
          'owner_id': userId,
          'name': name.trim(),
          if (trimmedDescription != null && trimmedDescription.isNotEmpty)
            'description': trimmedDescription,
        })
        .select()
        .single();
    return Store.fromMap(row);
  }

  /// (newOrders, totalOrders) -- newOrders counts `status = 'paid'`
  /// (created, not yet processed by this seller -- SELLER-003 renamed
  /// this status from 'pending' to 'paid', same meaning, see
  /// supabase/schema.sql's migration comment), totalOrders counts every
  /// status. See .wyn/docs/design/seller-001-foundation.md,
  /// SellerDashboardScreen Handoff.
  Future<(int, int)> fetchOrderCounts(String storeId) async {
    final newOrders = await _client
        .from('orders')
        .count(CountOption.exact)
        .eq('store_id', storeId)
        .eq('status', 'paid');
    final totalOrders = await _client
        .from('orders')
        .count(CountOption.exact)
        .eq('store_id', storeId);
    return (newOrders, totalOrders);
  }

  /// (today, thisMonth, allTime) -- sums `orders.total` for orders that
  /// are `status = 'delivered'` only (Product spec: "นับเป็นยอดขายจริง
  /// เมื่อลูกค้ายืนยันได้รับสินค้าแล้วเท่านั้น ไม่นับ pending/cancelled").
  /// Fetches every delivered order for the store and aggregates
  /// client-side -- same approach `ZokyRepository.fetchProductRating`/
  /// `fetchStoreRating` already use for other "must always be live, no
  /// denormalized column" aggregates in this codebase.
  Future<(double, double, double)> fetchSalesSummary(String storeId) async {
    final rows = await _client
        .from('orders')
        .select('total, created_at')
        .eq('store_id', storeId)
        .eq('status', 'delivered');

    final now = DateTime.now();
    var today = 0.0;
    var thisMonth = 0.0;
    var allTime = 0.0;

    for (final row in rows) {
      final total = (row['total'] as num).toDouble();
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();
      allTime += total;
      if (createdAt.year == now.year && createdAt.month == now.month) {
        thisMonth += total;
        if (createdAt.day == now.day) {
          today += total;
        }
      }
    }

    return (today, thisMonth, allTime);
  }

  /// Top [limit] products by total quantity sold across every
  /// `delivered` order of [storeId], highest first. Empty when the
  /// store has no delivered sales yet -- callers render "ยังไม่มีข้อมูล
  /// การขาย" for that case, not an error.
  Future<List<(String, int)>> fetchBestSellingProducts(
    String storeId, {
    int limit = 5,
  }) async {
    final rows = await _client
        .from('order_items')
        .select('product_name, quantity, order:orders!inner(store_id, status)')
        .eq('order.store_id', storeId)
        .eq('order.status', 'delivered');

    final totals = <String, int>{};
    for (final row in rows) {
      final name = row['product_name'] as String;
      final quantity = row['quantity'] as int;
      totals[name] = (totals[name] ?? 0) + quantity;
    }

    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => (e.key, e.value)).toList();
  }

  // -- Store Management (SELLER-004) --------------------------------------
  //
  // `store-media` is a public bucket (unlike `club-media`, which is
  // private) -- see supabase/schema.sql, SELLER-004 section, and the
  // Design spec's reasoning for why this is a single method instead of
  // ClubRepository's 2 upload methods + 1 info-update method: no
  // signed-URL round-trip is needed, `getPublicUrl()` returns a usable
  // URL immediately after upload.

  /// Uploads whichever of [newLogoBytes]/[newBannerBytes] is non-null to
  /// `store-media` first (path `{storeId}/logo-{timestamp}.{ext}` /
  /// `{storeId}/banner-{timestamp}.{ext}`, mirroring `product-images`'
  /// timestamped path so a stale CDN/cache never serves an old image
  /// back), then updates every text field (through
  /// [normalizeOptionalText], empty string -> null) plus `logo_url`/
  /// `banner_url` (only when a new image was actually uploaded -- an
  /// unchanged picker slot must never null out the existing URL) in a
  /// single `stores` update. Returns the freshest row from
  /// `.select().single()` so callers can hand it straight to
  /// `onStoreUpdated` without a second query.
  Future<Store> updateStoreInfo({
    required String storeId,
    required String name,
    String? description,
    String? address,
    String? contactPhone,
    String? businessHours,
    Uint8List? newLogoBytes,
    String? newLogoExtension,
    Uint8List? newBannerBytes,
    String? newBannerExtension,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String? logoUrl;
    if (newLogoBytes != null && newLogoExtension != null) {
      final path = '$storeId/logo-$timestamp.$newLogoExtension';
      await _client.storage.from('store-media').uploadBinary(path, newLogoBytes);
      logoUrl = _client.storage.from('store-media').getPublicUrl(path);
    }

    String? bannerUrl;
    if (newBannerBytes != null && newBannerExtension != null) {
      final path = '$storeId/banner-$timestamp.$newBannerExtension';
      await _client.storage.from('store-media').uploadBinary(path, newBannerBytes);
      bannerUrl = _client.storage.from('store-media').getPublicUrl(path);
    }

    final row = await _client
        .from('stores')
        .update({
          'name': name.trim(),
          'description': normalizeOptionalText(description?.trim() ?? ''),
          'address': normalizeOptionalText(address?.trim() ?? ''),
          'contact_phone': normalizeOptionalText(contactPhone?.trim() ?? ''),
          'business_hours': normalizeOptionalText(businessHours?.trim() ?? ''),
          if (logoUrl != null) 'logo_url': logoUrl,
          if (bannerUrl != null) 'banner_url': bannerUrl,
        })
        .eq('id', storeId)
        .select()
        .single();
    return Store.fromMap(row);
  }

  // -- Product Management (SELLER-002) -----------------------------------
  //
  // `products`/`product_variants` now have insert/update (and, for
  // variants only, delete) RLS policies scoped to the caller's own
  // store -- see supabase/schema.sql, SELLER-002 section. The
  // `.eq('store_id', storeId)`/ownership joins below are for
  // correctness/efficiency of the query itself, not the security
  // boundary, same disclaimer as every other method in this class.

  static const productsPageSize = 20;

  Future<List<Category>> fetchCategories() async {
    final rows =
        await _client.from('categories').select().order('name', ascending: true);
    return rows.map(Category.fromMap).toList();
  }

  Future<List<ProductVariant>> fetchProductVariants(String productId) async {
    final rows = await _client
        .from('product_variants')
        .select()
        .eq('product_id', productId)
        .order('variant_type', ascending: true);
    return rows.map(ProductVariant.fromMap).toList();
  }

  /// The seller's own product list, filtered by [filter]/[storeId] and
  /// optionally [query] (matches name OR SKU). PostgREST's `.or()`
  /// filter DSL needs [query] interpolated into a string -- the exact
  /// injection-prone shape flagged for `ProfileRepository.
  /// searchProfiles` (see .wyn/learning/MISTAKES.md, ZOKY-002/ZOKY-004)
  /// -- so this calls `.ilike()` directly on each column separately
  /// (name, then sku) instead and merges the two result sets
  /// client-side, rather than building an `.or()` string at all. A
  /// single seller's own catalog is expected to be small enough that
  /// two unpaginated-at-the-DB-level queries plus client-side
  /// pagination isn't a real performance concern this round.
  Future<List<Product>> fetchProducts({
    required String storeId,
    ProductStatusFilter filter = ProductStatusFilter.all,
    String query = '',
    required int page,
  }) async {
    final trimmed = query.trim();

    Future<List<Map<String, dynamic>>> queryByColumn(String? column) {
      var q = _client.from('products').select(_productSelect).eq('store_id', storeId);
      switch (filter) {
        case ProductStatusFilter.all:
          break;
        case ProductStatusFilter.active:
          q = q.eq('is_active', true);
        case ProductStatusFilter.inactive:
          q = q.eq('is_active', false);
        case ProductStatusFilter.outOfStock:
          q = q.eq('stock', 0);
      }
      if (column != null) q = q.ilike(column, '%$trimmed%');
      return q.order('created_at', ascending: false);
    }

    List<Map<String, dynamic>> rows;
    if (trimmed.isEmpty) {
      rows = await queryByColumn(null);
    } else {
      final nameRows = await queryByColumn('name');
      final skuRows = await queryByColumn('sku');
      final seen = <String>{};
      rows = [];
      for (final row in [...nameRows, ...skuRows]) {
        if (seen.add(row['id'] as String)) rows.add(row);
      }
      rows.sort((a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String));
    }

    final from = page * productsPageSize;
    if (from >= rows.length) return [];
    final to = (from + productsPageSize) > rows.length ? rows.length : from + productsPageSize;
    return rows.sublist(from, to).map(Product.fromMap).toList();
  }

  /// Creates a new product (+ its variants, if any) for [storeId].
  /// Images are uploaded to `product-images` *before* the product row
  /// is inserted, same "upload first" reasoning WYN-014's
  /// ClubPostRepository.createPost already established (see
  /// supabase/schema.sql's `products_image_urls_length` CHECK -- an
  /// intermediate row with an empty `image_urls` would violate it).
  /// [initialStock] is written directly via this insert, not through
  /// `adjustProductStock` -- there's no concurrent reader of a row that
  /// doesn't exist yet to race against (see the Product spec's
  /// Requirements #5).
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
    final imageUrls = await _uploadProductImages(storeId, images, imageExtensions);

    final row = await _client
        .from('products')
        .insert({
          'store_id': storeId,
          'category_id': categoryId,
          'name': name.trim(),
          'description': normalizeOptionalText(description?.trim() ?? ''),
          'price': price,
          'original_price': originalPrice,
          'stock': initialStock,
          'image_urls': imageUrls,
          'sku': normalizeOptionalText(sku?.trim() ?? ''),
        })
        .select(_productSelect)
        .single();
    final product = Product.fromMap(row);

    for (final variant in variants) {
      final value = variant.value.trim();
      if (value.isEmpty) continue;
      await _client.from('product_variants').insert({
        'product_id': product.id,
        'variant_type': variantTypeToDbValue(variant.type),
        'variant_value': value,
        'price_delta': variant.priceDelta,
        'stock': variant.stock,
      });
    }

    return product;
  }

  /// Updates every field of [productId] except `stock`/`is_active`
  /// (those go through `adjustProductStock` and `setProductActive`
  /// respectively -- never this method), diffing [variants] against
  /// what's currently in the DB: a row with no [VariantInput.id] is
  /// inserted, one with an id present in both is updated (its `stock`
  /// is deliberately never part of this update -- only
  /// `adjustVariantStock`'s RPC may change an *existing* variant's
  /// stock), and an existing id no longer present in [variants] is
  /// hard-deleted. See .wyn/docs/design/seller-002-product-management.md,
  /// Widget: ProductVariantEditor.
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
    final storeId = (await _client
        .from('products')
        .select('store_id')
        .eq('id', productId)
        .single())['store_id'] as String;

    final uploadedUrls =
        await _uploadProductImages(storeId, newImages, newImageExtensions);

    final row = await _client
        .from('products')
        .update({
          'category_id': categoryId,
          'name': name.trim(),
          'description': normalizeOptionalText(description?.trim() ?? ''),
          'price': price,
          'original_price': originalPrice,
          'image_urls': [...imageUrls, ...uploadedUrls],
          'sku': normalizeOptionalText(sku?.trim() ?? ''),
        })
        .eq('id', productId)
        .select(_productSelect)
        .single();
    final product = Product.fromMap(row);

    final existingRows =
        await _client.from('product_variants').select('id').eq('product_id', productId);
    final existingIds = existingRows.map((r) => r['id'] as String).toSet();
    final keptIds = variants.where((v) => v.id != null).map((v) => v.id!).toSet();

    for (final removedId in existingIds.difference(keptIds)) {
      await _client.from('product_variants').delete().eq('id', removedId);
    }

    for (final variant in variants) {
      final value = variant.value.trim();
      if (value.isEmpty) continue; // dropped silently, per the Design spec's States
      if (variant.id == null) {
        await _client.from('product_variants').insert({
          'product_id': productId,
          'variant_type': variantTypeToDbValue(variant.type),
          'variant_value': value,
          'price_delta': variant.priceDelta,
          'stock': variant.stock,
        });
      } else {
        await _client.from('product_variants').update({
          'variant_type': variantTypeToDbValue(variant.type),
          'variant_value': value,
          'price_delta': variant.priceDelta,
        }).eq('id', variant.id!);
      }
    }

    return product;
  }

  Future<List<String>> _uploadProductImages(
    String storeId,
    List<Uint8List> images,
    List<String> imageExtensions,
  ) async {
    if (images.isEmpty) return [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final urls = <String>[];
    for (var i = 0; i < images.length; i++) {
      final path = '$storeId/$timestamp-$i.${imageExtensions[i]}';
      await _client.storage.from('product-images').uploadBinary(path, images[i]);
      urls.add(_client.storage.from('product-images').getPublicUrl(path));
    }
    return urls;
  }

  /// "ลบสินค้า"/"เปิดขายอีกครั้ง" -- a plain RLS update, not the RPC
  /// pattern below, since toggling `is_active` isn't a cross-table
  /// atomic operation (see the Product spec's Requirements #4).
  Future<void> setProductActive(String productId, bool isActive) {
    return _client.from('products').update({'is_active': isActive}).eq('id', productId);
  }

  /// Adjusts a product's total stock by [delta] (never an absolute
  /// value) through `adjust_product_stock` -- see supabase/schema.sql,
  /// SELLER-002 section, and the Product spec's Requirements #5. Throws
  /// [InsufficientStockException] when the adjustment would take stock
  /// negative.
  Future<int> adjustProductStock(String productId, int delta) async {
    try {
      final result = await _client.rpc('adjust_product_stock', params: {
        'p_product_id': productId,
        'p_delta': delta,
      });
      return result as int;
    } on PostgrestException catch (e) {
      if (e.message.contains('INSUFFICIENT_STOCK')) {
        throw const InsufficientStockException();
      }
      rethrow;
    }
  }

  /// Same as [adjustProductStock], scoped to a single variant's stock
  /// through `adjust_variant_stock`.
  Future<int> adjustVariantStock(String variantId, int delta) async {
    try {
      final result = await _client.rpc('adjust_variant_stock', params: {
        'p_variant_id': variantId,
        'p_delta': delta,
      });
      return result as int;
    } on PostgrestException catch (e) {
      if (e.message.contains('INSUFFICIENT_STOCK')) {
        throw const InsufficientStockException();
      }
      rethrow;
    }
  }

  // -- Order Management (SELLER-003) --------------------------------------
  //
  // `orders`/`order_items` still have no insert/update/delete RLS
  // policy for a client at all (see supabase/schema.sql, SELLER-003
  // section) -- every status transition below goes through a
  // security-definer RPC, same as the buyer-side ones ZOKY-003 already
  // established. The `.eq('store_id', storeId)`/ownership joins in the
  // read methods below are for correctness/efficiency of the query
  // itself, not the security boundary, same disclaimer as every other
  // method in this class.

  static const ordersPageSize = 20;

  /// The seller's own orders for [storeId], newest first, optionally
  /// filtered to a single [filter] status. See .wyn/docs/design/
  /// seller-003-order-management.md, Screen: SellerOrderListScreen.
  Future<List<Order>> fetchStoreOrders({
    required String storeId,
    OrderStatus? filter,
    required int page,
  }) async {
    var query = _client.from('orders').select().eq('store_id', storeId);
    if (filter != null) {
      query = query.eq('status', orderStatusToDbValue(filter));
    }
    final from = page * ordersPageSize;
    final to = from + ordersPageSize - 1;
    final rows = await query.order('created_at', ascending: false).range(from, to);
    return rows.map(Order.fromMap).toList();
  }

  Future<Order?> fetchStoreOrder(String orderId) async {
    final row = await _client.from('orders').select().eq('id', orderId).maybeSingle();
    if (row == null) return null;
    return Order.fromMap(row);
  }

  Future<List<OrderItem>> fetchStoreOrderItems(String orderId) async {
    final rows = await _client.from('order_items').select().eq('order_id', orderId);
    return rows.map(OrderItem.fromMap).toList();
  }

  /// paid -> seller_processing, via `seller_start_processing`.
  Future<void> sellerStartProcessing(String orderId) {
    return _client.rpc('seller_start_processing', params: {'p_order_id': orderId});
  }

  /// seller_processing -> ready_to_ship, via `seller_mark_ready_to_ship`.
  Future<void> sellerMarkReadyToShip(String orderId) {
    return _client.rpc('seller_mark_ready_to_ship', params: {'p_order_id': orderId});
  }

  /// ready_to_ship -> shipped, via `seller_ship_order` -- records
  /// [shippingProvider]/[trackingNumber] in the same call.
  Future<void> sellerShipOrder(
    String orderId,
    String shippingProvider,
    String trackingNumber,
  ) {
    return _client.rpc('seller_ship_order', params: {
      'p_order_id': orderId,
      'p_shipping_provider': shippingProvider,
      'p_tracking_number': trackingNumber,
    });
  }

  /// paid/seller_processing/ready_to_ship -> cancelled, via
  /// `seller_cancel_order` -- restocks every item, mirroring the
  /// buyer's own `cancel_order`.
  Future<void> sellerCancelOrder(String orderId) {
    return _client.rpc('seller_cancel_order', params: {'p_order_id': orderId});
  }

  /// shipped/delivered -> refunded, via `seller_mark_refunded` -- a
  /// bookkeeping-only flag, no stock is restored (see that RPC's
  /// comment in supabase/schema.sql).
  Future<void> sellerMarkRefunded(String orderId) {
    return _client.rpc('seller_mark_refunded', params: {'p_order_id': orderId});
  }

  // -- Finance (SELLER-005) ------------------------------------------------
  //
  // Read-only -- no RLS/RPC changes needed at all (see .wyn/tasks/backlog/
  // SELLER-005-finance.md, Requirements #0: the existing `orders` select
  // policy from SELLER-001 already covers every query below). None of
  // the 4 methods here touch fetchOrderCounts/fetchSalesSummary/
  // fetchBestSellingProducts/fetchStoreOrders above -- those are left
  // exactly as SELLER-001/003 QA'd them.

  /// Gross Sales (sum(total)) / ZOKY Fee (sum(fee_amount)) / Net Revenue
  /// (sum(subtotal)) for `status = 'delivered'` orders of [storeId],
  /// split across the same 3 periods [fetchSalesSummary] reports
  /// (today/thisMonth/allTime) -- mirrors that method's query/aggregation
  /// shape exactly, just selecting 2 extra columns. `today.gross`/
  /// `thisMonth.gross`/`allTime.gross` are numerically identical to
  /// [fetchSalesSummary]'s 3-tuple for the same store at the same
  /// instant. `allTime.net` is the seller's cumulative Balance --
  /// callers use it directly, no second query. See .wyn/docs/design/
  /// seller-005-finance.md, Data Model & Repository #1.
  Future<SellerFinanceBreakdown> fetchFinanceBreakdown(String storeId) async {
    final rows = await _client
        .from('orders')
        .select('total, subtotal, fee_amount, created_at')
        .eq('store_id', storeId)
        .eq('status', 'delivered');

    final now = DateTime.now();
    var todayGross = 0.0;
    var todayFee = 0.0;
    var todayNet = 0.0;
    var monthGross = 0.0;
    var monthFee = 0.0;
    var monthNet = 0.0;
    var allGross = 0.0;
    var allFee = 0.0;
    var allNet = 0.0;

    for (final row in rows) {
      final total = (row['total'] as num).toDouble();
      final subtotal = (row['subtotal'] as num).toDouble();
      final feeAmount = (row['fee_amount'] as num).toDouble();
      final createdAt = DateTime.parse(row['created_at'] as String).toLocal();

      allGross += total;
      allFee += feeAmount;
      allNet += subtotal;
      if (createdAt.year == now.year && createdAt.month == now.month) {
        monthGross += total;
        monthFee += feeAmount;
        monthNet += subtotal;
        if (createdAt.day == now.day) {
          todayGross += total;
          todayFee += feeAmount;
          todayNet += subtotal;
        }
      }
    }

    return SellerFinanceBreakdown(
      today: FinancePeriodTotals(gross: todayGross, fee: todayFee, net: todayNet),
      thisMonth: FinancePeriodTotals(gross: monthGross, fee: monthFee, net: monthNet),
      allTime: FinancePeriodTotals(gross: allGross, fee: allFee, net: allNet),
    );
  }

  /// (sum(subtotal), count) of `status = 'shipped'` orders of [storeId]
  /// -- money "on the way" that isn't counted into Gross/Fee/Net/Balance
  /// yet (Product spec Requirements #2: `shipped` ไม่นับเข้า Gross/Net/
  /// Balance แต่ต้องแสดงแยกต่างหากเป็น "รายได้ระหว่างทาง").
  Future<(double, int)> fetchInTransitSummary(String storeId) async {
    final rows = await _client
        .from('orders')
        .select('subtotal')
        .eq('store_id', storeId)
        .eq('status', 'shipped');
    var sum = 0.0;
    for (final row in rows) {
      sum += (row['subtotal'] as num).toDouble();
    }
    return (sum, rows.length);
  }

  /// The seller's own `delivered`/`refunded` orders for [storeId],
  /// newest first, paginated with [ordersPageSize] -- deliberately a
  /// separate method from [fetchStoreOrders] (rather than widening that
  /// method's `filter` param to accept a list) so this screen's paging
  /// never risks a regression on the tab that already passed QA. No
  /// `order_items` join -- `SellerTransactionTile` only shows
  /// order-level totals, unlike `SellerOrderListTile`. See
  /// .wyn/docs/design/seller-005-finance.md, Data Model & Repository #3.
  Future<List<Order>> fetchTransactionHistory({
    required String storeId,
    required int page,
  }) async {
    final from = page * ordersPageSize;
    final to = from + ordersPageSize - 1;
    final rows = await _client
        .from('orders')
        .select()
        .eq('store_id', storeId)
        .inFilter('status', ['delivered', 'refunded'])
        .order('created_at', ascending: false)
        .range(from, to);
    return rows.map(Order.fromMap).toList();
  }

  /// Duplicated from `ZokyRepository.fetchMarketplaceFeePercent()`
  /// (`app/lib/features/zoky/data/zoky_repository.dart`) -- same table/
  /// key/fallback, separate Flutter binary, same pattern every other
  /// duplicated model/method in this class already follows. See
  /// .wyn/docs/design/seller-005-finance.md, Data Model & Repository #4.
  Future<double> fetchPlatformFeePercent() async {
    final row = await _client
        .from('platform_config')
        .select('value')
        .eq('key', 'zoky_marketplace_fee_percent')
        .maybeSingle();
    if (row == null) return 10;
    return double.tryParse(row['value'] as String) ?? 10;
  }
}
