import 'dart:async';
import 'package:flutter/foundation.dart';
import 'merchant_repository.dart';

class MerchantController extends ChangeNotifier {
  MerchantController(this.repository, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  final MerchantRepository repository;
  final DateTime Function() _now;
  List<Json> stores = [], menu = [], orders = [], campaigns = [];
  Json report = {}, qualityData = {};
  String? storeId, error, reportError, campaignError, qualityError;
  String status = 'pending_acceptance';
  bool loading = false,
      refreshing = false,
      ordersLoading = false,
      summariesLoading = false,
      busy = false,
      hasMore = false,
      canConfigure = false,
      canManage = false,
      canOrders = false,
      canDelivery = false,
      canCampaigns = false;
  DateTime? updatedAt, detailsUpdatedAt, summariesUpdatedAt;
  int _generation = 0, _summaryGeneration = 0, _scopeGeneration = 0;
  bool _disposed = false,
      _pendingFull = false,
      _pendingOrders = false,
      _activeFull = false;
  Future<void>? _readFuture, _summaryFuture;

  Json? get store => stores.where((s) => s['id'] == storeId).firstOrNull;
  // Background reads do not turn every switch and editor into a disabled form.
  // A write waits for the active critical read and checks this state again.
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
    _summaryGeneration++;
    _scopeGeneration++;
    super.dispose();
  }

  Future<void> initialize() => refresh();

  void _clearSummaries() {
    _summaryGeneration++;
    summariesLoading = false;
    _summaryFuture = null;
    summariesUpdatedAt = null;
    campaigns = [];
    report = {};
    qualityData = {};
    reportError = campaignError = qualityError = null;
    canCampaigns = false;
  }

  void _clearPrivateData() {
    _clearSummaries();
    _scopeGeneration++;
    menu = [];
    orders = [];
    canConfigure = canManage = canOrders = canDelivery = canCampaigns = false;
    hasMore = false;
    updatedAt = detailsUpdatedAt = null;
  }

  Future<void> selectStore(String id) async {
    if (_disposed || busy || id == storeId) return;
    _clearPrivateData();
    storeId = id;
    status = 'pending_acceptance';
    _pendingFull = _pendingOrders = false;
    // A slow read for the previous selection cannot swallow a user's click.
    // Supersede it; its generation cannot publish into the new store.
    await _startRead(full: true);
  }

  Future<void> selectStatus(String value) async {
    if (_disposed || busy || storeId == null || status == value) return;
    _scopeGeneration++;
    status = value;
    orders = [];
    hasMore = false;
    final full = _activeFull || _pendingFull || updatedAt == null;
    _pendingFull = _pendingOrders = false;
    await _startRead(full: full);
  }

  /// Full manual refresh. Its future includes summaries, but critical content
  /// is published first and is already writable while those summaries load.
  Future<void> refresh() => _requestRead(full: true);

  /// Realtime and polling only invalidate orders and the current access scope.
  /// Menu images and historical reports need not reload for every new order.
  Future<void> refreshOrders() => _requestRead(full: false);

  Future<void> _requestRead({required bool full}) {
    if (_disposed) return Future.value();
    if (busy || _readFuture != null) {
      if (full) {
        _pendingFull = true;
      } else {
        _pendingOrders = true;
      }
      // Invalidations are coalesced, not awaited by their event handlers.
      return Future.value();
    }
    return _startRead(full: full || updatedAt == null);
  }

  Future<void> _startRead({required bool full, bool append = false}) {
    final complete = Completer<void>();
    final generation = ++_generation;
    _readFuture = complete.future;
    _activeFull = full;
    loading = store == null || updatedAt == null;
    refreshing = !loading;
    ordersLoading = !full || append;
    notifyListeners();
    return _read(generation, complete, full: full, append: append);
  }

  bool _current(int generation, String id) =>
      !_disposed && generation == _generation && storeId == id;

  Future<void> _read(
    int generation,
    Completer<void> complete, {
    required bool full,
    required bool append,
  }) async {
    Future<void>? summaries;
    try {
      // One stores read serves both initial selection and access revalidation.
      final allowed = await repository.stores();
      if (_disposed || generation != _generation) return;
      stores = allowed;
      storeId ??= allowed.isEmpty ? null : allowed.first['id'] as String;
      final id = storeId;
      if (id == null || !allowed.any((s) => s['id'] == id)) {
        _clearPrivateData();
        storeId = null;
        error = null;
        return;
      }
      final readStatus = status;
      final results = await Future.wait([
        repository.hasRole(id, ['owner', 'admin']),
        if (full) repository.menu(id),
        repository.orders(id, readStatus, append ? orders.length : 0),
        repository.hasRole(id, ['owner', 'admin', 'manager']),
        repository.hasRole(id, ['owner', 'admin', 'manager', 'orders']),
        repository.hasRole(id, [
          'owner',
          'admin',
          'manager',
          'orders',
          'delivery',
        ]),
      ], eagerError: true);
      if (!_current(generation, id) || status != readStatus) return;
      final previousRoles = [canConfigure, canManage, canOrders, canDelivery];
      var index = 0;
      canConfigure = results[index++] as bool;
      if (full) menu = results[index++] as List<Json>;
      final rows = results[index++] as List<Json>;
      if (append) {
        final ids = orders.map((e) => e['id']).toSet();
        orders = [...orders, ...rows.where((e) => !ids.contains(e['id']))];
      } else {
        orders = rows;
      }
      canManage = results[index++] as bool;
      canOrders = results[index++] as bool;
      canDelivery = results[index] as bool;
      final rolesChanged =
          updatedAt != null &&
          !listEquals(previousRoles, [
            canConfigure,
            canManage,
            canOrders,
            canDelivery,
          ]);
      if (rolesChanged) {
        // A result started under the old role must not refill private panels.
        _clearSummaries();
        _scopeGeneration++;
      }
      if (!canManage) canCampaigns = false;
      hasMore = rows.length == MerchantRepository.pageSize;
      updatedAt = _now();
      if (full) detailsUpdatedAt = updatedAt;
      error = null;
      loading = false;
      // The initial store, menu, orders and permissions can paint immediately.
      notifyListeners();
      if (full || rolesChanged) summaries = refreshSummaries();
    } catch (e) {
      if (!_disposed && generation == _generation) {
        error = errorMessage(e);
        // No stale customer or panel data survives a failed access/read check.
        stores = [];
        _clearPrivateData();
      }
    } finally {
      if (!_disposed && generation == _generation) {
        loading = refreshing = ordersLoading = false;
        _readFuture = null;
        _activeFull = false;
        notifyListeners();
      }
      complete.complete();
      // Waiting user actions resume before a queued event starts another read.
      scheduleMicrotask(_drainRefresh);
    }
    if (summaries != null) await summaries;
  }

  void _drainRefresh() {
    if (_disposed || busy || _readFuture != null) return;
    if (!_pendingFull && !_pendingOrders) return;
    final full = _pendingFull;
    _pendingFull = _pendingOrders = false;
    unawaited(_requestRead(full: full));
  }

  /// Visible summary pages call this without blocking their controls. Order
  /// polling stays lightweight, while sales and campaign figures remain fresh.
  Future<void> refreshSummariesIfStale({
    Duration maxAge = const Duration(minutes: 1),
  }) {
    if (_disposed || loading || store == null || error != null) {
      return Future.value();
    }
    final active = _summaryFuture;
    if (active != null) return active;
    final at = summariesUpdatedAt;
    if (at != null) {
      final age = _now().difference(at);
      if (!age.isNegative && age < maxAge) return Future.value();
    }
    return refreshSummaries();
  }

  Future<void> refreshSummaries() {
    if (_disposed || storeId == null || store == null || error != null) {
      return Future.value();
    }
    final id = storeId!;
    final generation = ++_summaryGeneration;
    summariesLoading = true;
    notifyListeners();
    bool current() =>
        !_disposed && generation == _summaryGeneration && storeId == id;

    Future<void> loadReport() async {
      try {
        final value = await repository.report(id);
        if (!current()) return;
        report = value;
        reportError = null;
      } catch (e) {
        if (!current()) return;
        report = {};
        reportError = errorMessage(e);
      }
      if (current()) notifyListeners();
    }

    Future<void> loadQuality() async {
      try {
        final value = await repository.quality(id);
        if (!current()) return;
        qualityData = value;
        qualityError = null;
      } catch (e) {
        if (!current()) return;
        qualityData = {};
        qualityError = errorMessage(e);
      }
      if (current()) notifyListeners();
    }

    Future<void> loadCampaigns() async {
      try {
        final value = await repository.campaigns(id);
        if (!current()) return;
        campaigns = (value['campaigns'] as List? ?? [])
            .map((e) => Json.from(e as Map))
            .toList();
        canCampaigns = canManage && value['can_manage'] == true;
        campaignError = null;
      } catch (e) {
        if (!current()) return;
        campaigns = [];
        canCampaigns = false;
        campaignError = errorMessage(e);
      }
      if (current()) notifyListeners();
    }

    final future = Future.wait([loadReport(), loadQuality(), loadCampaigns()])
        .then<void>((_) {
          if (!current()) return;
          summariesLoading = false;
          summariesUpdatedAt = _now();
          _summaryFuture = null;
          notifyListeners();
        });
    _summaryFuture = future;
    return future;
  }

  Future<void> loadMore() {
    if (!writable || !hasMore || _readFuture != null) return Future.value();
    return _startRead(full: false, append: true);
  }

  /// Recheck the captured scope after a background read. Successful writes are
  /// read back from the server; they never claim optimistic success.
  Future<bool> mutate(Future<void> Function() operation) async {
    if (!writable) return false;
    final id = storeId, readStatus = status;
    final scope = _scopeGeneration;
    final read = _readFuture;
    if (read != null) await read;
    if (!writable ||
        scope != _scopeGeneration ||
        id != storeId ||
        readStatus != status) {
      return false;
    }
    busy = true;
    notifyListeners();
    try {
      await operation();
      if (_disposed || scope != _scopeGeneration || id != storeId) return false;
    } catch (e) {
      if (!_disposed) error = errorMessage(e);
      busy = false;
      notifyListeners();
      scheduleMicrotask(_drainRefresh);
      return false;
    }
    busy = false;
    // This full read already covers invalidations received during the write.
    _pendingFull = _pendingOrders = false;
    unawaited(refresh());
    final readBack = _readFuture;
    if (readBack != null) await readBack;
    return !_disposed && id == storeId && error == null;
  }
}
