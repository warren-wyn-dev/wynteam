import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/cart_item.dart';
import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/presentation/product_detail_screen.dart';
import 'package:wyn/features/zoky/presentation/store_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_cart_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_checkout_address_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ZokyCartScreen (ZOKY-003), per
/// .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 2.
void main() {
  Product product({
    String id = 'p1',
    String storeId = 'store-1',
    String storeName = 'ร้านทดสอบ',
    String name = 'เสื้อยืด',
    double price = 199,
    int stock = 10,
  }) =>
      Product(
        id: id,
        storeId: storeId,
        storeName: storeName,
        name: name,
        price: price,
        stock: stock,
        imageUrls: const ['https://example.supabase.co/products/p1.jpg'],
        createdAt: DateTime.now(),
      );

  late RecordingZokyRepository emptyRepo;
  late RecordingZokyRepository oneStoreRepo;
  late RecordingZokyRepository twoStoreRepo;
  late RecordingZokyRepository atMaxStockRepo;
  late RecordingZokyRepository singleQuantityRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    emptyRepo = RecordingZokyRepository();
    oneStoreRepo = RecordingZokyRepository(
      cartItems: [
        CartItem(id: 'ci1', product: product(), variantSelection: '', quantity: 2),
      ],
    );
    twoStoreRepo = RecordingZokyRepository(
      cartItems: [
        CartItem(id: 'ci1', product: product(), variantSelection: '', quantity: 2),
        CartItem(
          id: 'ci2',
          product: product(id: 'p2', storeId: 'store-2', storeName: 'ร้านที่สอง', price: 500),
          variantSelection: 'สี: แดง',
          quantity: 1,
        ),
      ],
    );
    atMaxStockRepo = RecordingZokyRepository(
      cartItems: [
        CartItem(
          id: 'ci1',
          product: product(stock: 2),
          variantSelection: '',
          quantity: 2,
        ),
      ],
    );
    singleQuantityRepo = RecordingZokyRepository(
      cartItems: [CartItem(id: 'ci1', product: product(), variantSelection: '', quantity: 1)],
    );
  });

  Widget buildCart(RecordingZokyRepository repo) {
    return MaterialApp(home: ZokyCartScreen(zokyRepository: repo));
  }

  testWidgets('shows empty-state text and a button back when cart is empty', (tester) async {
    await tester.pumpWidget(buildCart(emptyRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ตะกร้าของคุณว่างเปล่า'), findsOneWidget);
    expect(find.text('เลือกซื้อสินค้า'), findsOneWidget);
  });

  testWidgets('groups items by store and shows subtotal per store plus grand total',
      (tester) async {
    await tester.pumpWidget(buildCart(twoStoreRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ร้านทดสอบ'), findsOneWidget);
    expect(find.text('ร้านที่สอง'), findsOneWidget);
    // Store 1: 199 x2 = 398; Store 2: 500 x1 = 500; grand total 898.
    expect(find.text('รวมร้านนี้: ฿398'), findsOneWidget);
    expect(find.text('รวมร้านนี้: ฿500'), findsOneWidget);
    expect(find.text('฿898'), findsOneWidget);
  });

  testWidgets('shows the variant selection snapshot text under the product name',
      (tester) async {
    await tester.pumpWidget(buildCart(twoStoreRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('สี: แดง'), findsOneWidget);
  });

  testWidgets('tapping + calls updateCartItemQuantity with the incremented value',
      (tester) async {
    await tester.pumpWidget(buildCart(oneStoreRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pump();

    expect(oneStoreRepo.lastUpdateCartItemQuantityId, 'ci1');
    expect(oneStoreRepo.lastUpdateCartItemQuantityValue, 3);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('tapping - calls updateCartItemQuantity with the decremented value',
      (tester) async {
    await tester.pumpWidget(buildCart(oneStoreRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.remove));
    await tester.pump();

    expect(oneStoreRepo.lastUpdateCartItemQuantityId, 'ci1');
    expect(oneStoreRepo.lastUpdateCartItemQuantityValue, 1);
  });

  testWidgets('+ is disabled once quantity reaches the product\'s current stock',
      (tester) async {
    await tester.pumpWidget(buildCart(atMaxStockRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    final plusButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add));
    expect(plusButton.onPressed, isNull);
  });

  testWidgets('- is disabled at quantity 1', (tester) async {
    await tester.pumpWidget(buildCart(singleQuantityRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    final minusButton = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove));
    expect(minusButton.onPressed, isNull);
  });

  testWidgets('tapping remove calls removeCartItem and drops the row from the list',
      (tester) async {
    await tester.pumpWidget(buildCart(oneStoreRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(oneStoreRepo.lastRemoveCartItemId, 'ci1');
    expect(find.text('ตะกร้าของคุณว่างเปล่า'), findsOneWidget);
  });

  testWidgets('tapping ยืนยันคำสั่งซื้อ opens ZokyCheckoutAddressScreen with the cart items',
      (tester) async {
    await tester.pumpWidget(buildCart(twoStoreRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยืนยันคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ZokyCheckoutAddressScreen), findsOneWidget);
    final screen =
        tester.widget<ZokyCheckoutAddressScreen>(find.byType(ZokyCheckoutAddressScreen));
    expect(screen.cartItems.length, 2);
  });

  testWidgets('tapping a cart item opens ProductDetailScreen', (tester) async {
    await tester.pumpWidget(buildCart(oneStoreRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('เสื้อยืด'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('tapping the store header opens StoreScreen', (tester) async {
    await tester.pumpWidget(buildCart(oneStoreRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ร้านทดสอบ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(StoreScreen), findsOneWidget);
  });
}
