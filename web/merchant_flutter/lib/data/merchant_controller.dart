import 'package:flutter/foundation.dart';
import 'merchant_repository.dart';

class MerchantController extends ChangeNotifier {
  MerchantController(this.repository);
  final MerchantRepository repository;
  List<Json> stores = [], menu = [], orders = [], campaigns = [];
  Json report = {};
  String? storeId, error, reportError, campaignError;
  String status = 'pending_acceptance';
  bool loading = false,
      busy = false,
      hasMore = false,
      canManage = false,
      canOrders = false,
      canDelivery = false,
      canCampaigns = false;
  DateTime? updatedAt;
  int _generation = 0;
  bool _disposed = false;
  Json? get store => stores.where((s) => s['id'] == storeId).firstOrNull;
  bool get writable =>
      !_disposed && !loading && !busy && error == null && store != null;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  Future<void> initialize() async {
    if (_disposed || loading || busy) return;
    loading = true;
    error = null;
    notifyListeners();
    final g = ++_generation;
    try {
      final list = await repository.stores();
      if (_disposed || g != _generation) return;
      stores = list;
      storeId = list.isEmpty ? null : list.first['id'] as String;
      if (storeId != null) await _load(g);
    } catch (e) {
      if (!_disposed && g == _generation) error = errorMessage(e);
    } finally {
      if (!_disposed && g == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectStore(String id) async {
    if (_disposed || loading || busy || id == storeId) return;
    storeId = id;
    status = 'pending_acceptance';
    menu = [];
    orders = [];
    campaigns = [];
    report = {};
    updatedAt = null;
    await refresh();
  }

  Future<void> selectStatus(String value) async {
    if (_disposed || loading || busy || status == value) return;
    status = value;
    orders = [];
    hasMore = false;
    await refresh();
  }

  Future<void> _load(int g) async {
    final id = storeId!;
    // Re-evaluate visible stores and permissions each refresh. Role revocation
    // must remove cached customer data as well as disabling writes.
    final allowed = await repository.stores();
    if (_disposed || g != _generation) return;
    stores = allowed;
    if (!allowed.any((s) => s['id'] == id)) {
      storeId = null;
      menu = [];
      orders = [];
      campaigns = [];
      report = {};
      canManage = canOrders = canDelivery = canCampaigns = false;
      return;
    }
    final results = await Future.wait([
      repository.menu(id),
      repository.orders(id, status, 0),
      repository.hasRole(id, ['owner', 'admin', 'manager']),
      repository.hasRole(id, ['owner', 'admin', 'manager', 'orders']),
      repository.hasRole(id, [
        'owner',
        'admin',
        'manager',
        'orders',
        'delivery',
      ]),
    ]);
    if (_disposed || g != _generation) return;
    menu = results[0] as List<Json>;
    orders = results[1] as List<Json>;
    canManage = results[2] as bool;
    canOrders = results[3] as bool;
    canDelivery = results[4] as bool;
    hasMore = orders.length == MerchantRepository.pageSize;
    try {
      final value = await repository.report(id);
      if (_disposed || g != _generation) return;
      report = value;
      reportError = null;
    } catch (e) {
      report = {};
      reportError = errorMessage(e);
    }
    try {
      final value = await repository.campaigns(id);
      if (_disposed || g != _generation) return;
      campaigns = (value['campaigns'] as List? ?? [])
          .map((e) => Json.from(e as Map))
          .toList();
      canCampaigns = value['can_manage'] == true;
      campaignError = null;
    } catch (e) {
      campaigns = [];
      canCampaigns = false;
      campaignError = errorMessage(e);
    }
    updatedAt = DateTime.now();
    error = null;
  }

  Future<void> refresh() async {
    if (loading || busy || _disposed) return;
    if (storeId == null) {
      await initialize();
      return;
    }
    loading = true;
    notifyListeners();
    final g = ++_generation;
    try {
      await _load(g);
    } catch (e) {
      if (!_disposed && g == _generation) {
        error = errorMessage(e);
        // Never leave private customer data visible after an access failure.
        orders = [];
        menu = [];
        campaigns = [];
        report = {};
        canManage = canOrders = canDelivery = canCampaigns = false;
      }
    } finally {
      if (!_disposed && g == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (!writable || !hasMore) return;
    loading = true;
    notifyListeners();
    try {
      final rows = await repository.orders(storeId!, status, orders.length);
      if (_disposed) return;
      final ids = orders.map((e) => e['id']).toSet();
      orders.addAll(rows.where((e) => !ids.contains(e['id'])));
      hasMore = rows.length == MerchantRepository.pageSize;
    } catch (e) {
      error = errorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Successful writes are never shown optimistically. Read back server state.
  /// Failure leaves a visible error and disables writes until a refresh.
  Future<bool> mutate(Future<void> Function() operation) async {
    if (!writable) return false;
    busy = true;
    notifyListeners();
    try {
      await operation();
      if (_disposed) return false;
    } catch (e) {
      error = errorMessage(e);
      busy = false;
      notifyListeners();
      return false;
    }
    busy = false;
    await refresh();
    return !_disposed && error == null;
  }
}
