import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/product/data/category.dart';
import 'package:zoky_seller/features/product/data/product.dart';
import 'package:zoky_seller/features/product/presentation/seller_product_form_screen.dart';
import 'package:zoky_seller/features/product/presentation/widgets/stock_adjustment_sheet.dart';

import 'support/recording_seller_repository.dart';

/// Regression tests for SellerProductFormScreen (SELLER-002), per
/// .wyn/docs/design/seller-002-product-management.md, Screen:
/// SellerProductFormScreen.
void main() {
  final product = Product(
    id: 'p1',
    storeId: 'store-1',
    storeName: 'ร้านทดสอบ',
    name: 'เสื้อยืด',
    description: 'คำอธิบาย',
    price: 199,
    stock: 10,
    imageUrls: const ['https://example.supabase.co/products/p1.jpg'],
    isActive: true,
    sku: 'SKU1',
    createdAt: DateTime(2026, 1, 1),
  );

  const category = Category(id: 'cat-1', name: 'Fashion');

  // See seller_auth_gate_test.dart's comment on why Recording*Repository
  // must be built in setUp(), not inline inside testWidgets -- building
  // a fresh SupabaseClient (which every RecordingSellerRepository does
  // internally) starts a GoTrue auto-refresh Timer that's only safely
  // torn down when the repository outlives the pumped widget tree, i.e.
  // when it's constructed before pumpWidget via setUp().
  late RecordingSellerRepository repo;
  late RecordingSellerRepository stockRepo;

  setUp(() {
    repo = RecordingSellerRepository(categories: const [category]);
    stockRepo = RecordingSellerRepository(
      categories: const [category],
      adjustProductStockResult: 11,
    );
  });

  Future<void> pumpEditForm(WidgetTester tester, {Product? withProduct}) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductFormScreen(
        sellerRepository: repo,
        storeId: 'store-1',
        existingProduct: withProduct ?? product,
      ),
    ));
    await tester.pumpAndSettle();
    // The existing image thumbnail is a real Image.network -- the test
    // HTTP client always returns 400, expected/harmless (see
    // app/test/store_screen_test.dart's identical convention).
    tester.takeException();
  }

  testWidgets(
      'create mode: submit stays disabled without an image, even once every '
      'other required field is filled (image_picker has no platform-channel '
      'mock in this sandbox, same limitation as CreateDropScreen -- see '
      '.wyn/learning/PATTERNS.md)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductFormScreen(sellerRepository: repo, storeId: 'store-1'),
    ));
    await tester.pumpAndSettle();

    final submitButton = find.widgetWithText(FilledButton, 'สร้างสินค้า');
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'สินค้าใหม่'); // name
    await tester.enterText(find.byType(TextField).at(1), '100'); // price
    await tester.pump();

    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);
  });

  testWidgets(
      'edit mode: pre-fills every field, shows current stock read-only, and '
      'the submit button is enabled without needing a category (unlike '
      'create mode)', (tester) async {
    await pumpEditForm(tester);

    expect(find.text('แก้ไขสินค้า'), findsOneWidget);
    expect(find.text('สต็อกปัจจุบัน: 10 ชิ้น'), findsOneWidget);
    // No absolute-stock text field anywhere in edit mode.
    expect(find.widgetWithText(TextField, 'จำนวนสินค้าเริ่มต้น'), findsNothing);

    final submitButton = find.widgetWithText(FilledButton, 'บันทึกการแก้ไข');
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNotNull);
  });

  testWidgets(
      'edit mode: entering an original price below the real price shows an '
      'inline error on submit and does not call updateProduct',
      (tester) async {
    await pumpEditForm(tester);

    await tester.enterText(find.byType(TextField).at(2), '100'); // original price < 199
    await tester.pump();
    final submitButton = find.widgetWithText(FilledButton, 'บันทึกการแก้ไข');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ราคาก่อนลดต้องมากกว่าหรือเท่ากับราคาจริง'), findsOneWidget);
    expect(repo.updateProductCalls, 0);
  });

  testWidgets(
      'edit mode: submitting with an edited name pops back true and calls '
      'updateProduct', (tester) async {
    // Pushed (not used as `home:` directly) so Navigator.pop(true) on
    // success resolves against a real previous route -- same wrapper
    // shape as zoky_checkout_summary_screen_test.dart's "pops back to
    // the first route" test.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SellerProductFormScreen(
                      sellerRepository: repo,
                      storeId: 'store-1',
                      existingProduct: product,
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.enterText(find.byType(TextField).at(0), 'เสื้อยืดใหม่');
    await tester.pump();
    final submitButton = find.widgetWithText(FilledButton, 'บันทึกการแก้ไข');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.updateProductCalls, 1);
    expect(find.byType(SellerProductFormScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets(
      'edit mode: "ลบสินค้า" opens a soft-delete confirm dialog; cancelling '
      'calls nothing', (tester) async {
    await pumpEditForm(tester);

    final deleteButton = find.text('ลบสินค้า');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.textContaining('สินค้านี้จะถูกซ่อนจากลูกค้าทันที'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastSetProductActiveId, isNull);
  });

  testWidgets(
      'edit mode: confirming "ลบสินค้า" calls setProductActive(id, false) and '
      'the button flips to "เปิดขายอีกครั้ง"', (tester) async {
    await pumpEditForm(tester);

    final deleteButton = find.text('ลบสินค้า');
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(
      find.descendant(of: find.byType(AlertDialog), matching: find.text('ลบสินค้า')),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastSetProductActiveId, 'p1');
    expect(repo.lastSetProductActiveValue, false);
    expect(find.text('เปิดขายอีกครั้ง'), findsOneWidget);
  });

  testWidgets(
      'edit mode: "เปิดขายอีกครั้ง" on an already-inactive product calls '
      'setProductActive(id, true) without any confirm dialog', (tester) async {
    await pumpEditForm(
      tester,
      withProduct: Product(
        id: 'p2',
        storeId: 'store-1',
        storeName: 'ร้านทดสอบ',
        name: 'สินค้าที่ปิดขาย',
        price: 50,
        stock: 5,
        imageUrls: const ['https://example.supabase.co/products/p2.jpg'],
        isActive: false,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

    final reactivateButton = find.text('เปิดขายอีกครั้ง');
    await tester.ensureVisible(reactivateButton);
    await tester.tap(reactivateButton);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.lastSetProductActiveId, 'p2');
    expect(repo.lastSetProductActiveValue, true);
    expect(find.text('ลบสินค้า'), findsOneWidget);
  });

  testWidgets(
      'edit mode: "ปรับสต็อก" opens StockAdjustmentSheet; confirming a +1 '
      'delta calls adjustProductStock and updates the displayed stock',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductFormScreen(
        sellerRepository: stockRepo,
        storeId: 'store-1',
        existingProduct: product,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final adjustButton = find.widgetWithText(TextButton, 'ปรับสต็อก');
    await tester.ensureVisible(adjustButton);
    await tester.tap(adjustButton);
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'ยืนยันการปรับสต็อก'));
    // A bounded number of pumps rather than pumpAndSettle -- the
    // success SnackBar keeps a timer alive that pumpAndSettle waits on
    // indefinitely, same gotcha as zoky_checkout_summary_screen_test
    // .dart's "tapping ยืนยันคำสั่งซื้อ" test.
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    tester.takeException();

    expect(stockRepo.lastAdjustProductStockId, 'p1');
    expect(stockRepo.lastAdjustProductStockDelta, 1);
    expect(find.text('สต็อกปัจจุบัน: 11 ชิ้น'), findsWidgets);

    // The sheet deliberately doesn't auto-close on success (per the
    // Design spec) -- close it explicitly so no SnackBar/animation
    // timer is left pending when the test tears down.
    Navigator.of(tester.element(find.byType(StockAdjustmentSheet))).pop();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'edit mode: adding a new color variant and submitting includes it in '
      'updateProduct\'s variants list', (tester) async {
    await pumpEditForm(tester);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'เพิ่มสี'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'เพิ่มสี'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'สี'), 'แดง');
    await tester.enterText(find.widgetWithText(TextField, 'สต็อกเริ่มต้น'), '5');
    await tester.pump();

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'บันทึกการแก้ไข'));
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึกการแก้ไข'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.updateProductCalls, 1);
    final variants = repo.lastUpdateProductVariants!;
    expect(variants.single.value, 'แดง');
    expect(variants.single.stock, 5);
  });
}
