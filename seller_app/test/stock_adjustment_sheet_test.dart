import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/product/presentation/widgets/stock_adjustment_sheet.dart';
import 'package:zoky_seller/features/store/data/seller_repository.dart';

/// Regression tests for StockAdjustmentSheet (SELLER-002), per
/// .wyn/docs/design/seller-002-product-management.md, Screen:
/// StockAdjustmentSheet. This widget takes its RPC call as a plain
/// callback (not a repository), so it needs no Recording*Repository
/// (and none of that pattern's Supabase-auto-refresh-Timer gotcha --
/// see seller_product_form_screen_test.dart).
void main() {
  Widget buildOpener({
    required int initialStock,
    required Future<int> Function(int delta) onAdjust,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showStockAdjustmentSheet(
              context,
              initialStock: initialStock,
              onAdjust: onAdjust,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();
  }

  testWidgets('confirm button is disabled while delta is 0', (tester) async {
    await tester.pumpWidget(buildOpener(initialStock: 5, onAdjust: (_) async => 5));
    await openSheet(tester);

    final confirmButton =
        find.widgetWithText(FilledButton, 'ยืนยันการปรับสต็อก');
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);
  });

  testWidgets('the "-" button is disabled once current stock + delta reaches 0',
      (tester) async {
    await tester.pumpWidget(buildOpener(initialStock: 1, onAdjust: (_) async => 0));
    await openSheet(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.remove));
    await tester.pump();

    expect(find.text('-1'), findsOneWidget);
    final minusButton = find.widgetWithIcon(IconButton, Icons.remove);
    expect(tester.widget<IconButton>(minusButton).onPressed, isNull);
  });

  testWidgets(
      'confirming a delta calls onAdjust, updates the shown stock and resets '
      'delta back to 0 without closing the sheet', (tester) async {
    int? lastDelta;
    await tester.pumpWidget(buildOpener(
      initialStock: 5,
      onAdjust: (delta) async {
        lastDelta = delta;
        return 5 + delta;
      },
    ));
    await openSheet(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pump();
    expect(find.text('+2'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันการปรับสต็อก'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    tester.takeException();

    expect(lastDelta, 2);
    expect(find.text('สต็อกปัจจุบัน: 7 ชิ้น'), findsOneWidget);
    expect(find.text('ปรับสต็อกสำเร็จ'), findsOneWidget);
    // Delta reset to 0 -- confirm disabled again, sheet still open.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'ยืนยันการปรับสต็อก'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('InsufficientStockException shows "สต็อกไม่พอ" instead of a raw error',
      (tester) async {
    await tester.pumpWidget(buildOpener(
      initialStock: 5,
      onAdjust: (_) async => throw const InsufficientStockException(),
    ));
    await openSheet(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.remove));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันการปรับสต็อก'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    tester.takeException();

    expect(find.text('สต็อกไม่พอ'), findsOneWidget);
  });

  testWidgets('any other error shows the generic retry message', (tester) async {
    await tester.pumpWidget(buildOpener(
      initialStock: 5,
      onAdjust: (_) async => throw Exception('network down'),
    ));
    await openSheet(tester);

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันการปรับสต็อก'));
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    tester.takeException();

    expect(find.text('ปรับสต็อกไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
  });
}
