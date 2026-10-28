import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_controller.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';

import 'support/fake_repository.dart';

class _CountingRepository extends FakeRepository {
  int storeReads = 0, menuReads = 0, reportReads = 0, qualityReads = 0;
  int campaignReads = 0, firstPageReads = 0;
  Completer<void>? blockOrders;
  Completer<Json>? blockReport;

  @override
  Future<List<Json>> stores() {
    storeReads++;
    return super.stores();
  }

  @override
  Future<List<Json>> menu(String id) {
    menuReads++;
    return super.menu(id);
  }

  @override
  Future<Json> report(String id) {
    reportReads++;
    return blockReport?.future ?? super.report(id);
  }

  @override
  Future<Json> quality(String id) async {
    qualityReads++;
    return {'available': false};
  }

  @override
  Future<Json> campaigns(String id) {
    campaignReads++;
    return super.campaigns(id);
  }

  @override
  Future<List<Json>> orders(String id, String status, int offset) async {
    if (offset == 0) {
      firstPageReads++;
      await blockOrders?.future;
    }
    return super.orders(id, status, offset);
  }
}

Future<void> until(bool Function() predicate) async {
  for (var i = 0; i < 100 && !predicate(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), true);
}

void main() {
  test('initial store discovery is reused, preserving owner role', () async {
    final repo = _CountingRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    expect(repo.storeReads, 1);
    expect(c.canConfigure, true);
    expect(c.canManage, true);
    expect(c.orders, isNotEmpty);
  });

  test('routine reconciliation fetches orders only', () async {
    final repo = _CountingRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    final stores = repo.storeReads;
    final menu = repo.menuReads;
    final report = repo.reportReads;
    final quality = repo.qualityReads;
    final campaigns = repo.campaignReads;
    final orders = repo.orderReads;
    repo.orderRows.add({...repo.orderRows.first, 'id': 'fresh-order'});
    await c.refreshOrders();
    expect(repo.orderReads, orders + 1);
    expect(repo.storeReads, stores);
    expect(repo.menuReads, menu);
    expect(repo.reportReads, report);
    expect(repo.qualityReads, quality);
    expect(repo.campaignReads, campaigns);
    expect(c.orders.any((row) => row['id'] == 'fresh-order'), true);
    expect(c.loading, false);
  });

  test('bursts coalesce and full grant check takes priority', () async {
    final repo = _CountingRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    final gate = repo.blockOrders = Completer<void>();
    final first = c.refreshOrders();
    await until(() => repo.firstPageReads == 2);
    repo.orderRows.add({...repo.orderRows.first, 'id': 'during-read'});
    final queued = [for (var i = 0; i < 25; i++) c.refreshOrders()];
    final revalidate = c.refresh();
    repo.blockOrders = null;
    gate.complete();
    await Future.wait([first, ...queued, revalidate]);
    expect(repo.firstPageReads, 3);
    expect(repo.reportReads, 2);
    expect(repo.storeReads, 2);
    expect(c.orders.any((row) => row['id'] == 'during-read'), true);
  });

  test('access errors clear private rows, recovery rechecks full snapshot', () async {
    final repo = _CountingRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    repo.failReads = true;
    await c.refreshOrders();
    expect(c.error, isNotNull);
    expect(c.orders, isEmpty);
    expect(c.menu, isEmpty);
    expect(c.canConfigure, false);
    expect(c.writable, false);
    repo.failReads = false;
    final reports = repo.reportReads;
    await c.refreshOrders();
    expect(c.error, isNull);
    expect(c.menu, isNotEmpty);
    expect(c.canConfigure, true);
    expect(repo.reportReads, reports + 1);
  });

  test('revoked access on full refresh removes store and permissions', () async {
    final repo = _CountingRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    repo.access = false;
    await c.refresh();
    expect(c.store, isNull);
    expect(c.orders, isEmpty);
    expect(c.canConfigure, false);
    expect(c.writable, false);
  });

  test('dashboard reports launch in parallel without waiting for sales', () async {
    final repo = _CountingRepository();
    final gate = repo.blockReport = Completer<Json>();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    final started = c.initialize();
    await until(() => repo.reportReads == 1);
    expect(repo.qualityReads, 1);
    expect(repo.campaignReads, 1);
    repo.blockReport = null;
    gate.complete({'today_sales': 174});
    await started;
    expect(c.reportError, isNull);
    expect(c.campaignError, isNull);
  });
}
