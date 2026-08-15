import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/order/data/order.dart';
import 'package:zoky_seller/features/order/data/order_item.dart';
import 'package:zoky_seller/features/order/presentation/seller_order_detail_screen.dart';
import 'package:zoky_seller/features/order/presentation/seller_order_list_screen.dart';
import 'package:zoky_seller/features/order/presentation/widgets/order_status_badge.dart';
import 'package:zoky_seller/features/order/presentation/widgets/seller_order_list_tile.dart';
import 'package:zoky_seller/features/store/data/store.dart';

import 'support/recording_seller_repository.dart';

/// Regression tests for SellerOrderListScreen (SELLER-003), per
/// .wyn/docs/design/seller-003-order-management.md, Screen:
/// SellerOrderListScreen.
void main() {
  final store = Store(
    id: 'store-1',
    ownerId: 'u1',
    name: 'ร้านทดสอบ',
    createdAt: DateTime(2026, 1, 1),
  );

  Order order({
    String id = 'o1',
    OrderStatus status = OrderStatus.paid,
    String recipientName = 'สมชาย ใจดี',
  }) =>
      Order(
        id: id,
        storeId: store.id,
        status: status,
        recipientName: recipientName,
        recipientPhone: '0812345678',
        shippingAddress: '123 ถนนทดสอบ',
        subtotal: 200,
        feePercent: 10,
        feeAmount: 20,
        total: 220,
        createdAt: DateTime(2026, 1, 1),
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
  late RecordingSellerRepository emptyRepo;
  late RecordingSellerRepository populatedRepo;

  setUp(() {
    emptyRepo = RecordingSellerRepository();
    populatedRepo = RecordingSellerRepository(
      storeOrders: [
        order(id: 'o1', status: OrderStatus.paid, recipientName: 'สมชาย ใจดี'),
        order(id: 'o2', status: OrderStatus.delivered, recipientName: 'สมหญิง ดีใจ'),
      ],
      storeOrderItems: [orderItem],
      storeOrder: order(id: 'o1', status: OrderStatus.paid),
    );
  });

  Widget buildOrderList(RecordingSellerRepository repo) {
    return MaterialApp(
      home: SellerOrderListScreen(store: store, sellerRepository: repo),
    );
  }

  testWidgets('shows the absolute empty state when the store has no orders at all',
      (tester) async {
    await tester.pumpWidget(buildOrderList(emptyRepo));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีคำสั่งซื้อเข้ามา'), findsOneWidget);
  });

  testWidgets(
      'renders a SellerOrderListTile per order, buyer name (not store name) + status badge',
      (tester) async {
    await tester.pumpWidget(buildOrderList(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(SellerOrderListTile), findsNWidgets(2));
    expect(find.text('ผู้ซื้อ: สมชาย ใจดี'), findsOneWidget);
    expect(find.text('ผู้ซื้อ: สมหญิง ดีใจ'), findsOneWidget);
    // "ชำระเงินแล้ว" also appears as a filter chip label, so assert via
    // OrderStatusBadge's own status value instead of raw text -- same
    // convention seller_product_list_screen_test.dart already uses for
    // ProductActiveBadge's "กำลังขาย"/"ปิดการขาย" collision.
    final badges = tester.widgetList<OrderStatusBadge>(find.byType(OrderStatusBadge)).toList();
    expect(badges.map((b) => b.status).toList(), [OrderStatus.paid, OrderStatus.delivered]);
  });

  testWidgets('tapping a filter chip re-fetches with that filter, scoped to this store',
      (tester) async {
    await tester.pumpWidget(buildOrderList(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(populatedRepo.lastFetchStoreOrdersFilter, isNull);
    expect(populatedRepo.lastFetchStoreOrdersStoreId, 'store-1');

    // The filter chip row scrolls horizontally and "ยกเลิกแล้ว" (7th of
    // 8 chips) sits outside the default test viewport -- must scroll it
    // into view first, per .wyn/learning/PATTERNS.md ("find.byType()/
    // find.text() มองไม่เห็น widget ที่อยู่นอก viewport...").
    final cancelledChip = find.widgetWithText(ChoiceChip, 'ยกเลิกแล้ว');
    await tester.scrollUntilVisible(
      cancelledChip,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cancelledChip);
    await tester.pumpAndSettle();
    await tester.tap(cancelledChip);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(populatedRepo.lastFetchStoreOrdersFilter, OrderStatus.cancelled);
  });

  testWidgets('does not offer a "pending_payment" filter chip -- unreachable status',
      (tester) async {
    await tester.pumpWidget(buildOrderList(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.widgetWithText(ChoiceChip, 'รอชำระเงิน'), findsNothing);
  });

  testWidgets('tapping an order row opens SellerOrderDetailScreen for that order',
      (tester) async {
    await tester.pumpWidget(buildOrderList(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byType(SellerOrderListTile).first);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(SellerOrderDetailScreen), findsOneWidget);
    final screen = tester.widget<SellerOrderDetailScreen>(find.byType(SellerOrderDetailScreen));
    expect(screen.orderId, 'o1');
  });
}
