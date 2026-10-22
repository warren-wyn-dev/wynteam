import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/main.dart';
import 'package:zoky_merchant/screens/merchant_home.dart';
import 'package:zoky_merchant/data/merchant_controller.dart';
import 'support/fake_repository.dart';

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeRepository repo, {
    double width = 1200,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ZokyApp(
        home: MerchantHome(repository: repo, onSignOut: () async {}),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'real mutation is awaited, payment gate is enforced, order is read back',
    (tester) async {
      final repo = FakeRepository();
      await mount(tester, repo);
      await tester.tap(find.text('ออเดอร์').first);
      await tester.pumpAndSettle();
      final buttons = tester
          .widgetList<FilledButton>(
            find.widgetWithText(FilledButton, 'รับออเดอร์'),
          )
          .toList();
      expect(buttons.where((b) => b.onPressed != null).length, 1);
      expect(buttons.where((b) => b.onPressed == null).length, 1);
      await tester.tap(find.widgetWithText(FilledButton, 'รับออเดอร์').first);
      await tester.pumpAndSettle();
      expect(repo.writes, 0);
      await tester.tap(find.text('ยืนยัน'));
      await tester.pumpAndSettle();
      expect(repo.writes, 1);
      expect(repo.orderRows.first['status'], 'preparing');
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
