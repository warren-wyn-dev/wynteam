import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_controller.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/main.dart';
import 'package:zoky_merchant/screens/merchant_home.dart';

import 'support/fake_repository.dart';

class _DelayedRepository extends FakeRepository {
  Completer<Json>? pendingReport;
  Completer<void>? pendingPage;
  Completer<List<Json>>? pendingStores;
  Completer<void>? pendingFirstOrders;
  VoidCallback? onReport;
  int reportReads = 0, pageReads = 0, firstPageReads = 0;
  int storeReads = 0, menuReads = 0, campaignReads = 0, qualityReads = 0;

  @override
  Future<Json> report(String id) async {
    reportReads++;
    onReport?.call();
    return pendingReport?.future ?? super.report(id);
  }

  @override
  Future<List<Json>> stores() {
    storeReads++;
    return pendingStores?.future ?? super.stores();
  }

  @override
  Future<List<Json>> menu(String id) {
    menuReads++;
    return super.menu(id);
  }

  @override
  Future<Json> campaigns(String id) {
    campaignReads++;
    return super.campaigns(id);
  }

  @override
  Future<Json> quality(String id) {
    qualityReads++;
    return super.quality(id);
  }

  @override
  Future<void> saveStore(String id, Json values) async {
    if (!access) throw const MerchantException('บัญชีนี้ไม่มีสิทธิ์จัดการร้าน');
    await super.saveStore(id, values);
  }

  @override
  Future<List<Json>> orders(String id, String status, int offset) async {
    if (!access) throw const MerchantException('บัญชีนี้ไม่มีสิทธิ์จัดการร้าน');
    if (offset == 0) {
      firstPageReads++;
      await pendingFirstOrders?.future;
    }
    final rows = await super.orders(id, status, offset);
    if (offset > 0) {
      pageReads++;
      await pendingPage?.future;
    }
    return rows;
  }
}

Future<void> _until(bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(ready(), true);
}

void main() {
  testWidgets(
    'a periodic refresh preserves an open editor and its valid save',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _DelayedRepository();
      await tester.pumpWidget(
        ZokyApp(
          home: MerchantHome(repository: repo, onSignOut: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('เมนูอาหาร').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('เพิ่มเมนู'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'ชื่อเมนูทดสอบ');
      await tester.enterText(find.byType(TextFormField).at(1), '50');
      final orderRead = repo.pendingFirstOrders = Completer<void>();
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(repo.reportReads, 1);
      expect(repo.firstPageReads, 2);
      await tester.tap(find.text('บันทึก'));
      await tester.pump();
      expect(repo.writes, 0);
      expect(find.text('กำลังบันทึก…'), findsOneWidget);
      expect(find.textContaining('กรุณาปิดแล้วรีเฟรช'), findsNothing);
      repo.pendingFirstOrders = null;
      orderRead.complete();
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.menuRows.last['name'], 'ชื่อเมนูทดสอบ');
      expect(repo.menuRows.last['price'], 50);
      expect(find.byType(EditorDialog), findsNothing);
      expect(find.text('ชื่อเมนูทดสอบ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'a burst during refresh coalesces and reads an order arriving mid-load',
    () async {
      final repo = _DelayedRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final report = repo.pendingReport = Completer<Json>();
      final first = c.refresh();
      await _until(() => repo.reportReads == 2);
      repo.orderRows.add({
        ...repo.orderRows.first,
        'id': 'arriving-during-refresh',
      });
      final pending = [for (var i = 0; i < 100; i++) c.refresh()];
      expect(repo.orderReads, 2);
      repo.pendingReport = null;
      report.complete({'today_sales': 174});
      await Future.wait([first, ...pending]);
      expect(repo.orderReads, 3);
      expect(repo.reportReads, 3);
      expect(
        c.orders.any((row) => row['id'] == 'arriving-during-refresh'),
        true,
      );
      expect(c.loading, false);
    },
  );

  test(
    'a change received during pagination gets a trailing fresh first page',
    () async {
      final repo = _DelayedRepository();
      repo.orderRows = [
        for (var i = 0; i < 51; i++)
          {...repo.orderRows.first, 'id': 'order-$i'},
      ];
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.hasMore, true);
      final page = repo.pendingPage = Completer<void>();
      final more = c.loadMore();
      await _until(() => repo.pageReads == 1);
      repo.orderRows.insert(0, {...repo.orderRows.first, 'id': 'newest'});
      final changed = c.refresh();
      page.complete();
      await Future.wait([more, changed]);
      expect(c.orders.first['id'], 'newest');
      expect(c.orders.length, 50);
      expect(c.loading, false);
    },
  );

  test(
    'writes waiting on a refresh still enforce one pending mutation',
    () async {
      final repo = _DelayedRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final report = repo.pendingReport = Completer<Json>();
      final refresh = c.refresh();
      await _until(() => repo.reportReads == 2);
      final finishWrite = Completer<void>();
      var writes = 0;
      final first = c.mutate(() async {
        writes++;
        await finishWrite.future;
      });
      final duplicate = c.mutate(() async {
        writes++;
      });
      expect(writes, 0);
      repo.pendingReport = null;
      report.complete({'today_sales': 174});
      await refresh;
      await _until(() => writes == 1);
      expect(await duplicate, false);
      finishWrite.complete();
      expect(await first, true);
      expect(writes, 1);
    },
  );

  test('a queued save respects a refreshed store-access revocation', () async {
    final repo = _DelayedRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    final stores = repo.pendingStores = Completer<List<Json>>();
    final refresh = c.refresh();
    var writes = 0;
    final write = c.mutate(() async {
      writes++;
    });
    repo.access = false;
    stores.complete([]);
    await refresh;
    expect(await write, false);
    expect(writes, 0);
    expect(c.store, isNull);
    expect(c.orders, isEmpty);
    expect(c.writable, false);
  });

  test(
    'a queued save still respects server rejection after a stale read',
    () async {
      final repo = _DelayedRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final report = repo.pendingReport = Completer<Json>();
      final refresh = c.refresh();
      await _until(() => repo.reportReads == 2);
      final write = c.mutate(
        () => repo.saveStore('store-1', {'name': 'forbidden'}),
      );
      repo.access = false;
      final revoked = c.refresh();
      repo.pendingReport = null;
      report.complete({'today_sales': 174});
      await Future.wait([refresh, revoked]);
      expect(await write, false);
      expect(repo.writes, 0);
      expect(c.store, isNull);
      expect(c.orders, isEmpty);
      expect(c.writable, false);
    },
  );

  test(
    'continuous notifications cannot starve a save or extend its read future',
    () async {
      final repo = _DelayedRepository();
      final c = MerchantController(repo);
      await c.initialize();
      final requests = <Future<void>>[];
      repo.onReport = () => requests.add(c.refresh());
      final beforeSave = repo.pendingReport = Completer<Json>();
      final firstPass = c.refresh();
      await _until(() => repo.reportReads == 2);
      final finishWrite = Completer<void>();
      var writes = 0;
      final save = c.mutate(() async {
        writes++;
        await finishWrite.future;
      });
      beforeSave.complete({'today_sales': 174});
      await firstPass;
      await _until(() => writes == 1);
      expect(repo.reportReads, 2);
      expect(c.busy, true);

      final afterSave = repo.pendingReport = Completer<Json>();
      finishWrite.complete();
      await _until(() => repo.reportReads == 3);
      final nextNotification = repo.pendingReport = Completer<Json>();
      afterSave.complete({'today_sales': 174});
      expect(await save, true);
      await _until(() => repo.reportReads == 4);
      expect(writes, 1);

      c.dispose();
      repo.pendingReport = null;
      nextNotification.complete({'today_sales': 174});
      await Future.wait(requests);
    },
  );

  test(
    'closing a view cancels queued reads and prevents a waiting write',
    () async {
      final repo = _DelayedRepository();
      final c = MerchantController(repo);
      await c.initialize();
      final report = repo.pendingReport = Completer<Json>();
      final refresh = c.refresh();
      await _until(() => repo.reportReads == 2);
      final queued = c.refresh();
      final write = c.mutate(
        () => repo.saveStore('store-1', {'name': 'closed'}),
      );
      c.dispose();
      expect(
        await c.mutate(
          () => repo.saveStore('store-1', {'name': 'after-close'}),
        ),
        false,
      );
      repo.pendingReport = null;
      report.complete({'today_sales': 174});
      await Future.wait([refresh, queued]);
      expect(await write, false);
      expect(repo.writes, 0);
      expect(repo.orderReads, 2);
    },
  );

  test(
    'pagination access failure clears cached private data and write roles',
    () async {
      final repo = _DelayedRepository();
      repo.orderRows = [
        for (var i = 0; i < 51; i++)
          {...repo.orderRows.first, 'id': 'order-$i'},
      ];
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.access = false;
      await c.loadMore();
      expect(c.error, isNotNull);
      expect(c.orders, isEmpty);
      expect(c.menu, isEmpty);
      expect(c.report, isEmpty);
      expect(c.canOrders, false);
      expect(c.writable, false);
    },
  );
  test('lightweight refresh reads only orders, not store/menu/dashboard', () async {
    final repo = _DelayedRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    expect(repo.storeReads, 1); // initial grants are not fetched twice
    final stores = repo.storeReads;
    final menu = repo.menuReads;
    final report = repo.reportReads;
    final quality = repo.qualityReads;
    final campaign = repo.campaignReads;
    final orderReads = repo.orderReads;
    repo.orderRows.add({...repo.orderRows.first, 'id': 'realtime-new'});
    await c.refreshOrders();
    expect(repo.orderReads, orderReads + 1);
    expect(repo.storeReads, stores);
    expect(repo.menuReads, menu);
    expect(repo.reportReads, report);
    expect(repo.qualityReads, quality);
    expect(repo.campaignReads, campaign);
    expect(c.orders.any((o) => o['id'] == 'realtime-new'), true);
    expect(c.loading, false);
    expect(c.writable, true);
  });

  test('order-only bursts queue one trailing read without full refresh', () async {
    final repo = _DelayedRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    final delayed = repo.pendingFirstOrders = Completer<void>();
    final first = c.refreshOrders();
    await _until(() => repo.firstPageReads == 2);
    repo.orderRows.add({...repo.orderRows.first, 'id': 'in-flight-order'});
    final pending = [for (var i = 0; i < 50; i++) c.refreshOrders()];
    repo.pendingFirstOrders = null;
    delayed.complete();
    await Future.wait([first, ...pending]);
    expect(repo.firstPageReads, 3);
    expect(repo.reportReads, 1);
    expect(c.orders.any((o) => o['id'] == 'in-flight-order'), true);
  });

  test('queued full grant check is not downgraded by order events', () async {
    final repo = _DelayedRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    final delayed = repo.pendingFirstOrders = Completer<void>();
    final order = c.refreshOrders();
    await _until(() => repo.firstPageReads == 2);
    final full = c.refresh();
    final event = c.refreshOrders();
    repo.pendingFirstOrders = null;
    delayed.complete();
    await Future.wait([order, full, event]);
    expect(repo.reportReads, 2);
    expect(repo.storeReads, 2);
  });

  test('order reconciliation denies access without keeping customer data', () async {
    final repo = _DelayedRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    repo.access = false;
    await c.refreshOrders();
    expect(c.error, isNotNull);
    expect(c.orders, isEmpty);
    expect(c.menu, isEmpty);
    expect(c.report, isEmpty);
    expect(c.writable, false);
  });

  test('dashboard sections launch in parallel and stay independent', () async {
    final repo = _DelayedRepository();
    final report = repo.pendingReport = Completer<Json>();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    final startup = c.initialize();
    await _until(() => repo.reportReads == 1);
    expect(repo.qualityReads, 1);
    expect(repo.campaignReads, 1);
    repo.pendingReport = null;
    report.complete({'today_sales': 174});
    await startup;
    expect(c.reportError, isNull);
    expect(c.campaignError, isNull);
  });

}
