import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/shell/presentation/seller_coming_soon_screen.dart';
import 'package:zoky_seller/features/shell/presentation/seller_home_shell.dart';
import 'package:zoky_seller/features/store/data/store.dart';

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

  setUp(() {
    repository = RecordingSellerRepository();
  });

  testWidgets('renders all 5 bottom nav destinations, starting on Dashboard',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(store: _store, sellerRepository: repository),
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
      'the 4 not-yet-built tabs each show SellerComingSoonScreen, not a '
      'crash', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(store: _store, sellerRepository: repository),
    ));
    await tester.pumpAndSettle();

    for (final label in ['สินค้า', 'คำสั่งซื้อ', 'ร้านค้า', 'การเงิน']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SellerComingSoonScreen, label),
        findsOneWidget,
      );
      expect(find.text('ฟีเจอร์นี้จะมาเร็ว ๆ นี้'), findsOneWidget);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs keeps IndexedStack state (no unmount)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerHomeShell(store: _store, sellerRepository: repository),
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
