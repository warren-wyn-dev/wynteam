import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/order.dart';
import 'package:wyn/features/zoky/data/order_item.dart';
import 'package:wyn/features/zoky/data/review.dart';
import 'package:wyn/features/zoky/presentation/zoky_order_detail_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ZokyOrderDetailScreen (ZOKY-003, action bar made
/// per-status + shipping info card added by SELLER-003), per
/// .wyn/docs/design/seller-003-order-management.md, Screen:
/// ZokyOrderDetailScreen.
///
/// [OrderStatus.pending] no longer exists (SELLER-003 renamed it to
/// [OrderStatus.paid] -- same meaning, see supabase/schema.sql's
/// migration comment) -- every case below that used to assert on
/// "pending" now asserts on "paid" instead, which is an intended
/// behavior change (the status this project's orders are actually
/// created in), not a regression. New cases cover the 2 statuses that
/// didn't exist before this task at all (sellerProcessing/readyToShip)
/// and the new shipping info card.
void main() {
  Order order({OrderStatus status = OrderStatus.paid, String? shippingProvider, String? trackingNumber}) =>
      Order(
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

  late RecordingZokyRepository paidRepo;
  late RecordingZokyRepository sellerProcessingRepo;
  late RecordingZokyRepository readyToShipRepo;
  late RecordingZokyRepository shippedRepo;
  late RecordingZokyRepository deliveredRepo;
  late RecordingZokyRepository cancelledRepo;
  late RecordingZokyRepository cancelFailsRepo;
  late RecordingZokyRepository alreadyReviewedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    paidRepo = RecordingZokyRepository(order: order(), orderItems: [orderItem]);
    sellerProcessingRepo = RecordingZokyRepository(
      order: order(status: OrderStatus.sellerProcessing),
      orderItems: [orderItem],
    );
    readyToShipRepo = RecordingZokyRepository(
      order: order(status: OrderStatus.readyToShip),
      orderItems: [orderItem],
    );
    shippedRepo = RecordingZokyRepository(
      order: order(
        status: OrderStatus.shipped,
        shippingProvider: 'Kerry Express',
        trackingNumber: 'TH123456789',
      ),
      orderItems: [orderItem],
    );
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
    alreadyReviewedRepo = RecordingZokyRepository(
      order: order(status: OrderStatus.delivered),
      orderItems: [orderItem],
      reviewForOrderItem: Review(
        id: 'r1',
        orderItemId: orderItem.id,
        productId: orderItem.productId!,
        userId: 'me',
        authorUsername: 'me',
        rating: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  Widget buildOrderDetail(RecordingZokyRepository repo) {
    return MaterialApp(home: ZokyOrderDetailScreen(zokyRepository: repo, orderId: 'o1'));
  }

  testWidgets('shows address, item snapshot, and summary totals', (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.textContaining('สมชาย ใจดี'), findsOneWidget);
    expect(find.text('123 ถนนทดสอบ'), findsOneWidget);
    expect(find.text('เสื้อยืด'), findsOneWidget);
    expect(find.text('฿220'), findsOneWidget);
  });

  testWidgets('shows only the Cancel button when status is paid', (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsOneWidget);
    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsNothing);
  });

  testWidgets('shows only the Confirm Received button when status is shipped', (tester) async {
    await tester.pumpWidget(buildOrderDetail(shippedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsOneWidget);
    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
  });

  testWidgets('hides both buttons when status is seller_processing', (tester) async {
    await tester.pumpWidget(buildOrderDetail(sellerProcessingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsNothing);
  });

  testWidgets('hides both buttons when status is ready_to_ship', (tester) async {
    await tester.pumpWidget(buildOrderDetail(readyToShipRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsNothing);
  });

  testWidgets('hides both buttons when status is delivered', (tester) async {
    await tester.pumpWidget(buildOrderDetail(deliveredRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsNothing);
  });

  testWidgets('hides both buttons when status is cancelled', (tester) async {
    await tester.pumpWidget(buildOrderDetail(cancelledRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยกเลิกคำสั่งซื้อ'), findsNothing);
    expect(find.text('ยืนยันได้รับสินค้าแล้ว'), findsNothing);
  });

  testWidgets('shows the shipping info card once the seller has shipped the order',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(shippedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ข้อมูลการจัดส่ง'), findsOneWidget);
    expect(find.text('ขนส่งโดย: Kerry Express'), findsOneWidget);
    expect(find.text('เลขพัสดุ: TH123456789'), findsOneWidget);
  });

  testWidgets('hides the shipping info card entirely before the seller has shipped the order',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ข้อมูลการจัดส่ง'), findsNothing);
  });

  testWidgets('cancel: dismissing the confirm dialog does not call cancelOrder', (tester) async {
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

    expect(paidRepo.lastCancelOrderId, isNull);
  });

  testWidgets('cancel: confirming the dialog calls cancelOrder with the order id', (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยกเลิกคำสั่งซื้อ'));
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(paidRepo.lastCancelOrderId, 'o1');
  });

  testWidgets('confirm received: confirming the dialog calls confirmOrderReceived',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(shippedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ยืนยันได้รับสินค้าแล้ว'));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('ยืนยันได้รับสินค้าแล้ว?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'ยืนยัน'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(shippedRepo.lastConfirmOrderReceivedId, 'o1');
  });

  testWidgets('shows a "เขียนรีวิว" entry point per item once delivered, with no review yet '
      '(ZOKY-004)', (tester) async {
    await tester.pumpWidget(buildOrderDetail(deliveredRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('เขียนรีวิว'), findsOneWidget);
    expect(find.text('แก้ไขรีวิว'), findsNothing);
  });

  testWidgets('shows the star rating and "แก้ไขรีวิว" once an item has already been reviewed '
      '(ZOKY-004)', (tester) async {
    await tester.pumpWidget(buildOrderDetail(alreadyReviewedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('แก้ไขรีวิว'), findsOneWidget);
    expect(find.text('เขียนรีวิว'), findsNothing);
  });

  testWidgets('does not show a review entry point while an order is still paid (ZOKY-004)',
      (tester) async {
    await tester.pumpWidget(buildOrderDetail(paidRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('เขียนรีวิว'), findsNothing);
    expect(find.text('แก้ไขรีวิว'), findsNothing);
  });

  testWidgets('tapping "เขียนรีวิว" opens the review form and submitting calls addReview '
      '(ZOKY-004)', (tester) async {
    await tester.pumpWidget(buildOrderDetail(deliveredRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('เขียนรีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    // 5th star button (index 4) selects a rating of 5.
    await tester.tap(find.byIcon(Icons.star_border).last);
    await tester.pump();

    await tester.tap(find.text('ส่งรีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(deliveredRepo.lastAddReviewOrderItemId, orderItem.id);
    expect(deliveredRepo.lastAddReviewProductId, orderItem.productId);
    expect(deliveredRepo.lastAddReviewRating, 5);
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
