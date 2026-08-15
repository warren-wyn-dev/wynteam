import 'package:supabase_flutter/supabase_flutter.dart';

import 'store.dart';

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

  /// (newOrders, totalOrders) -- newOrders counts `status = 'pending'`
  /// (not yet processed), totalOrders counts every status. See
  /// .wyn/docs/design/seller-001-foundation.md, SellerDashboardScreen
  /// Handoff.
  Future<(int, int)> fetchOrderCounts(String storeId) async {
    final newOrders = await _client
        .from('orders')
        .count(CountOption.exact)
        .eq('store_id', storeId)
        .eq('status', 'pending');
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
}
