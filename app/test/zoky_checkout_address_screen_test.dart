import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/cart_item.dart';
import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/presentation/zoky_checkout_address_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_checkout_summary_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ZokyCheckoutAddressScreen (ZOKY-003), per
/// .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 3.
void main() {
  final cartItems = [
    CartItem(
      id: 'ci1',
      product: Product(
        id: 'p1',
        storeId: 'store-1',
        storeName: 'ร้านทดสอบ',
        name: 'เสื้อยืด',
        price: 199,
        stock: 10,
        imageUrls: const ['https://example.supabase.co/products/p1.jpg'],
        createdAt: DateTime.now(),
      ),
      variantSelection: '',
      quantity: 1,
    ),
  ];

  late RecordingZokyRepository repo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    repo = RecordingZokyRepository();
  });

  Widget buildAddressScreen() {
    return MaterialApp(
      home: ZokyCheckoutAddressScreen(zokyRepository: repo, cartItems: cartItems),
    );
  }

  testWidgets('shows validation errors and does not navigate when fields are empty',
      (tester) async {
    await tester.pumpWidget(buildAddressScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกข้อมูล'), findsNWidgets(3));
    expect(find.byType(ZokyCheckoutSummaryScreen), findsNothing);
  });

  testWidgets('navigates to ZokyCheckoutSummaryScreen carrying the entered address',
      (tester) async {
    await tester.pumpWidget(buildAddressScreen());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'ชื่อผู้รับ'), 'สมชาย ใจดี');
    await tester.enterText(find.widgetWithText(TextFormField, 'เบอร์โทรศัพท์'), '0812345678');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ที่อยู่จัดส่ง'),
      '123 ถนนทดสอบ กรุงเทพฯ',
    );
    await tester.tap(find.text('ถัดไป'));
    await tester.pumpAndSettle();

    expect(find.byType(ZokyCheckoutSummaryScreen), findsOneWidget);
    final summary =
        tester.widget<ZokyCheckoutSummaryScreen>(find.byType(ZokyCheckoutSummaryScreen));
    expect(summary.recipientName, 'สมชาย ใจดี');
    expect(summary.recipientPhone, '0812345678');
    expect(summary.shippingAddress, '123 ถนนทดสอบ กรุงเทพฯ');
    expect(summary.cartItems.length, 1);
  });
}
