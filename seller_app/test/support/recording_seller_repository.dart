import 'package:supabase_flutter/supabase_flutter.dart';
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
  })  : bestSellingProducts = bestSellingProducts ?? const [],
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
}
