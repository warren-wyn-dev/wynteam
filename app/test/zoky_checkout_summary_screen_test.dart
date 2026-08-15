import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/cart_item.dart';
import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/data/zoky_repository.dart';
import 'package:wyn/features/zoky/presentation/zoky_checkout_summary_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ZokyCheckoutSummaryScreen (ZOKY-003), per
/// .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 4.
void main() {
  Product product({
    String id = 'p1',
    String storeId = 'store-1',
    String storeName = 'ร้านทดสอบ',
    String name = 'เสื้อยืด',
    double price = 200,
  }) =>
      Product(
        id: id,
        storeId: storeId,
        storeName: storeName,
        name: name,
        price: price,
        stock: 10,
        imageUrls: const ['https://example.supabase.co/products/p1.jpg'],
        createdAt: DateTime.now(),
      );

  late List<CartItem> oneStoreItems;
  late List<CartItem> twoStoreItems;
  late RecordingZokyRepository repo;
  late RecordingZokyRepository insufficientStockRepo;
  late RecordingZokyRepository genericErrorRepo;
  late RecordingZokyRepository controlledRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    oneStoreItems = [
      CartItem(id: 'ci1', product: product(), variantSelection: '', quantity: 2),
    ];
    twoStoreItems = [
      CartItem(id: 'ci1', product: product(), variantSelection: '', quantity: 2),
      CartItem(
        id: 'ci2',
        product: product(id: 'p2', storeId: 'store-2', storeName: 'ร้านที่สอง', price: 500),
        variantSelection: '',
        quantity: 1,
      ),
    ];
    repo = RecordingZokyRepository(marketplaceFeePercent: 10, createOrdersResult: ['o1']);
    insufficientStockRepo = RecordingZokyRepository(
      marketplaceFeePercent: 10,
      createOrdersException: const InsufficientStockException('เสื้อยืด'),
    );
    genericErrorRepo = RecordingZokyRepository(
      marketplaceFeePercent: 10,
      createOrdersException: Exception('network down'),
    );
    controlledRepo = RecordingZokyRepository(marketplaceFeePercent: 10);
  });

  Widget buildSummary(RecordingZokyRepository repo, List<CartItem> items) {
    return MaterialApp(
      home: ZokyCheckoutSummaryScreen(
        zokyRepository: repo,
        cartItems: items,
        recipientName: 'สมชาย ใจดี',
        recipientPhone: '0812345678',
        shippingAddress: '123 ถนนทดสอบ',
      ),
    );
  }

  testWidgets('shows the address, per-store breakdown using the live fee percent, and grand total',
      (tester) async {
    await tester.pumpWidget(buildSummary(repo, twoStoreItems));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.textContaining('สมชาย ใจดี'), findsOneWidget);
    expect(find.text('123 ถนนทดสอบ'), findsOneWidget);

    // Store 1: subtotal 400, fee 10% = 40, total 440.
    expect(find.text('ค่าธรรมเนียมแพลตฟอร์ม (10%)'), findsNWidgets(2));
    expect(find.text('฿440'), findsOneWidget);
    // Store 2: subtotal 500, fee 10% = 50, total 550.
    expect(find.text('฿550'), findsOneWidget);
    // Grand total 440 + 550 = 990 -- below the fold with 2 store cards
    // in this 800x600 test viewport, see .wyn/learning/PATTERNS.md.
    await tester.scrollUntilVisible(find.text('฿990'), 500, scrollable: find.byType(Scrollable).first);
    tester.takeException();
    expect(find.text('฿990'), findsOneWidget);
  });

  testWidgets('tapping ยืนยันคำสั่งซื้อ calls createOrders with the recipient/address data',
      (tester) async {
    await tester.pumpWidget(buildSummary(repo, oneStoreItems));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยืนยันคำสั่งซื้อ'));
    // A bounded number of pumps rather than pumpAndSettle -- this
    // screen's success path calls Navigator.popUntil(isFirst) on its
    // own (only) route, a harmless no-op since there's nothing above
    // it to pop, but the SnackBar shown just before it keeps a timer
    // alive that pumpAndSettle waits on indefinitely when run as part
    // of the full suite (not reproducible running this file alone).
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    tester.takeException();

    expect(repo.lastCreateOrdersRecipientName, 'สมชาย ใจดี');
    expect(repo.lastCreateOrdersRecipientPhone, '0812345678');
    expect(repo.lastCreateOrdersShippingAddress, '123 ถนนทดสอบ');
  });

  testWidgets('on success shows a confirmation SnackBar and pops back to the first route',
      (tester) async {
    // Push ZokyCheckoutSummaryScreen directly (not via buildSummary's
    // own MaterialApp wrapper) -- pushing a route whose content is a
    // second, nested MaterialApp gives it a separate, inner Navigator,
    // so Navigator.of(context).popUntil(isFirst) from inside the
    // pushed screen resolves against that inner (single-route, already
    // "first") Navigator instead of this outer one, making the pop a
    // silent no-op.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ZokyCheckoutSummaryScreen(
                      zokyRepository: repo,
                      cartItems: oneStoreItems,
                      recipientName: 'สมชาย ใจดี',
                      recipientPhone: '0812345678',
                      shippingAddress: '123 ถนนทดสอบ',
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยืนยันคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('สั่งซื้อสำเร็จ'), findsOneWidget);
    // Back at the root route -- the Checkout screen is gone.
    expect(find.byType(ZokyCheckoutSummaryScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('on InsufficientStockException shows a specific error and stays on screen',
      (tester) async {
    await tester.pumpWidget(buildSummary(insufficientStockRepo, oneStoreItems));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยืนยันคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.textContaining('เสื้อยืด มีสินค้าไม่เพียงพอ'), findsOneWidget);
    expect(find.byType(ZokyCheckoutSummaryScreen), findsOneWidget);
  });

  testWidgets('on a generic error shows a generic error message and stays on screen',
      (tester) async {
    await tester.pumpWidget(buildSummary(genericErrorRepo, oneStoreItems));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยืนยันคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('สั่งซื้อไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.byType(ZokyCheckoutSummaryScreen), findsOneWidget);
  });

  testWidgets('disables the confirm button and shows a spinner while the request is in flight',
      (tester) async {
    final completer = Completer<List<String>>();
    controlledRepo.createOrdersOverride = () => completer.future;

    await tester.pumpWidget(buildSummary(controlledRepo, oneStoreItems));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยืนยันคำสั่งซื้อ'));
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(['o1']);
    // Bounded pumps rather than pumpAndSettle -- see the note in the
    // "calls createOrders" test above.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    tester.takeException();

    expect(find.text('สั่งซื้อสำเร็จ'), findsOneWidget);
  });
}
