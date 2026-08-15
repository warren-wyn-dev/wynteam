import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/finance/presentation/widgets/seller_transaction_tile.dart';
import 'package:zoky_seller/features/order/data/order.dart';
import 'package:zoky_seller/features/order/presentation/widgets/order_status_badge.dart';

/// Regression tests for SellerTransactionTile (SELLER-005), per
/// .wyn/docs/design/seller-005-finance.md, Widget: SellerTransactionTile.
void main() {
  Order order({OrderStatus status = OrderStatus.delivered}) => Order(
        id: 'order-12345678-abcd',
        storeId: 'store-1',
        status: status,
        recipientName: 'สมชาย ใจดี',
        recipientPhone: '0812345678',
        shippingAddress: '123 ถนนทดสอบ',
        subtotal: 900,
        feePercent: 10,
        feeAmount: 100,
        total: 1000,
        createdAt: DateTime(2026, 1, 1),
      );

  Widget buildTile(Order order, {VoidCallback? onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: SellerTransactionTile(order: order, onTap: onTap ?? () {}),
      ),
    );
  }

  testWidgets('delivered: shows the gross - fee = net formula, no thumbnail, and '
      'the delivered status badge', (tester) async {
    await tester.pumpWidget(buildTile(order(status: OrderStatus.delivered)));
    await tester.pumpAndSettle();

    expect(find.text('ผู้ซื้อ: สมชาย ใจดี'), findsOneWidget);
    final badge = tester.widget<OrderStatusBadge>(find.byType(OrderStatusBadge));
    expect(badge.status, OrderStatus.delivered);

    // No product thumbnail -- SellerTransactionTile never queries
    // order_items, unlike SellerOrderListTile.
    expect(find.byType(Image), findsNothing);

    final formulaText = tester.widget<Text>(
      find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
    );
    expect(formulaText.textSpan!.toPlainText(), '฿900 − ฿100 = ฿900');

    // The refund-only explanatory line must never appear for a
    // delivered row.
    expect(find.text('คืนเงินแล้ว — ไม่นับรวมในยอดคงเหลือ'), findsNothing);
  });

  testWidgets('refunded: strikes through the formula and shows the "ไม่นับรวม" '
      'label, not silently omitted', (tester) async {
    await tester.pumpWidget(buildTile(order(status: OrderStatus.refunded)));
    await tester.pumpAndSettle();

    final badge = tester.widget<OrderStatusBadge>(find.byType(OrderStatusBadge));
    expect(badge.status, OrderStatus.refunded);

    final formulaText = tester.widget<Text>(
      find.byWidgetPredicate(
        (w) => w is Text && (w.data?.contains(' = ') ?? false),
      ),
    );
    expect(formulaText.data, '฿900 − ฿100 = ฿900');
    expect(formulaText.style?.decoration, TextDecoration.lineThrough);

    // The visual strike-through must always be paired with an explicit
    // text explanation -- never color/decoration alone (Product spec's
    // Risks, Design spec's Accessibility).
    expect(find.text('คืนเงินแล้ว — ไม่นับรวมในยอดคงเหลือ'), findsOneWidget);
  });

  testWidgets('semantics label speaks "นับรวม" for delivered and "ไม่นับรวม" for '
      'refunded explicitly, not left to the screen reader to infer from styling',
      (tester) async {
    await tester.pumpWidget(buildTile(order(status: OrderStatus.delivered)));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('ผู้ซื้อ สมชาย ใจดี, ยอดสุทธิ ฿900 บาท, นับรวมในยอดคงเหลือ'),
      findsOneWidget,
    );
  });

  testWidgets('semantics label for a refunded row', (tester) async {
    await tester.pumpWidget(buildTile(order(status: OrderStatus.refunded)));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('ผู้ซื้อ สมชาย ใจดี, คืนเงินแล้ว, ไม่นับรวมในยอดคงเหลือ'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the row calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(buildTile(order(), onTap: () => tapped = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SellerTransactionTile));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('shows the short order reference derived from the id, not a raw UUID',
      (tester) async {
    await tester.pumpWidget(buildTile(order()));
    await tester.pumpAndSettle();

    expect(find.textContaining('#ORDER-12'), findsOneWidget);
  });
}
