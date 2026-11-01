import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/main.dart';
import 'package:zoky_merchant/screens/merchant_home.dart';
import 'package:zoky_merchant/data/merchant_controller.dart';
import 'support/fake_repository.dart';

class _LargeSalesRepository extends FakeRepository {
  @override
  Future<Map<String, dynamic>> report(String id) async => {
    ...await super.report(id),
    'today_sales': 9999999.99,
  };
}

class _QualityRepository extends FakeRepository {
  bool failQuality = false;
  @override
  Future<Map<String, dynamic>> quality(String id) async {
    if (failQuality) throw Exception('โหลดรีวิวไม่สำเร็จ');
    return {'available': true, 'count': 12, 'average': 4.8, 'unanswered': 2};
  }
}

class _CountsRepository extends FakeRepository {
  @override
  Future<Map<String, dynamic>> orderCounts(String id) async => {
    'pending': 2,
    'review': 1,
    'preparing': 3,
    'delivering': 0,
  };
}

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeRepository repo, {
    double width = 1200,
    Future<void> Function()? onSignOut,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ZokyApp(
        home: MerchantHome(
          repository: repo,
          onSignOut: onSignOut ?? () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final offline in [false, true]) {
    testWidgets(
      'sign out remains available without a store (offline: $offline)',
      (tester) async {
        final repo = FakeRepository()..storeRows = [];
        repo.failReads = offline;
        var signOutCalls = 0;
        await mount(
          tester,
          repo,
          width: 360,
          onSignOut: () async {
            signOutCalls++;
          },
        );
        final action = find.widgetWithText(TextButton, 'ออกจากระบบ');
        expect(action, findsOneWidget);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(signOutCalls, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'home to-do counts open the matching tab and menu filters sold-out items',
    (tester) async {
      final repo = _CountsRepository();
      repo.menuRows.add({
        'id': 'menu-2',
        'name': 'ชาเย็น',
        'price': 35,
        'category': 'เครื่องดื่ม',
        'description': '',
        'is_available': false,
      });
      await mount(tester, repo, width: 390);
      expect(find.text('ต้องทำตอนนี้'), findsOneWidget);
      expect(find.bySemanticsLabel('ออเดอร์ใหม่ 2 รายการ'), findsOneWidget);
      expect(find.bySemanticsLabel('ตรวจสลิป 1 รายการ'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('กำลังเตรียม 3 รายการ'));
      await tester.pumpAndSettle();
      final preparing = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'กำลังเตรียม'),
      );
      expect(preparing.selected, isTrue);

      await tester.tap(find.text('เมนูอาหาร').last);
      await tester.pumpAndSettle();
      expect(find.text('2 เมนู · หมด 1'), findsOneWidget);
      expect(find.text('ข้าวกะเพรา'), findsOneWidget);
      final soldOut = find.widgetWithText(ChoiceChip, 'หมดอยู่ 1');
      await tester.ensureVisible(soldOut);
      await tester.pumpAndSettle();
      await tester.tap(soldOut);
      await tester.pumpAndSettle();
      expect(find.text('ข้าวกะเพรา'), findsNothing);
      expect(find.text('ชาเย็น'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('losing the final store preserves an account exit', (
    tester,
  ) async {
    final repo = FakeRepository();
    var signOutCalls = 0;
    await mount(
      tester,
      repo,
      width: 360,
      onSignOut: () async {
        signOutCalls++;
      },
    );
    expect(find.text('ร้านทดสอบ'), findsOneWidget);
    repo.access = false;
    await tester
        .widget<RefreshIndicator>(find.byType(RefreshIndicator))
        .onRefresh();
    await tester.pumpAndSettle();
    expect(find.text('ร้านทดสอบ'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'ออกจากระบบ'));
    await tester.pumpAndSettle();
    expect(signOutCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'real mutation is awaited, payment gate is enforced, order is read back',
    (tester) async {
      final repo = FakeRepository();
      await mount(tester, repo);
      await tester.tap(find.text('ออเดอร์').first);
      await tester.pumpAndSettle();
      // Paid order: direct accept. Unpaid order: no direct accept, only the
      // payment review (the server gate is unchanged).
      expect(
        find.widgetWithText(FilledButton, 'รับออเดอร์ · 30 นาที'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'ตรวจเงินเข้า · รับออเดอร์'),
        findsOneWidget,
      );
      expect(repo.writes, 0);
      await tester.tap(find.widgetWithText(ChoiceChip, '45 นาที').first);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.tap(
        find.widgetWithText(FilledButton, 'รับออเดอร์ · 45 นาที'),
      );
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.orderRows.first['status'], 'preparing');
      expect(repo.orderRows.first['eta_minutes'], 45);
      await tester.tap(find.text('กำลังเตรียม').first);
      await tester.pumpAndSettle();
      expect(find.text('#TEST-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('phone menu editor validates and saves persisted server result', (
    tester,
  ) async {
    final repo = FakeRepository();
    await mount(tester, repo, width: 360);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('เมนูอาหาร').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('เพิ่มเมนู'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(repo.writes, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'ข้าวไข่เจียว');
    await tester.enterText(find.byType(TextFormField).at(1), '50');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(repo.menuRows.last['name'], 'ข้าวไข่เจียว');
    expect(find.text('ข้าวไข่เจียว'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('failed writes stay visible and do not alter server menu', (
    tester,
  ) async {
    final repo = FakeRepository()..failWrites = true;
    await mount(tester, repo);
    await tester.tap(find.text('เมนูอาหาร').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(repo.menuRows.first['is_available'], true);
    expect(find.textContaining('บัญชีนี้ไม่มีสิทธิ์'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch).first).value, true);
    expect(tester.widget<Switch>(find.byType(Switch).first).onChanged, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'reference layout preserves four destinations and menu readability at large text',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = _LargeSalesRepository();
      await mount(tester, repo, width: 320);
      expect(
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .destinations
            .length,
        4,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('เมนูอาหาร').last);
      await tester.pumpAndSettle();
      expect(find.text('ข้าวกะเพรา'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('เพิ่มเติม').last);
      await tester.pumpAndSettle();
      expect(find.text('ขายและเงิน'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'home structure opens the actual readiness checklist and preserves data at large text',
    (tester) async {
      final repo = _QualityRepository();
      await mount(tester, repo, width: 360);
      await tester.tap(find.bySemanticsLabel('ดูยอดขายวันนี้'));
      await tester.pumpAndSettle();
      expect(find.text('ยอดขายของร้าน'), findsOneWidget);
      await tester.tap(find.text('หน้าหลัก').last);
      await tester.pumpAndSettle();
      expect(find.text('เตรียมร้านให้พร้อม'), findsOneWidget);
      await tester.ensureVisible(find.text('เตรียมร้านให้พร้อม'));
      await tester.tap(find.text('เตรียมร้านให้พร้อม'));
      await tester.pumpAndSettle();
      expect(find.text('ช่องทางรับเงิน'), findsOneWidget);
      expect(find.text('เผยแพร่ร้านให้ลูกค้าเห็น'), findsOneWidget);
      await tester.tap(find.text('เปิดขายเมนูอย่างน้อย 1 รายการ'));
      await tester.pumpAndSettle();
      expect(find.text('ข้าวกะเพรา'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'review failure clears old quality without faking zeros and access revocation clears the summary',
    () async {
      final repo = _QualityRepository();
      final controller = MerchantController(repo);
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.qualityData['average'], 4.8);
      repo.failQuality = true;
      await controller.refresh();
      expect(controller.qualityData, isEmpty);
      expect(controller.qualityError, isNotNull);
      expect(controller.error, isNull);
      repo.failQuality = false;
      await controller.refresh();
      expect(controller.qualityData['unanswered'], 2);
      repo.access = false;
      await controller.refresh();
      expect(controller.qualityData, isEmpty);
      expect(controller.store, isNull);
    },
  );
  testWidgets('quality tool opens real all-review metrics from the home', (
    tester,
  ) async {
    await mount(tester, _QualityRepository(), width: 360);
    expect(find.text('คุณภาพร้านสัปดาห์นี้'), findsNothing);
    expect(find.text('คะแนนร้าน'), findsNothing);
    final shortcut = find.text('คุณภาพร้าน');
    await tester.ensureVisible(shortcut);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(find.text('รีวิวทั้งหมด'), findsOneWidget);
    expect(find.text('4.8 /5'), findsOneWidget);
    expect(find.text('รีวิวรอตอบ'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('ดูรีวิวและตอบกลับ'), findsOneWidget);
    expect(find.text('คุณภาพร้านสัปดาห์นี้'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('revocation clears customer data and disables writes', () async {
    final repo = FakeRepository();
    final c = MerchantController(repo);
    addTearDown(c.dispose);
    await c.initialize();
    expect(c.orders, isNotEmpty);
    repo.access = false;
    await c.refresh();
    expect(c.orders, isEmpty);
    expect(c.store, isNull);
    expect(c.writable, false);
  });
  test(
    'network error never becomes a zero sales success and refresh recovers',
    () async {
      final repo = FakeRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      repo.failReads = true;
      await c.refresh();
      expect(c.error, isNotNull);
      expect(c.writable, false);
      expect(c.orders, isEmpty);
      repo.failReads = false;
      await c.refresh();
      expect(c.error, isNull);
      expect(c.orders, isNotEmpty);
    },
  );
  test(
    'duplicate submissions are blocked while an operation is pending',
    () async {
      final repo = FakeRepository();
      final c = MerchantController(repo);
      addTearDown(c.dispose);
      await c.initialize();
      final first = c.mutate(() => repo.saveStore('store-1', {'name': 'ใหม่'}));
      final second = await c.mutate(
        () => repo.saveStore('store-1', {'name': 'ซ้ำ'}),
      );
      await first;
      expect(second, false);
      expect(repo.writes, 1);
    },
  );
}
