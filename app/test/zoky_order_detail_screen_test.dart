import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/order.dart';
import 'package:wyn/features/zoky/data/order_item.dart';
import 'package:wyn/features/zoky/presentation/zoky_order_detail_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ZokyOrderDetailScreen (ZOKY-003), per
/// .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 6.
void main() {
  Order order({OrderStatus status = OrderStatus.pending}) => Order(
        id: 'o1',
        storeId: 'store-1',
        storeName: 'ร้านทดสอบ',
        status: status,
        recipientName: 'สมชาย ใจดี',
        recipientPhone: '0812345678',
        shippingAddress: '123 ถนนทดสอบ',
        subtotal: 200,
        feePercent: 10,
        feeAmount: 20,
        total: 220,
        createdAt: DateTime.now(),
      );

  const orderItem = OrderItem(
    id: 'oi1',
    productId: 'p1',
    productName: 'เสื้อยืด',
    variantSelection: '',
    unitPrice: 200,
    quantity: 1,
    imageUrl: 'https://example.supabase.co/products/p1.jpg',
  );

  late RecordingZokyRepository pendingRepo;
  late RecordingZokyRepository deliveredRepo;
  late RecordingZokyRepository cancelledRepo;
  late RecordingZokyRepository cancelFailsRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    pendingRepo = RecordingZokyRepository(order: order(), orderItems: [orderItem]);
    deliveredRepo = RecordingZokyRepository(
      order: order(status: OrderStatus.delivered),
      orderItems: [orderItem],
    );
    cancelledRepo = RecordingZokyRepository(
      order: order(status: OrderStatus.cancelled),
      orderItems: [orderItem],
    );
    cancelFailsRepo = RecordingZokyRepository(
      order: order(),
      orderItems: [orderItem],
      cancelOrderException: Exception('network down'),
    );
  });

  Widget buildOrderDetail(RecordingZokyRepository repo) {
    return MaterialApp(home: ZokyOrderDetailScreen(zokyRepository: repo, orderId: 'o1'));
  }

  testWidgets('shows address, item snapshot, and summary totals', (tester) async {
    await tester.pumpWidget(buildOrderDetail(pendingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.textContaining('สมชาย ใจดี'), findsOneWidget);
    expect(find.text('123 ถนนทดสอบ'), findsOneWidget);
    expect(find.text('เสื้อยืด'), findsOneWidget);
    expect(find.text('฿220'), findsOneWidget);
  });

  testWidgets('shows Cancel/Confirm Received buttons when status is pending', (tester) async {
    await tester.pumpWidget(buildOrderDetail(pendingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsOneWidget);
    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsOneWidget);
  });

  testWidgets('hides Cancel/Confirm Received buttons when status is delivered', (tester) async {
    await tester.pumpWidget(buildOrderDetail(deliveredRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsNothing);
  });

  testWidgets('hides Cancel/Confirm Received buttons when status is cancelled', (tester) async {
    await tester.pumpWidget(buildOrderDetail(cancelledRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsNothing);
  });

  testWidgets('cancel: dismissing the confirm dialog does not call cancelOrder', (tester) async {
    await tester.pumpWidget(buildOrderDetail(pendingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยกเลิกคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('ยกเลิกคำสั่งซื้อ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(pendingRepo.lastCancelOrderId, isNull);
  });

  testWidgets('cancel: confirming the dialog calls cancelOrder with the order id', (tester) async {
    await tester.pumpWidget(buildOrderDetail(pendingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยกเลิกคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(pendingRepo.lastCancelOrderId, 'o1');
  });

  testWidgets('confirm received: confirming the dialog calls confirmOrderReceived',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(pendingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยืนยันได้รับสินค้าแล้ว'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('ยืนยันได้รับสินค้าแล้ว?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(pendingRepo.lastConfirmOrderReceivedId, 'o1');
  });

  testWidgets('shows an error SnackBar when cancelOrder fails', (tester) async {
    await tester.pumpWidget(buildOrderDetail(cancelFailsRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยกเลิกคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });
}
