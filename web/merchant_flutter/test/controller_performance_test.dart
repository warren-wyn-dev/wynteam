import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_controller.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';

import 'support/fake_repository.dart';

class ControlledRepository extends FakeRepository {
  int storeReads = 0, menuReads = 0, roleReads = 0;
  int reportReads = 0, qualityReads = 0, campaignReads = 0;
  Completer<void>? storeGate, orderGate, menuGate, summaryGate;
  final summariesStarted = Completer<void>();
  final ordersStarted = Completer<void>();
  bool failQuality = false, holdNextOrderOnly = false, failOrders = false;
  String? heldSummaryStore;

  @override
  Future<List<Json>> stores() async {
    storeReads++;
    await storeGate?.future;
    return super.stores();
  }

  @override
  Future<List<Json>> menu(String id) async {
    menuReads++;
    await menuGate?.future;
    return super.menu(id);
  }

  @override
  Future<bool> hasRole(String id, List<String> roles) async {
    roleReads++;
    return super.hasRole(id, roles);
  }

  @override
  Future<List<Json>> orders(String id, String status, int offset) async {
    if (!ordersStarted.isCompleted) ordersStarted.complete();
    final gate = orderGate;
    if (holdNextOrderOnly) orderGate = null;
    await gate?.future;
    if (failOrders) throw const MerchantException('access denied');
    return (await super.orders(
      id,
      status,
      offset,
    )).map((row) => {...row, 'read_store': id}).toList();
  }

  Future<void> summary(String id) async {
    if (reportReads > 0 &&
        qualityReads > 0 &&
        campaignReads > 0 &&
        !summariesStarted.isCompleted) {
      summariesStarted.complete();
    }
    if (heldSummaryStore == null || heldSummaryStore == id) {
      await summaryGate?.future;
    }
  }

  @override
  Future<Json> report(String id) async {
    final readNumber = ++reportReads;
    await summary(id);
    return {'store': id, 'today_sales': 100, 'read': readNumber};
  }

  @override
  Future<Json> quality(String id) async {
    qualityReads++;
    await summary(id);
    if (failQuality) throw const MerchantException('quality unavailable');
    return {'store': id, 'available': true, 'count': 2, 'average': 4.5};
  }

  @override
  Future<Json> campaigns(String id) async {
    campaignReads++;
    await summary(id);
    return {
      'can_manage': manager,
      'campaigns': [
        {'id': 'campaign-$id'},
      ],
    };
  }
}

Future<void> turn() => Future<void>.delayed(Duration.zero);

class SnapshotRepository extends ControlledRepository {
  Json? snap;
  @override
  Future<Json?> snapshot() async => snap;
}

void main() {
  test(
    'an order action reads back orders and store rows without reloading the menu or summaries',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      await turn();
      final menu = repo.menuReads, report = repo.reportReads;
      final stores = repo.storeReads, orders = repo.orderReads;
      final ok = await c.mutate(
        () => repo.transition('store-1', 'order-1', 'preparing'),
        reload: MutationReload.orders,
      );
      await turn();
      expect(ok, isTrue);
      expect(repo.storeReads, stores + 1);
      expect(repo.orderReads, orders + 1);
      expect(repo.menuReads, menu);
      expect(repo.reportReads, report);

      final menuWrite = await c.mutate(
        () => repo.saveMenu('store-1', {'is_available': false}, id: 'menu-1'),
        reload: MutationReload.menu,
      );
      await turn();
      expect(menuWrite, isTrue);
      expect(repo.menuReads, menu + 1);
      expect(repo.reportReads, report);
      expect(c.menu.first['is_available'], isFalse);
    },
  );
  test(
    'a reopen paints the last snapshot at once but stays read-only until the live read, which replaces it',
    () async {
      final repo = SnapshotRepository()
        ..snap = {
          'stores': [
            {'id': 'store-1', 'name': 'ร้านจากเครื่อง', 'is_open': true},
          ],
          'storeId': 'store-1',
          'menu': [
            {'id': 'm1', 'name': 'เมนูเดิม', 'price': 50, 'is_available': true},
          ],
          'report': {'today_sales': 99},
          'orderCounts': {'pending': 1},
        };
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      repo.storeGate = Completer<void>();
      final start = c.initialize();
      await turn();
      expect(c.store?['name'], 'ร้านจากเครื่อง');
      expect(c.menu.single['name'], 'เมนูเดิม');
      expect(c.loading, isFalse);
      expect(c.writable, isFalse);
      repo.storeGate!.complete();
      await start;
      expect(c.store?['name'], 'ร้านทดสอบ');
      expect(c.writable, isTrue);

      final revoked = SnapshotRepository()..snap = repo.snap;
      revoked.storeRows.clear();
      final d = MerchantController(revoked);
      addTearDown(d.dispose);
      await d.initialize();
      expect(d.store, isNull);
      expect(d.menu, isEmpty);
      expect(d.report, isEmpty);
    },
  );

  test(
    'a known store reads orders while access is revalidated, and a revoked store publishes nothing',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final before = repo.orderReads;
      repo.storeGate = Completer<void>();
      final refresh = c.refreshOrders();
      await turn();
      // Orders started before the stores revalidation finished.
      expect(repo.orderReads, before + 1);
      repo.storeGate!.complete();
      await refresh;
      expect(c.orders, isNotEmpty);

      repo.storeGate = Completer<void>();
      final revoked = c.refreshOrders();
      await turn();
      repo.storeRows.clear();
      repo.storeGate!.complete();
      await revoked;
      expect(c.store, isNull);
      expect(c.orders, isEmpty);
      expect(c.error, isNull);
    },
  );

  test(
    'a visited order tab shows its last rows at once while it refreshes, and a store change clears them',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final pending = c.orders.map((o) => o['id']).toList();
      expect(pending, isNotEmpty);
      await c.selectStatus('preparing');
      expect(c.orders, isEmpty);

      repo.orderGate = Completer<void>();
      final back = c.selectStatus('pending_acceptance');
      // Shown before the server read finishes.
      expect(c.orders.map((o) => o['id']).toList(), pending);
      expect(c.ordersLoading, isTrue);
      repo.orderGate!.complete();
      await back;
      expect(c.orders.map((o) => o['id']).toList(), pending);

      await c.selectStatus('preparing');
      await c.selectStore('store-2');
      repo.orderGate = Completer<void>();
      final fresh = c.selectStatus('preparing');
      expect(c.orders, isEmpty);
      repo.orderGate!.complete();
      await fresh;
    },
  );

  test(
    'authorized critical content publishes before three parallel summaries',
    () async {
      final repo = ControlledRepository()..summaryGate = Completer<void>();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      var published = false;
      c.addListener(() {
        if (c.writable && c.orders.isNotEmpty && c.summariesLoading) {
          published = true;
        }
      });
      final initial = c.initialize();
      await repo.summariesStarted.future;
      expect(repo.storeReads, 1);
      expect(repo.reportReads, 1);
      expect(repo.qualityReads, 1);
      expect(repo.campaignReads, 1);
      expect(c.loading, false);
      expect(c.writable, true);
      expect(c.menu, isNotEmpty);
      expect(c.orders, isNotEmpty);
      expect(c.summariesLoading, true);
      expect(published, true);
      repo.summaryGate!.complete();
      await initial;
      expect(c.report['store'], 'store-1');
      expect(c.qualityData['average'], 4.5);
      expect(c.summariesLoading, false);
    },
  );

  test(
    'order polling revalidates access without reloading menu and summaries',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final detailsAt = c.detailsUpdatedAt;
      final roles = repo.roleReads;
      repo.orderRows.first['recipient_name'] = 'updated';
      await c.refreshOrders();
      expect(repo.storeReads, 2);
      expect(repo.roleReads, roles + 4);
      expect(repo.menuReads, 1);
      expect(repo.reportReads, 1);
      expect(repo.qualityReads, 1);
      expect(repo.campaignReads, 1);
      expect(c.orders.first['recipient_name'], 'updated');
      expect(c.detailsUpdatedAt, detailsAt);
    },
  );

  test(
    'a save waits for a background critical read and skips slow summaries',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.orderGate = Completer<void>();
      final refresh = c.refreshOrders();
      await turn();
      expect(c.refreshing, true);
      expect(c.writable, true);
      var operated = false;
      repo.summaryGate = Completer<void>();
      final save = c.mutate(() async {
        operated = true;
        await repo.saveStore('store-1', {'name': 'saved'});
      });
      await turn();
      expect(operated, false);
      repo.orderGate!.complete();
      await refresh;
      expect(await save, true);
      expect(operated, true);
      expect(c.store!['name'], 'saved');
      expect(c.summariesLoading, true);
      repo.summaryGate!.complete();
      await turn();
    },
  );

  test(
    'a queued save cannot run after access is revoked during a poll',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.storeGate = Completer<void>();
      final refresh = c.refreshOrders();
      final save = c.mutate(
        () => repo.saveStore('store-1', {'name': 'denied'}),
      );
      repo.access = false;
      repo.storeGate!.complete();
      await refresh;
      expect(await save, false);
      expect(repo.writes, 0);
      expect(c.store, isNull);
      expect(c.orders, isEmpty);
      expect(c.menu, isEmpty);
      expect(c.report, isEmpty);
      expect(c.qualityData, isEmpty);
      expect(c.campaigns, isEmpty);
      expect(c.writable, false);
    },
  );

  test(
    'bursty invalidations coalesce and a full refresh wins over order-only',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.orderGate = Completer<void>();
      final first = c.refreshOrders();
      await turn();
      for (var i = 0; i < 5; i++) {
        await c.refreshOrders();
      }
      await c.refresh();
      repo.orderGate!.complete();
      await first;
      await turn();
      expect(repo.orderReads, 3);
      expect(repo.menuReads, 2);
      expect(repo.storeReads, 3);
      expect(repo.reportReads, 2);
    },
  );

  test('late summaries cannot restore data after access revocation', () async {
    final repo = ControlledRepository()..summaryGate = Completer<void>();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    final initial = c.initialize();
    await repo.summariesStarted.future;
    repo.access = false;
    await c.refreshOrders();
    repo.summaryGate!.complete();
    await initial;
    expect(c.report, isEmpty);
    expect(c.qualityData, isEmpty);
    expect(c.campaigns, isEmpty);
    expect(c.canCampaigns, false);
    expect(c.store, isNull);
    expect(c.summariesLoading, false);
  });

  test('old-store summaries never overwrite a newly selected store', () async {
    final repo = ControlledRepository()
      ..summaryGate = Completer<void>()
      ..heldSummaryStore = 'store-1';
    repo.storeRows.add({'id': 'store-2', 'name': 'second'});
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    final initial = c.initialize();
    await repo.summariesStarted.future;
    await c.selectStore('store-2');
    expect(c.report['store'], 'store-2');
    repo.summaryGate!.complete();
    await initial;
    expect(c.storeId, 'store-2');
    expect(c.report['store'], 'store-2');
    expect(c.qualityData['store'], 'store-2');
    expect(c.campaigns.single['id'], 'campaign-store-2');
  });

  test(
    'a summary failure clears only its own old values and recovers',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.failQuality = true;
      await c.refresh();
      expect(c.qualityData, isEmpty);
      expect(c.qualityError, isNotNull);
      expect(c.report, isNotEmpty);
      expect(c.orders, isNotEmpty);
      expect(c.error, isNull);
      expect(c.writable, true);
      repo.failQuality = false;
      await c.refreshSummaries();
      expect(c.qualityError, isNull);
      expect(c.qualityData['average'], 4.5);
    },
  );

  test(
    'late summaries from a revoked role cannot restore its panel snapshot',
    () async {
      final repo = ControlledRepository()..summaryGate = Completer<void>();
      final oldGate = repo.summaryGate!;
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      final initial = c.initialize();
      await repo.summariesStarted.future;
      repo.manager = false;
      repo.summaryGate = null;
      await c.refreshOrders();
      expect(c.canManage, false);
      expect(c.canCampaigns, false);
      expect(c.report['read'], 2);
      oldGate.complete();
      await initial;
      expect(c.report['read'], 2);
      expect(c.canCampaigns, false);
    },
  );

  test(
    'a queued editor save is rejected when its role snapshot changes',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.manager = false;
      repo.orderGate = Completer<void>();
      final poll = c.refreshOrders();
      final save = c.mutate(
        () => repo.saveStore('store-1', {'name': 'old manager'}),
      );
      await turn();
      repo.orderGate!.complete();
      await poll;
      expect(c.canManage, false);
      expect(await save, false);
      expect(repo.writes, 0);
    },
  );

  test(
    'order-only access errors clear private data and full recovery restores it',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.failReads = true;
      await c.refreshOrders();
      expect(c.error, isNotNull);
      expect(c.store, isNull);
      expect(c.orders, isEmpty);
      expect(c.report, isEmpty);
      expect(c.writable, false);
      repo.failReads = false;
      await c.refreshOrders();
      expect(c.error, isNull);
      expect(c.store, isNotNull);
      expect(c.menu, isNotEmpty);
      expect(c.report, isNotEmpty);
    },
  );

  test(
    'status selection supersedes a slow background poll immediately',
    () async {
      final repo = ControlledRepository();
      repo.orderRows.add({'id': 'preparing-order', 'status': 'preparing'});
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final oldGate = Completer<void>();
      repo.orderGate = oldGate;
      repo.holdNextOrderOnly = true;
      final oldRead = c.refreshOrders();
      await turn();
      final selection = c.selectStatus('preparing');
      expect(c.status, 'preparing');
      await selection;
      expect(c.orders.single['id'], 'preparing-order');
      expect(c.ordersLoading, false);
      oldGate.complete();
      await oldRead;
      expect(c.status, 'preparing');
      expect(c.orders.single['id'], 'preparing-order');
    },
  );

  test(
    'store selection supersedes an old-store poll without waiting for it',
    () async {
      final repo = ControlledRepository();
      repo.storeRows.add({'id': 'store-2', 'name': 'second'});
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final oldGate = Completer<void>();
      repo.orderGate = oldGate;
      repo.holdNextOrderOnly = true;
      final oldRead = c.refreshOrders();
      await turn();
      final selection = c.selectStore('store-2');
      expect(c.storeId, 'store-2');
      expect(c.orders, isEmpty);
      await selection;
      expect(c.orders.first['read_store'], 'store-2');
      oldGate.complete();
      await oldRead;
      expect(c.storeId, 'store-2');
      expect(c.orders.first['read_store'], 'store-2');
      expect(c.report['store'], 'store-2');
    },
  );

  test(
    'an old queued save cannot run after a selection changes away and back',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final oldGate = Completer<void>();
      repo.orderGate = oldGate;
      repo.holdNextOrderOnly = true;
      final oldRead = c.refreshOrders();
      await turn();
      final oldSave = c.mutate(
        () => repo.saveStore('store-1', {'name': 'stale editor'}),
      );
      await c.selectStatus('preparing');
      await c.selectStatus('pending_acceptance');
      oldGate.complete();
      await oldRead;
      expect(await oldSave, false);
      expect(repo.writes, 0);
    },
  );

  test(
    'a failed critical authorization clears private data before a slow peer',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.menuGate = Completer<void>();
      repo.failOrders = true;
      await c.refresh();
      expect(c.error, isNotNull);
      expect(c.store, isNull);
      expect(c.orders, isEmpty);
      expect(c.report, isEmpty);
      expect(c.writable, false);
      repo.menuGate!.complete();
      await turn();
      expect(c.menu, isEmpty);
    },
  );

  test(
    'duplicate saves waiting on one background read still write only once',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.orderGate = Completer<void>();
      final read = c.refreshOrders();
      await turn();
      final first = c.mutate(
        () => repo.saveStore('store-1', {'name': 'first'}),
      );
      final second = c.mutate(
        () => repo.saveStore('store-1', {'name': 'duplicate'}),
      );
      repo.orderGate!.complete();
      await read;
      expect(await first, true);
      expect(await second, false);
      expect(repo.writes, 1);
    },
  );

  test(
    'invalidations received during a write are covered by its readback',
    () async {
      final repo = ControlledRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final before = repo.orderReads;
      final write = Completer<void>();
      final save = c.mutate(() => write.future);
      for (var i = 0; i < 5; i++) {
        await c.refreshOrders();
      }
      write.complete();
      expect(await save, true);
      await turn();
      expect(repo.orderReads, before + 1);
    },
  );

  test(
    'visible summary refresh has a bounded TTL across a calendar rollover',
    () async {
      final repo = ControlledRepository();
      var now = DateTime.utc(2026, 10, 27, 23, 59, 30);
      final c = MerchantController(repo, now: () => now);
      addTearDown(c.dispose);
      await c.initialize();
      now = now.add(const Duration(seconds: 59));
      await c.refreshSummariesIfStale();
      expect(repo.reportReads, 1);
      now = now.add(const Duration(seconds: 1));
      await c.refreshSummariesIfStale();
      expect(repo.reportReads, 2);
      expect(repo.qualityReads, 2);
      expect(repo.campaignReads, 2);
      expect(repo.menuReads, 1);
      expect(repo.storeReads, 1);
      expect(c.summariesUpdatedAt, now);
    },
  );

  test(
    'overlapping visible summary refreshes share the in-flight request',
    () async {
      final repo = ControlledRepository()..summaryGate = Completer<void>();
      var now = DateTime.utc(2026, 10, 27);
      final c = MerchantController(repo, now: () => now);
      addTearDown(c.dispose);
      final initial = c.initialize();
      await repo.summariesStarted.future;
      now = now.add(const Duration(minutes: 2));
      final first = c.refreshSummariesIfStale();
      final second = c.refreshSummariesIfStale();
      expect(repo.reportReads, 1);
      expect(repo.qualityReads, 1);
      expect(repo.campaignReads, 1);
      repo.summaryGate!.complete();
      await Future.wait([initial, first, second]);
      expect(repo.reportReads, 1);
      await c.refreshSummariesIfStale();
      expect(repo.reportReads, 1);
    },
  );

  test('an explicit refresh supersedes pre-mutation summary results', () async {
    final repo = ControlledRepository()..summaryGate = Completer<void>();
    final oldGate = repo.summaryGate!;
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    final initial = c.initialize();
    await repo.summariesStarted.future;
    repo.summaryGate = null;
    await c.refreshSummaries();
    expect(c.report['read'], 2);
    oldGate.complete();
    await initial;
    expect(c.report['read'], 2);
    expect(c.summariesLoading, false);
  });

  test(
    'summary failures retry on the bounded TTL without polling storms',
    () async {
      final repo = ControlledRepository()..failQuality = true;
      var now = DateTime.utc(2026, 10, 27);
      final c = MerchantController(repo, now: () => now);
      addTearDown(c.dispose);
      await c.initialize();
      expect(c.qualityError, isNotNull);
      repo.failQuality = false;
      for (var i = 0; i < 3; i++) {
        now = now.add(const Duration(seconds: 19));
        await c.refreshSummariesIfStale();
      }
      expect(repo.qualityReads, 1);
      now = now.add(const Duration(seconds: 3));
      await c.refreshSummariesIfStale();
      expect(repo.qualityReads, 2);
      expect(c.qualityError, isNull);
      expect(c.writable, true);
    },
  );

  test('a disposed view ignores held summaries and cannot submit', () async {
    final repo = ControlledRepository()..summaryGate = Completer<void>();
    final c = MerchantController(repo);
    final initial = c.initialize();
    await repo.summariesStarted.future;
    c.dispose();
    repo.summaryGate!.complete();
    await initial;
    expect(c.report, isEmpty);
    expect(c.writable, false);
    expect(
      await c.mutate(() => repo.saveStore('store-1', {'name': 'old'})),
      false,
    );
    expect(repo.writes, 0);
  });
}
