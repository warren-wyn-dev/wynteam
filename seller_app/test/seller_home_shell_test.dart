import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/finance/presentation/seller_finance_screen.dart';
import 'package:zoky_seller/features/order/presentation/seller_order_list_screen.dart';
import 'package:zoky_seller/features/product/presentation/seller_product_list_screen.dart';
import 'package:zoky_seller/features/shell/presentation/seller_coming_soon_screen.dart';
import 'package:zoky_seller/features/shell/presentation/seller_home_shell.dart';
import 'package:zoky_seller/features/store/data/store.dart';
import 'package:zoky_seller/features/store/presentation/seller_store_screen.dart';

import 'support/recording_seller_notification_repository.dart';
import 'support/recording_seller_repository.dart';

final _store = Store(
  id: 'store-1',
  ownerId: 'u1',
  name: 'ร้านทดสอบ',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  // See seller_auth_gate_test.dart's comment on why Recording*Repository
  // must be built in setUp(), not inline inside testWidgets.
  late RecordingSellerRepository repository;
  late RecordingSellerNotificationRepository notificationRepository;

  setUp(() {
    repository = RecordingSellerRepository();
    notificationRepository = RecordingSellerNotificationRepository();
  });

  testWidgets('renders all 5 bottom nav destinations, starting on Dashboard',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(
        store: _store,
        sellerRepository: repository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(5));
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('สินค้า'), findsOneWidget);
    expect(find.text('คำสั่งซื้อ'), findsOneWidget);
    expect(find.text('ร้านค้า'), findsOneWidget);
    expect(find.text('การเงิน'), findsOneWidget);

    // Dashboard (index 0) is the landing tab -- its store name should
    // already be visible without tapping anything.
    expect(find.text('ร้านทดสอบ'), findsOneWidget);
  });

  testWidgets(
      'the การเงิน tab shows SellerFinanceScreen (SELLER-005), not the '
      'placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(
        store: _store,
        sellerRepository: repository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('การเงิน'));
    await tester.pumpAndSettle();

    expect(find.byType(SellerFinanceScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the ร้านค้า tab shows SellerStoreScreen (SELLER-004), not the '
      'placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(
        store: _store,
        sellerRepository: repository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ร้านค้า'));
    await tester.pumpAndSettle();

    expect(find.byType(SellerStoreScreen), findsOneWidget);
    expect(find.widgetWithText(SellerComingSoonScreen, 'ร้านค้า'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'editing store info in the ร้านค้า tab and saving updates the '
      'Dashboard tab in the same session (SELLER-004)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(
        store: _store,
        sellerRepository: repository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ร้านค้า'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'ร้านทดสอบ (ชื่อใหม่)');
    await tester.pump();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    expect(find.text('ร้านทดสอบ (ชื่อใหม่)'), findsOneWidget);
    expect(find.text('ร้านทดสอบ'), findsNothing);
  });

  testWidgets(
      'the สินค้า tab shows SellerProductListScreen (SELLER-002), not the '
      'placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(
        store: _store,
        sellerRepository: repository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('สินค้า'));
    await tester.pumpAndSettle();

    expect(find.byType(SellerProductListScreen), findsOneWidget);
    expect(find.widgetWithText(SellerComingSoonScreen, 'สินค้า'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'the คำสั่งซื้อ tab shows SellerOrderListScreen (SELLER-003), not the '
      'placeholder', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(
        store: _store,
        sellerRepository: repository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('คำสั่งซื้อ'));
    await tester.pumpAndSettle();

    expect(find.byType(SellerOrderListScreen), findsOneWidget);
    expect(find.widgetWithText(SellerComingSoonScreen, 'คำสั่งซื้อ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs keeps IndexedStack state (no unmount)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(
        store: _store,
        sellerRepository: repository,
        notificationRepository: notificationRepository,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(IndexedStack), findsOneWidget);
    final indexedStack = tester.widget<IndexedStack>(find.byType(IndexedStack));
    expect(indexedStack.children.length, 5);

    await tester.tap(find.text('สินค้า'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();

    // Dashboard's own FutureBuilder resolved once and its State was
    // never disposed while switched away, so its content is still
    // there immediately (no reload spinner) after switching back.
    expect(find.text('ร้านทดสอบ'), findsOneWidget);
  });
}
