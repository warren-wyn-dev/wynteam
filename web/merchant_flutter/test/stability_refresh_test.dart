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
  // The first page of orders is a critical read: saves and access checks wait
  // for it. (The report is a summary read; saves intentionally do not wait.)
  Completer<void>? pendingFirstPage;
  VoidCallback? onFirstPage;
  int firstPageReads = 0;
  VoidCallback? onReport;
  int reportReads = 0, pageReads = 0;

  @override
  Future<Json> report(String id) async {
    reportReads++;
    onReport?.call();
    return pendingReport?.future ?? super.report(id);
  }

  @override
  Future<List<Json>> stores() => pendingStores?.future ?? super.stores();

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
      onFirstPage?.call();
      await pendingFirstPage?.future;
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

// These tests pin the controller's stability rules under the current design:
// a save waits for an in-flight *critical* read (stores / first page of
// orders) and re-checks access afterwards, but intentionally does not wait for
// slow summary reads such as the report (see controller_performance_test.dart).
// The in-flight read is therefore simulated with the first page of orders.
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
      final reads = repo.firstPageReads;
      final firstPage = Completer<void>();
      repo.pendingFirstPage = firstPage;
      await tester.pump(const Duration(seconds: 20));
      await tester.pump();
      expect(repo.firstPageReads, reads + 1);
      await tester.tap(find.text('บันทึก'));
      await tester.pump();
      expect(repo.writes, 0);
      expect(find.text('กำลังบันทึก…'), findsOneWidget);
      expect(find.textContaining('กรุณาปิดแล้วรีเฟรช'), findsNothing);
      repo.pendingFirstPage = null;
      firstPage.complete();
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
      final reads = repo.firstPageReads;
      final firstPage = repo.pendingFirstPage = Completer<void>();
      final first = c.refresh();
      await _until(() => repo.firstPageReads == reads + 1);
      repo.orderRows.add({
        ...repo.orderRows.first,
        'id': 'arriving-during-refresh',
      });
      final pending = [for (var i = 0; i < 100; i++) c.refresh()];
      repo.pendingFirstPage = null;
      firstPage.complete();
      await Future.wait([first, ...pending]);
      await _until(
        () => c.orders.any((row) => row['id'] == 'arriving-during-refresh'),
      );
      // 100 notifications share at most one trailing read.
      expect(repo.firstPageReads, lessThanOrEqualTo(reads + 2));
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
      // The trailing fresh read starts after the refresh future completes.
      await _until(() => c.orders.first['id'] == 'newest');
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
      final reads = repo.firstPageReads;
      final firstPage = repo.pendingFirstPage = Completer<void>();
      final refresh = c.refresh();
      await _until(() => repo.firstPageReads == reads + 1);
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
      repo.pendingFirstPage = null;
      firstPage.complete();
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
      final reads = repo.firstPageReads;
      final firstPage = repo.pendingFirstPage = Completer<void>();
      final refresh = c.refresh();
      await _until(() => repo.firstPageReads == reads + 1);
      final write = c.mutate(
        () => repo.saveStore('store-1', {'name': 'forbidden'}),
      );
      repo.access = false;
      final revoked = c.refresh();
      repo.pendingFirstPage = null;
      firstPage.complete();
      await Future.wait([refresh, revoked]);
      // The save never runs, even though the read it waited on was stale.
      expect(await write, false);
      expect(repo.writes, 0);
      // The fresh read that sees the revocation starts after the futures above.
      await _until(() => c.store == null);
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
      final reads = repo.firstPageReads;
      // Every read raises one more notification, but only a bounded number:
      // an unbounded feedback loop would never settle (and exhausts memory).
      const notifications = 10;
      var raised = 0;
      final requests = <Future<void>>[];
      repo.onFirstPage = () {
        if (raised >= notifications) return;
        raised++;
        requests.add(c.refresh());
      };
      final beforeSave = repo.pendingFirstPage = Completer<void>();
      final firstPass = c.refresh();
      await _until(() => repo.firstPageReads > reads);
      final finishWrite = Completer<void>();
      var writes = 0;
      final save = c.mutate(() async {
        writes++;
        await finishWrite.future;
      });
      repo.pendingFirstPage = null;
      beforeSave.complete();
      await firstPass;
      await _until(() => writes == 1);
      expect(c.busy, true);

      finishWrite.complete();
      expect(await save, true);
      expect(writes, 1);
      await _until(() => raised == notifications);
      c.dispose();
      await Future.wait(requests);
      // Reads stay proportional to the notifications that caused them.
      expect(repo.firstPageReads, lessThanOrEqualTo(reads + notifications + 3));
    },
  );

  test(
    'closing a view cancels queued reads and prevents a waiting write',
    () async {
      final repo = _DelayedRepository();
      final c = MerchantController(repo);
      await c.initialize();
      final reads = repo.firstPageReads;
      final firstPage = repo.pendingFirstPage = Completer<void>();
      final refresh = c.refresh();
      await _until(() => repo.firstPageReads == reads + 1);
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
      repo.pendingFirstPage = null;
      firstPage.complete();
      await Future.wait([refresh, queued]);
      expect(await write, false);
      expect(repo.writes, 0);
      // Disposing drops the queued read: no read starts after the close.
      expect(repo.firstPageReads, reads + 1);
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
      // Access loss is shown as the no-access state, not as a load error.
      expect(c.orders, isEmpty);
      expect(c.menu, isEmpty);
      expect(c.report, isEmpty);
      expect(c.canOrders, false);
      expect(c.writable, false);
    },
  );
}
