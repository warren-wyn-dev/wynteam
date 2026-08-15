import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/finance/presentation/seller_finance_screen.dart';
import 'package:zoky_seller/features/finance/presentation/widgets/seller_transaction_tile.dart';
import 'package:zoky_seller/features/order/data/order.dart';
import 'package:zoky_seller/features/order/presentation/seller_order_detail_screen.dart';
import 'package:zoky_seller/features/store/data/seller_repository.dart';
import 'package:zoky_seller/features/store/data/store.dart';

import 'support/recording_seller_repository.dart';

/// Regression tests for SellerFinanceScreen (SELLER-005), per
/// .wyn/docs/design/seller-005-finance.md, Screen: SellerFinanceScreen.
void main() {
  final store = Store(
    id: 'store-1',
    ownerId: 'u1',
    name: 'ร้านทดสอบ',
    createdAt: DateTime(2026, 1, 1),
  );

  Order order({
    String id = 'o1',
    OrderStatus status = OrderStatus.delivered,
    String recipientName = 'สมชาย ใจดี',
    double subtotal = 900,
    double feeAmount = 100,
  }) =>
      Order(
        id: id,
        storeId: store.id,
        status: status,
        recipientName: recipientName,
        recipientPhone: '0812345678',
        shippingAddress: '123 ถนนทดสอบ',
        subtotal: subtotal,
        feePercent: 10,
        feeAmount: feeAmount,
        total: subtotal + feeAmount,
        createdAt: DateTime(2026, 1, 1),
      );

  const breakdown = SellerFinanceBreakdown(
    today: FinancePeriodTotals(gross: 1100, fee: 100, net: 1000),
    thisMonth: FinancePeriodTotals(gross: 22000, fee: 2000, net: 20000),
    allTime: FinancePeriodTotals(gross: 55000, fee: 5000, net: 50000),
  );

  // See seller_auth_gate_test.dart's comment on why Recording*Repository
  // must be built in setUp(), not inline inside testWidgets.
  late RecordingSellerRepository emptyRepo;
  late RecordingSellerRepository populatedRepo;
  late RecordingSellerRepository errorRepo;
  late RecordingSellerRepository repoForStoreB;

  setUp(() {
    emptyRepo = RecordingSellerRepository();
    populatedRepo = RecordingSellerRepository(
      financeBreakdown: breakdown,
      inTransitSummary: (3000.0, 2),
      platformFeePercent: 10,
      transactionHistory: [
        order(id: 'o1', status: OrderStatus.delivered, recipientName: 'สมชาย ใจดี'),
        order(
          id: 'o2',
          status: OrderStatus.refunded,
          recipientName: 'สมหญิง ดีใจ',
          subtotal: 5000, // deliberately large -- must not leak into the
          // breakdown totals above if the screen is buggy and
          // recomputes from the transaction list instead of trusting
          // fetchFinanceBreakdown.
          feeAmount: 500,
        ),
      ],
      storeOrder: order(id: 'o1', status: OrderStatus.delivered),
      storeOrderItems: const [], // no thumbnails -- avoids Image.network
      // entirely when navigating into SellerOrderDetailScreen (see
      // .wyn/learning/PATTERNS.md's Clipboard/share_plus note on why
      // network-touching platform code should just be avoided in tests
      // rather than swallowed with tester.takeException()).
    );
    errorRepo = RecordingSellerRepository(
      financeBreakdownException: Exception('network down'),
    );
    repoForStoreB = RecordingSellerRepository(financeBreakdown: breakdown);
  });

  Widget buildFinance(RecordingSellerRepository repo, {Store? forStore}) {
    return MaterialApp(
      home: SellerFinanceScreen(store: forStore ?? store, sellerRepository: repo),
    );
  }

  testWidgets('shows a loading spinner before the initial fetch resolves',
      (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('shows an explicit error + retry button on initial load failure, '
      'not a silent fail', (tester) async {
    await tester.pumpWidget(buildFinance(errorRepo));
    await tester.pumpAndSettle();

    expect(find.text('โหลดข้อมูลการเงินไม่สำเร็จ'), findsOneWidget);
    final retryButton = find.widgetWithText(TextButton, 'ลองใหม่');
    expect(retryButton, findsOneWidget);

    expect(errorRepo.fetchFinanceBreakdownCalls, 1);
    await tester.tap(retryButton);
    await tester.pumpAndSettle();
    expect(errorRepo.fetchFinanceBreakdownCalls, 2);
    expect(find.text('โหลดข้อมูลการเงินไม่สำเร็จ'), findsOneWidget);
  });

  testWidgets('empty state: no delivered/refunded orders yet shows "ยังไม่มีประวัติรายรับ" '
      'while the summary cards still render real (zero) totals, not a "coming soon" '
      'placeholder', (tester) async {
    await tester.pumpWidget(buildFinance(emptyRepo));
    await tester.pumpAndSettle();

    // Zero is a real, correct answer here (there's an actual formula
    // behind it) -- must render "฿0", never "เร็ว ๆ นี้" like the old
    // Dashboard placeholder. Checked before scrolling -- the summary
    // section (index 0) is the very first item, always mounted.
    expect(find.text('เร็ว ๆ นี้'), findsNothing);
    expect(find.text('฿0'), findsWidgets);
    expect(find.byType(SellerTransactionTile), findsNothing);

    // The summary section is tall enough that the empty-state message
    // below it sits outside the default 800x600 test viewport + cache
    // extent, so it isn't mounted until scrolled into view -- see
    // .wyn/learning/PATTERNS.md ("find.byType()/find.text() มองไม่เห็น
    // widget ที่อยู่นอก viewport ใน ListView/Sliver").
    final emptyMessage = find.text('ยังไม่มีประวัติรายรับ');
    await tester.scrollUntilVisible(emptyMessage, 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(emptyMessage, findsOneWidget);
  });

  testWidgets('renders Gross/Fee/Net for the default "วันนี้" period, and the '
      'Balance card always shows all-time Net with its disclaimer', (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    await tester.pumpAndSettle();

    // Balance card = allTime.net, always, regardless of the selected period.
    expect(find.text('฿50,000'), findsOneWidget); // allTime.net (Balance)
    expect(
      find.text(
        'ยอดนี้เป็นตัวเลขคำนวณจากคำสั่งซื้อที่ลูกค้าได้รับสินค้าแล้วเท่านั้น '
        'ไม่ใช่เงินในบัญชีธนาคารจริง เนื่องจากยังไม่มีระบบชำระเงิน/โอนเงินเชื่อมต่อ',
      ),
      findsOneWidget,
    );

    // Default period is "วันนี้" -- today's breakdown.
    expect(find.text('฿1,100'), findsOneWidget); // today.gross
    expect(find.text('− ฿100'), findsOneWidget); // today.fee
    // today.net (฿1,000) also equals... nothing else on screen by
    // coincidence in this fixture, safe to assert directly.
    expect(find.text('฿1,000'), findsOneWidget);
  });

  testWidgets('switching the SegmentedButton to "ทั้งหมด" swaps the 3 rows without '
      'a new network call (all 3 periods were already loaded together)', (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    await tester.pumpAndSettle();

    expect(populatedRepo.fetchFinanceBreakdownCalls, 1);

    await tester.tap(find.text('ทั้งหมด'));
    await tester.pumpAndSettle();

    expect(find.text('฿55,000'), findsOneWidget); // allTime.gross
    expect(find.text('− ฿5,000'), findsOneWidget); // allTime.fee
    // allTime.net (฿50,000) already shown by the Balance card too --
    // now shown a second time in the sales summary card.
    expect(find.text('฿50,000'), findsNWidgets(2));
    expect(populatedRepo.fetchFinanceBreakdownCalls, 1);
  });

  testWidgets('in-transit card shows the shipped-but-not-yet-delivered summary, '
      'separate from Balance/Net', (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    await tester.pumpAndSettle();

    expect(find.text('฿3,000 จาก 2 คำสั่งซื้อ'), findsOneWidget);
    expect(
      find.text('ยอดนี้ยังไม่ถูกนับรวมในยอดคงเหลือ จนกว่าลูกค้าจะยืนยันได้รับสินค้า'),
      findsOneWidget,
    );
  });

  testWidgets('in-transit card shows a descriptive message instead of "฿0" when '
      'there is nothing shipped', (tester) async {
    await tester.pumpWidget(buildFinance(emptyRepo));
    await tester.pumpAndSettle();

    expect(find.text('ไม่มีคำสั่งซื้อที่กำลังจัดส่งอยู่ในขณะนี้'), findsOneWidget);
  });

  testWidgets('shows the current platform fee rate with its non-retroactive '
      'disclaimer', (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    await tester.pumpAndSettle();

    expect(find.text('ค่าธรรมเนียมแพลตฟอร์มปัจจุบัน: 10%'), findsOneWidget);
    expect(
      find.text('อัตรานี้ใช้กับคำสั่งซื้อใหม่เท่านั้น ไม่กระทบยอดของคำสั่งซื้อเก่าที่บันทึกอัตราไว้แล้วตอนสั่งซื้อ'),
      findsOneWidget,
    );
  });

  testWidgets('renders one SellerTransactionTile per delivered/refunded order, '
      'newest first, without recomputing Gross/Fee/Net from the refunded row',
      (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    await tester.pumpAndSettle();

    // The refunded row's ฿5,000 subtotal never appears in the "สรุปยอดขาย"
    // card figures, which come only from fetchFinanceBreakdown -- check
    // this before scrolling, while the summary section is still mounted.
    expect(find.text('฿1,100'), findsOneWidget); // today.gross unaffected

    // The transaction rows sit below the tall summary section, outside
    // the default test viewport + cache extent -- scroll them into view
    // first. See .wyn/learning/PATTERNS.md. Note: the finder passed to
    // scrollUntilVisible must NOT be `.first`-wrapped -- evaluating
    // `.first` on zero matches throws a StateError immediately, before
    // any scrolling can happen.
    await tester.scrollUntilVisible(
      find.byType(SellerTransactionTile),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byType(SellerTransactionTile), findsNWidgets(2));
  });

  testWidgets('the "ถอนเงิน" button always looks/works the same regardless of '
      'balance -- opens the explanation bottom sheet with the exact copy, never '
      'triggers a real payout call', (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('ปุ่มถอนเงิน ยังไม่พร้อมใช้งานในเวอร์ชันนี้ แตะเพื่อดูรายละเอียด'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'ถอนเงิน'));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่รองรับการถอนเงิน'), findsOneWidget);
    expect(
      find.text(
        'ยังไม่รองรับการถอนเงินในเวอร์ชันนี้ เนื่องจากยังไม่มีระบบชำระเงิน '
        '(Payment Gateway) เชื่อมต่อกับแพลตฟอร์ม ยอดคงเหลือที่แสดงเป็นตัวเลข'
        'คำนวณเพื่อการติดตามเท่านั้น',
      ),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'เข้าใจแล้ว'));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่รองรับการถอนเงิน'), findsNothing);
    // No repository write method was ever called by any of the above.
    expect(populatedRepo.sellerStartProcessingCalls, 0);
    expect(populatedRepo.sellerCancelOrderCalls, 0);
    expect(populatedRepo.sellerMarkRefundedCalls, 0);
  });

  testWidgets('tapping a transaction row opens SellerOrderDetailScreen for that '
      'order and does not reload Finance on return (read-only screen)',
      (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    await tester.pumpAndSettle();

    expect(populatedRepo.fetchFinanceBreakdownCalls, 1);

    // Scroll the transaction rows into view first -- see the note on
    // .wyn/learning/PATTERNS.md in the test above.
    await tester.scrollUntilVisible(
      find.byType(SellerTransactionTile),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SellerTransactionTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(SellerOrderDetailScreen), findsOneWidget);
    final screen = tester.widget<SellerOrderDetailScreen>(find.byType(SellerOrderDetailScreen));
    expect(screen.orderId, 'o1');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(populatedRepo.fetchFinanceBreakdownCalls, 1);
  });

  testWidgets('pull-to-refresh reloads the breakdown/in-transit/fee-rate/first-page '
      'together', (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo));
    await tester.pumpAndSettle();
    expect(populatedRepo.fetchFinanceBreakdownCalls, 1);
    expect(populatedRepo.fetchInTransitSummaryCalls, 1);
    expect(populatedRepo.fetchPlatformFeePercentCalls, 1);

    // Invoking RefreshIndicator.onRefresh directly (rather than a
    // gesture-based fling) is deterministic and mirrors what the
    // pull-to-refresh gesture actually triggers under the hood.
    final indicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect(populatedRepo.fetchFinanceBreakdownCalls, 2);
    expect(populatedRepo.fetchInTransitSummaryCalls, 2);
    expect(populatedRepo.fetchPlatformFeePercentCalls, 2);
  });

  // Split into 2 separate testWidgets blocks (rather than 2 pumpWidget
  // calls in one test) -- pumping a second widget of the same type/
  // position in one test only triggers didUpdateWidget, not a fresh
  // initState, so the screen's own _loadInitial() would never re-run
  // for the second store/repo. See .wyn/learning/PATTERNS.md.
  testWidgets("every finance query is scoped to store A's own id when built for "
      'store A (relies on the RLS select policy, same as every other '
      'SellerRepository read)', (tester) async {
    await tester.pumpWidget(buildFinance(populatedRepo, forStore: store));
    await tester.pumpAndSettle();

    expect(populatedRepo.lastFetchFinanceBreakdownStoreId, 'store-1');
    expect(populatedRepo.lastFetchInTransitSummaryStoreId, 'store-1');
    expect(populatedRepo.lastFetchTransactionHistoryStoreId, 'store-1');
  });

  testWidgets("every finance query is scoped to store B's own id when built for "
      'store B -- never store A\'s id leaking through', (tester) async {
    final storeB = Store(
      id: 'store-2',
      ownerId: 'u2',
      name: 'ร้าน B',
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(buildFinance(repoForStoreB, forStore: storeB));
    await tester.pumpAndSettle();

    expect(repoForStoreB.lastFetchFinanceBreakdownStoreId, 'store-2');
    expect(repoForStoreB.lastFetchInTransitSummaryStoreId, 'store-2');
    expect(repoForStoreB.lastFetchTransactionHistoryStoreId, 'store-2');
  });
}
