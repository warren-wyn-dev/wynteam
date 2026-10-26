import 'dart:async';

import 'package:flutter/foundation.dart';

import 'merchant_repository.dart';

class MerchantController extends ChangeNotifier {
  MerchantController(this.repository);
  final MerchantRepository repository;
  List<Json> stores = [], menu = [], orders = [], campaigns = [];
  Json report = {}, qualityData = {};
  String? storeId, error, reportError, campaignError, qualityError;
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
  Future<void>? _readFuture;
  Completer<void>? _pendingRefresh;
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
    _pendingRefresh?.complete();
    _pendingRefresh = null;
    super.dispose();
  }

  Future<void> initialize() => refresh();

  Future<void> selectStore(String id) async {
    if (_disposed || loading || busy || id == storeId) return;
    storeId = id;
    status = 'pending_acceptance';
    menu = [];
    orders = [];
    campaigns = [];
    report = {};
    qualityData = {};
    qualityError = null;
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
      qualityData = {};
      qualityError = null;
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
      qualityData = {};
      qualityError = null;
      reportError = errorMessage(e);
    }
    try {
      final value = await repository.quality(id);
      if (_disposed || g != _generation) return;
      qualityData = value;
      qualityError = null;
    } catch (e) {
      if (_disposed || g != _generation) return;
      qualityData = {};
      qualityError = errorMessage(e);
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

  Future<void> refresh() {
    if (_disposed) return Future.value();
    if (busy || _readFuture != null) {
      // Coalesce a burst of realtime notifications into one pending refresh.
      // In particular, do not lose an order that arrived after its page read.
      _pendingRefresh ??= Completer<void>();
      return _pendingRefresh!.future;
    }
    return _startRead();
  }

  Future<void> _startRead({bool appendOrders = false}) {
    final complete = _pendingRefresh ?? Completer<void>();
    _pendingRefresh = null;
    _readFuture = complete.future;
    loading = true;
    notifyListeners();
    final g = ++_generation;
    unawaited(_read(g, complete, appendOrders: appendOrders));
    return complete.future;
  }

  Future<void> _read(
    int g,
    Completer<void> complete, {
    required bool appendOrders,
  }) async {
    try {
      if (appendOrders) {
        final rows = await repository.orders(storeId!, status, orders.length);
        if (_disposed || g != _generation) return;
        final ids = orders.map((e) => e['id']).toSet();
        orders.addAll(rows.where((e) => !ids.contains(e['id'])));
        hasMore = rows.length == MerchantRepository.pageSize;
      } else {
        if (storeId == null) {
          final list = await repository.stores();
          if (_disposed || g != _generation) return;
          stores = list;
          storeId = list.isEmpty ? null : list.first['id'] as String;
          error = null;
        }
        if (storeId != null) await _load(g);
      }
    } catch (e) {
      if (!_disposed && g == _generation) {
        error = errorMessage(e);
        // Never leave private customer data visible after an access failure.
        orders = [];
        menu = [];
        campaigns = [];
        report = {};
        qualityData = {};
        qualityError = null;
        canManage = canOrders = canDelivery = canCampaigns = false;
      }
    } finally {
      if (!_disposed && g == _generation) {
        loading = false;
        _readFuture = null;
        notifyListeners();
      }
      complete.complete();
      _drainRefresh();
    }
  }

  void _drainRefresh() {
    // Complete this pass first so a waiting save can take the single-write
    // guard before the next read. A continuous realtime stream cannot extend
    // one read future forever or starve a user's pending action.
    scheduleMicrotask(() {
      if (!_disposed &&
          !busy &&
          _readFuture == null &&
          _pendingRefresh != null) {
        unawaited(_startRead());
      }
    });
  }

  Future<void> loadMore() {
    if (!writable || !hasMore) return Future.value();
    return _startRead(appendOrders: true);
  }

  /// Successful writes are never shown optimistically. Read back server state.
  /// Failure leaves a visible error and disables writes until a refresh.
  Future<bool> mutate(Future<void> Function() operation) async {
    if (_disposed) return false;
    // A background poll is not a failed save. Keep the form and its draft while
    // awaiting the active read, then recheck access and the single-write guard.
    if (_readFuture != null) await _readFuture;
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
      _drainRefresh();
      return false;
    }
    busy = false;
    await refresh();
    return !_disposed && error == null;
  }
}
