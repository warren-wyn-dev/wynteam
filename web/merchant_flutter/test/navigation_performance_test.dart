import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/main.dart';
import 'package:zoky_merchant/screens/merchant_home.dart';
import 'support/fake_repository.dart';

class NavigationRepository extends FakeRepository {
  final events = StreamController<void>.broadcast(sync: true);
  final financeStores = <String>[];
  int menuReads = 0, summaryReads = 0;
  num sales = 1234;

  @override
  Stream<void> get orderChanges => events.stream;

  @override
  Future<List<Json>> menu(String id) {
    menuReads++;
    return super.menu(id);
  }

  @override
  Future<Json> report(String id) {
    summaryReads++;
    return super.report(id);
  }

  @override
  Future<Json> finance(String storeId, String period) async {
    financeStores.add(storeId);
    return {'sales_net': sales, 'income': sales, 'days': []};
  }
}

class HeldReportRepository extends NavigationRepository {
  final pendingReport = Completer<Json>();
  @override
  Future<Json> report(String id) {
    summaryReads++;
    return pendingReport.future;
  }
}

Future<void> mount(WidgetTester tester, NavigationRepository repository) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ZokyApp(
      home: MerchantHome(repository: repository, onSignOut: () async {}),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> navigate(WidgetTester tester, int page) async {
  final dynamic state = tester.state(find.byType(MerchantHome));
  state.navigate(page);
  await tester.pumpAndSettle();
}

Future<void> unmount(
  WidgetTester tester,
  NavigationRepository repository,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await repository.events.close();
}

void main() {
  testWidgets(
    'replacement account discards the same-store primary page state',
    (tester) async {
      final before = NavigationRepository();
      await mount(tester, before);
      final oldScroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      final after = NavigationRepository();
      await tester.pumpWidget(
        ZokyApp(
          home: MerchantHome(repository: after, onSignOut: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable).first),
        isNot(same(oldScroll)),
      );
      expect(oldScroll.mounted, isFalse);
      expect(tester.takeException(), isNull);
      await unmount(tester, after);
      await before.events.close();
    },
  );

  testWidgets('primary tabs retain menu draft and discard it for a new scope', (
    tester,
  ) async {
    final repo = NavigationRepository();
    repo.storeRows.add({'id': 'store-2', 'name': 'ร้านสอง'});
    await mount(tester, repo);
    await navigate(tester, 2);
    await tester.enterText(find.byType(TextField), 'กะเพรา');
    await tester.pumpAndSettle();
    final field = tester.state<EditableTextState>(find.byType(EditableText));
    await navigate(tester, 0);
    expect(find.byType(TextField), findsNothing);
    await navigate(tester, 2);
    expect(find.text('กะเพรา'), findsOneWidget);
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      same(field),
    );
    final dynamic state = tester.state(find.byType(MerchantHome));
    await state.c.selectStore('store-2');
    await tester.pumpAndSettle();
    expect(find.text('กะเพรา'), findsNothing);
    expect(
      tester.state<EditableTextState>(find.byType(EditableText)),
      isNot(same(field)),
    );
    expect(repo.menuReads, 2);
    expect(tester.takeException(), isNull);
    await unmount(tester, repo);
  });

  testWidgets('pending reports do not display final zero sales or block menu', (
    tester,
  ) async {
    final repo = HeldReportRepository();
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ZokyApp(
        home: MerchantHome(repository: repo, onSignOut: () async {}),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('กำลังโหลดยอดขาย'), findsOneWidget);
    expect(find.text('0 ออเดอร์สำเร็จ'), findsNothing);
    final dynamic state = tester.state(find.byType(MerchantHome));
    state.navigate(4);
    await tester.pump();
    expect(find.text('฿0.00'), findsNothing);
    expect(find.text('กำลังโหลดยอดขาย'), findsOneWidget);
    expect(find.text('ยังไม่มีข้อมูลการขาย'), findsNothing);
    state.navigate(2);
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'เพิ่มเมนู'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.text('ข้าวกะเพรา'), findsOneWidget);
    repo.pendingReport.complete({'today_sales': 700, 'today_orders': 2});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await unmount(tester, repo);
  });

  testWidgets('visited finance state survives tab switches and order polling', (
    tester,
  ) async {
    final repo = NavigationRepository();
    await mount(tester, repo);
    expect(repo.financeStores, isEmpty);
    await navigate(tester, 8);
    expect(repo.financeStores, ['store-1']);
    expect(find.text('฿1234.00'), findsNWidgets(2));
    await tester.tap(find.text('เดือนนี้'));
    await tester.pumpAndSettle();
    expect(repo.financeStores.length, 2);
    await navigate(tester, 2);
    await navigate(tester, 8);
    expect(repo.financeStores.length, 2);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'เดือนนี้'))
          .selected,
      isTrue,
    );

    repo.events.add(null);
    await tester.pumpAndSettle();
    expect(repo.financeStores.length, 2);
    expect(repo.menuReads, 1);
    expect(repo.summaryReads, 1);
    expect(repo.orderReads, 2);
    expect(tester.takeException(), isNull);
    await unmount(tester, repo);
  });

  testWidgets('cached finance is removed when role or store scope changes', (
    tester,
  ) async {
    final repo = NavigationRepository();
    repo.storeRows.add({'id': 'store-2', 'name': 'ร้านสอง'});
    await mount(tester, repo);
    await navigate(tester, 8);
    expect(find.text('฿1234.00'), findsNWidgets(2));
    final dynamic state = tester.state(find.byType(MerchantHome));
    repo.sales = 5678;
    await state.c.selectStore('store-2');
    await tester.pumpAndSettle();
    expect(repo.financeStores, ['store-1', 'store-2']);
    expect(find.text('฿1234.00', skipOffstage: false), findsNothing);
    expect(find.text('฿5678.00'), findsNWidgets(2));

    repo.manager = false;
    repo.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('฿5678.00', skipOffstage: false), findsNothing);
    expect(
      find.text('เฉพาะเจ้าของ แอดมิน หรือผู้จัดการร้านที่ดูการเงินได้'),
      findsOneWidget,
    );
    repo.manager = true;
    repo.sales = 999;
    repo.events.add(null);
    await tester.pumpAndSettle();
    expect(repo.financeStores, ['store-1', 'store-2', 'store-2']);
    expect(find.text('฿999.00'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await unmount(tester, repo);
  });

  testWidgets('a different repository cannot reuse the former account panels', (
    tester,
  ) async {
    final before = NavigationRepository();
    await mount(tester, before);
    await navigate(tester, 8);
    final after = NavigationRepository()..sales = 4321;
    await tester.pumpWidget(
      ZokyApp(
        home: MerchantHome(repository: after, onSignOut: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('฿1234.00', skipOffstage: false), findsNothing);
    expect(after.financeStores, isEmpty);
    await navigate(tester, 8);
    expect(after.financeStores, ['store-1']);
    expect(find.text('฿4321.00'), findsNWidgets(2));
    before.events.add(null);
    await tester.pumpAndSettle();
    expect(before.orderReads, 1);
    expect(tester.takeException(), isNull);
    await unmount(tester, after);
    await before.events.close();
  });

  testWidgets(
    'large menus build visible rows lazily and keep category control',
    (tester) async {
      final repo = NavigationRepository();
      repo.menuRows = List.generate(
        500,
        (i) => {
          'id': 'menu-$i',
          'name': 'อาหารรายการ $i',
          'price': i + 10,
          'category': 'อาหาร',
          'is_available': true,
        },
      );
      await mount(tester, repo);
      await navigate(tester, 2);
      expect(find.text('อาหารรายการ 0'), findsOneWidget);
      expect(find.text('อาหารรายการ 499'), findsNothing);
      expect(find.byType(Switch).evaluate().length, lessThan(30));
      await tester.tap(find.widgetWithText(ListTile, 'อาหาร'));
      await tester.pumpAndSettle();
      expect(find.text('อาหารรายการ 0'), findsNothing);
      await tester.tap(find.widgetWithText(ListTile, 'อาหาร'));
      await tester.pumpAndSettle();
      expect(find.text('อาหารรายการ 0'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'รายการ 499');
      await tester.pumpAndSettle();
      expect(find.text('อาหารรายการ 499'), findsOneWidget);
      expect(find.text('อาหารรายการ 0'), findsNothing);
      expect(tester.takeException(), isNull);
      await unmount(tester, repo);
    },
  );

  testWidgets('hidden app pauses polling and catches up once resumed', (
    tester,
  ) async {
    final repo = NavigationRepository();
    await mount(tester, repo);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    repo.events.add(null);
    await tester.pump(const Duration(seconds: 21));
    expect(repo.orderReads, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.orderReads, 2);
    expect(repo.menuReads, 1);
    expect(repo.summaryReads, 1);
    expect(tester.takeException(), isNull);
    await unmount(tester, repo);
  });
}
