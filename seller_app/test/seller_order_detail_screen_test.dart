import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/order/data/order.dart';
import 'package:zoky_seller/features/order/data/order_item.dart';
import 'package:zoky_seller/features/order/presentation/seller_order_detail_screen.dart';

import 'support/recording_seller_repository.dart';

/// Regression tests for SellerOrderDetailScreen (SELLER-003), per
/// .wyn/docs/design/seller-003-order-management.md, Screen:
/// SellerOrderDetailScreen. The action bar is per-status (never
/// all-or-nothing), so each status below gets its own test rather than
/// just an "has buttons"/"has no buttons" pair -- per that same doc's
/// "เตือน Coding" #1.
void main() {
  Order order({
    OrderStatus status = OrderStatus.paid,
    String? shippingProvider,
    String? trackingNumber,
  }) =>
      Order(
        id: 'o1',
        storeId: 'store-1',
        status: status,
        recipientName: 'สมชาย ใจดี',
        recipientPhone: '0812345678',
        shippingAddress: '123 ถนนทดสอบ',
        subtotal: 200,
        feePercent: 10,
        feeAmount: 20,
        total: 220,
        createdAt: DateTime(2026, 1, 1),
        shippingProvider: shippingProvider,
        trackingNumber: trackingNumber,
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

  // See seller_auth_gate_test.dart's comment on why Recording*Repository
  // must be built in setUp(), not inline inside testWidgets.
  late RecordingSellerRepository paidRepo;
  late RecordingSellerRepository sellerProcessingRepo;
  late RecordingSellerRepository readyToShipRepo;
  late RecordingSellerRepository shippedRepo;
  late RecordingSellerRepository deliveredRepo;
  late RecordingSellerRepository cancelledRepo;
  late RecordingSellerRepository startProcessingFailsRepo;
  late RecordingSellerRepository cancelFailsRepo;
  late RecordingSellerRepository refundFailsRepo;

  setUp(() {
    paidRepo = RecordingSellerRepository(
      storeOrder: order(),
      storeOrderItems: [orderItem],
    );
    sellerProcessingRepo = RecordingSellerRepository(
      storeOrder: order(status: OrderStatus.sellerProcessing),
      storeOrderItems: [orderItem],
    );
    readyToShipRepo = RecordingSellerRepository(
      storeOrder: order(status: OrderStatus.readyToShip),
      storeOrderItems: [orderItem],
    );
    shippedRepo = RecordingSellerRepository(
      storeOrder: order(
        status: OrderStatus.shipped,
        shippingProvider: 'Kerry Express',
        trackingNumber: 'TH123456789',
      ),
      storeOrderItems: [orderItem],
    );
    deliveredRepo = RecordingSellerRepository(
      storeOrder: order(
        status: OrderStatus.delivered,
        shippingProvider: 'Kerry Express',
        trackingNumber: 'TH123456789',
      ),
      storeOrderItems: [orderItem],
    );
    cancelledRepo = RecordingSellerRepository(
      storeOrder: order(status: OrderStatus.cancelled),
      storeOrderItems: [orderItem],
    );
    startProcessingFailsRepo = RecordingSellerRepository(
      storeOrder: order(),
      storeOrderItems: [orderItem],
      sellerStartProcessingException: Exception('network down'),
    );
    cancelFailsRepo = RecordingSellerRepository(
      storeOrder: order(),
      storeOrderItems: [orderItem],
      sellerCancelOrderException: Exception('network down'),
    );
    refundFailsRepo = RecordingSellerRepository(
      storeOrder: order(status: OrderStatus.shipped, shippingProvider: 'Kerry Express'),
      storeOrderItems: [orderItem],
      sellerMarkRefundedException: Exception('network down'),
    );
  });

  Widget buildOrderDetail(RecordingSellerRepository repo) {
    return MaterialApp(
      home: SellerOrderDetailScreen(sellerRepository: repo, orderId: 'o1'),
    );
  }

  testWidgets('shows recipient info, item snapshot, and summary totals', (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.textContaining('สมชาย ใจดี'), findsOneWidget);
    expect(find.text('123 ถนนทดสอบ'), findsOneWidget);
    expect(find.text('เสื้อยืด'), findsOneWidget);
    expect(find.text('฿220'), findsOneWidget);
  });

  testWidgets('paid: shows "เริ่มเตรียมสินค้า" + "ยกเลิกคำสั่งซื้อ" only', (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('เริ่มเตรียมสินค้า'), findsOneWidget);
    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsOneWidget);
    expect(find.text('พร้อมจัดส่ง'), findsNothing);
    expect(find.text('ยืนยันจัดส่งแล้ว'), findsNothing);
    expect(find.text('ทำเครื่องหมายคืนเงินแล้ว'), findsNothing);
  });

  testWidgets('paid: tapping "เริ่มเตรียมสินค้า" calls sellerStartProcessing directly, no dialog',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('เริ่มเตรียมสินค้า'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(paidRepo.sellerStartProcessingCalls, 1);
    expect(paidRepo.lastSellerStartProcessingId, 'o1');
    // No AlertDialog should have appeared -- this action isn't
    // destructive, per the Design spec's Interactions.
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('paid: shows an error SnackBar when sellerStartProcessing fails', (tester) async {
    await tester.pumpWidget(buildOrderDetail(startProcessingFailsRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('เริ่มเตรียมสินค้า'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('เริ่มเตรียมสินค้าไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });

  testWidgets('seller_processing: shows "พร้อมจัดส่ง" + "ยกเลิกคำสั่งซื้อ" only', (tester) async {
    await tester.pumpWidget(buildOrderDetail(sellerProcessingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('พร้อมจัดส่ง'), findsOneWidget);
    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsOneWidget);
    expect(find.text('เริ่มเตรียมสินค้า'), findsNothing);
  });

  testWidgets('seller_processing: tapping "พร้อมจัดส่ง" calls sellerMarkReadyToShip',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(sellerProcessingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('พร้อมจัดส่ง'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(sellerProcessingRepo.sellerMarkReadyToShipCalls, 1);
    expect(sellerProcessingRepo.lastSellerMarkReadyToShipId, 'o1');
  });

  testWidgets(
      'ready_to_ship: shows the shipping form, "ยืนยันจัดส่งแล้ว" disabled until both fields '
      'are filled, plus "ยกเลิกคำสั่งซื้อ"', (tester) async {
    await tester.pumpWidget(buildOrderDetail(readyToShipRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('กรอกข้อมูลการจัดส่ง'), findsOneWidget);
    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsOneWidget);

    final shipButtonFinder = find.widgetWithText(FilledButton, 'ยืนยันจัดส่งแล้ว');
    expect(shipButtonFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(shipButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField).first, 'Kerry Express');
    await tester.pump();
    // Still disabled -- only 1 of 2 required fields filled.
    expect(tester.widget<FilledButton>(shipButtonFinder).onPressed, isNull);

    await tester.enterText(find.byType(TextField).last, 'TH123456789');
    await tester.pump();
    expect(tester.widget<FilledButton>(shipButtonFinder).onPressed, isNotNull);
  });

  testWidgets(
      'ready_to_ship: tapping "ยืนยันจัดส่งแล้ว" once both fields are filled calls '
      'sellerShipOrder with the entered values', (tester) async {
    await tester.pumpWidget(buildOrderDetail(readyToShipRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.enterText(find.byType(TextField).first, 'Kerry Express');
    await tester.enterText(find.byType(TextField).last, 'TH123456789');
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันจัดส่งแล้ว'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(readyToShipRepo.sellerShipOrderCalls, 1);
    expect(readyToShipRepo.lastSellerShipOrderId, 'o1');
    expect(readyToShipRepo.lastSellerShipOrderProvider, 'Kerry Express');
    expect(readyToShipRepo.lastSellerShipOrderTracking, 'TH123456789');
  });

  testWidgets('shipped: shows the shipping info card and only "ทำเครื่องหมายคืนเงินแล้ว"',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(shippedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ข้อมูลการจัดส่ง'), findsOneWidget);
    expect(find.text('ขนส่งโดย: Kerry Express'), findsOneWidget);
    expect(find.text('เลขพัสดุ: TH123456789'), findsOneWidget);

    expect(find.text('ทำเครื่องหมายคืนเงินแล้ว'), findsOneWidget);
    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
    expect(find.text('เริ่มเตรียมสินค้า'), findsNothing);
    expect(find.text('พร้อมจัดส่ง'), findsNothing);
    expect(find.text('ยืนยันจัดส่งแล้ว'), findsNothing);
  });

  testWidgets('delivered: shows only "ทำเครื่องหมายคืนเงินแล้ว"', (tester) async {
    await tester.pumpWidget(buildOrderDetail(deliveredRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ทำเครื่องหมายคืนเงินแล้ว'), findsOneWidget);
    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
  });

  testWidgets('cancelled: no action bar at all', (tester) async {
    await tester.pumpWidget(buildOrderDetail(cancelledRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
    expect(find.text('เริ่มเตรียมสินค้า'), findsNothing);
    expect(find.text('ทำเครื่องหมายคืนเงินแล้ว'), findsNothing);
  });

  testWidgets('cancel: shows a confirm dialog and only calls sellerCancelOrder on confirm',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยกเลิกคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('ยกเลิกคำสั่งซื้อ?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(paidRepo.sellerCancelOrderCalls, 0);

    await tester.tap(find.text('ยกเลิกคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(paidRepo.sellerCancelOrderCalls, 1);
    expect(paidRepo.lastSellerCancelOrderId, 'o1');
  });

  testWidgets('shows an error SnackBar when sellerCancelOrder fails', (tester) async {
    await tester.pumpWidget(buildOrderDetail(cancelFailsRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยกเลิกคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });

  testWidgets(
      'refund: shows a confirm dialog explaining it is bookkeeping-only, and only calls '
      'sellerMarkRefunded on confirm', (tester) async {
    await tester.pumpWidget(buildOrderDetail(shippedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ทำเครื่องหมายคืนเงินแล้ว'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('ทำเครื่องหมายคืนเงินแล้ว?'), findsOneWidget);
    expect(
      find.textContaining('ระบบยังไม่มีการโอนเงินคืนอัตโนมัติ'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();
    expect(shippedRepo.sellerMarkRefundedCalls, 0);

    await tester.tap(find.text('ทำเครื่องหมายคืนเงินแล้ว'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(shippedRepo.sellerMarkRefundedCalls, 1);
    expect(shippedRepo.lastSellerMarkRefundedId, 'o1');
  });

  testWidgets('shows an error SnackBar when sellerMarkRefunded fails', (tester) async {
    await tester.pumpWidget(buildOrderDetail(refundFailsRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ทำเครื่องหมายคืนเงินแล้ว'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('บันทึกการคืนเงินไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });
}
