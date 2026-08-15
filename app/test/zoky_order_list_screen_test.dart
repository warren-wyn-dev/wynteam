import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/order.dart';
import 'package:wyn/features/zoky/data/order_item.dart';
import 'package:wyn/features/zoky/presentation/widgets/order_summary_card.dart';
import 'package:wyn/features/zoky/presentation/zoky_order_detail_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_order_list_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ZokyOrderListScreen (ZOKY-003), per
/// .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 5.
void main() {
  Order order({
    String id = 'o1',
    String storeName = 'ร้านทดสอบ',
    OrderStatus status = OrderStatus.pending,
    double total = 220,
  }) =>
      Order(
        id: id,
        storeId: 'store-1',
        storeName: storeName,
        status: status,
        recipientName: 'สมชาย ใจดี',
        recipientPhone: '0812345678',
        shippingAddress: '123 ถนนทดสอบ',
        subtotal: 200,
        feePercent: 10,
        feeAmount: 20,
        total: total,
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

  late RecordingZokyRepository emptyRepo;
  late RecordingZokyRepository populatedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    emptyRepo = RecordingZokyRepository();
    populatedRepo = RecordingZokyRepository(
      orders: [
        order(id: 'o1', status: OrderStatus.pending),
        order(id: 'o2', storeName: 'ร้านที่สอง', status: OrderStatus.delivered),
      ],
      orderItems: [orderItem],
      order: order(id: 'o1', status: OrderStatus.pending),
    );
  });

  Widget buildOrderList(RecordingZokyRepository repo) {
    return MaterialApp(home: ZokyOrderListScreen(zokyRepository: repo));
  }

  testWidgets('shows empty state when there are no orders', (tester) async {
    await tester.pumpWidget(buildOrderList(emptyRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ยังไม่มีคำสั่งซื้อ'), findsOneWidget);
  });

  testWidgets('renders an OrderSummaryCard per order with the correct status badge',
      (tester) async {
    await tester.pumpWidget(buildOrderList(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(OrderSummaryCard), findsNWidgets(2));
    expect(find.text('รอดำเนินการ'), findsOneWidget);
    expect(find.text('ได้รับสินค้าแล้ว'), findsOneWidget);
  });

  testWidgets('tapping an order card opens ZokyOrderDetailScreen for that order',
      (tester) async {
    await tester.pumpWidget(buildOrderList(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byType(OrderSummaryCard).first);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ZokyOrderDetailScreen), findsOneWidget);
    final screen = tester.widget<ZokyOrderDetailScreen>(find.byType(ZokyOrderDetailScreen));
    expect(screen.orderId, 'o1');
  });
}
