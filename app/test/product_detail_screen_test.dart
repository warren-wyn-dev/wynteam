import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/data/product_variant.dart';
import 'package:wyn/features/zoky/presentation/product_detail_screen.dart';
import 'package:wyn/features/zoky/presentation/store_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ProductDetailScreen (ZOKY-001), per
/// .wyn/docs/design/zoky-001-marketplace-foundation.md, Screen 2.
void main() {
  final discountedProduct = Product(
    id: 'p1',
    storeId: 'store-1',
    storeName: 'ร้านทดสอบ',
    name: 'เสื้อยืด',
    description: 'เสื้อยืดผ้าฝ้าย 100%',
    price: 300,
    originalPrice: 400,
    stock: 5,
    imageUrls: const [
      'https://example.supabase.co/products/p1a.jpg',
      'https://example.supabase.co/products/p1b.jpg',
    ],
    createdAt: DateTime.now(),
  );

  final outOfStockProduct = Product(
    id: 'p2',
    storeId: 'store-1',
    storeName: 'ร้านทดสอบ',
    name: 'กระเป๋า',
    price: 500,
    stock: 0,
    imageUrls: const ['https://example.supabase.co/products/p2.jpg'],
    createdAt: DateTime.now(),
  );

  const colorVariant = ProductVariant(
    id: 'v1',
    productId: 'p1',
    type: VariantType.color,
    value: 'แดง',
    stock: 5,
  );
  const sizeVariant = ProductVariant(
    id: 'v2',
    productId: 'p1',
    type: VariantType.size,
    value: 'M',
    stock: 5,
  );

  late RecordingZokyRepository discountedRepo;
  late RecordingZokyRepository outOfStockRepo;
  late RecordingZokyRepository variantsRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    discountedRepo = RecordingZokyRepository();
    outOfStockRepo = RecordingZokyRepository();
    variantsRepo = RecordingZokyRepository(productVariants: [colorVariant, sizeVariant]);
  });

  Widget buildProductDetail(RecordingZokyRepository repo, Product product) {
    return MaterialApp(
      home: ProductDetailScreen(zokyRepository: repo, product: product),
    );
  }

  // The image carousel (AspectRatio 1, 800px wide in this test viewport)
  // pushes everything below it out of the lazily-built sliver range --
  // see .wyn/learning/PATTERNS.md and drop_comment_delete_test.dart for
  // the same technique on DropDetailScreen.
  Future<void> scrollToFind(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
        finder,
        500,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('shows price, discount badge, and struck-through original price',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(discountedRepo, discountedProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await scrollToFind(tester, find.text('฿300'));
    tester.takeException();

    expect(find.text('฿300'), findsOneWidget);
    expect(find.text('฿400'), findsOneWidget);
    expect(find.text('-25%'), findsOneWidget);
  });

  testWidgets('shows stock count when in stock, "สินค้าหมด" when out of stock',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(outOfStockRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await scrollToFind(tester, find.text('สินค้าหมด'));
    tester.takeException();

    expect(find.text('สินค้าหมด'), findsOneWidget);
  });

  testWidgets('shows "ยังไม่มีรีวิว" since Review (ZOKY-004) does not exist yet',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(outOfStockRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await scrollToFind(tester, find.text('ยังไม่มีรีวิว'));
    tester.takeException();

    expect(find.text('ยังไม่มีรีวิว'), findsOneWidget);
  });

  testWidgets('renders Color/Size variant chips and selecting one does not throw',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(variantsRepo, discountedProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await scrollToFind(tester, find.text('สี'));
    tester.takeException();

    expect(find.text('สี'), findsOneWidget);
    expect(find.text('ไซส์'), findsOneWidget);
    expect(find.text('แดง'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);

    await tester.tap(find.text('แดง'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping Add to Cart shows a coming-soon SnackBar and does not crash',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(outOfStockRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('เพิ่มลงตะกร้า'));
    await tester.pump();

    expect(find.text('ฟีเจอร์นี้จะมาเร็ว ๆ นี้'), findsOneWidget);
  });

  testWidgets('tapping Buy Now shows a coming-soon SnackBar and does not crash',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(outOfStockRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ซื้อเลย'));
    await tester.pump();

    expect(find.text('ฟีเจอร์นี้จะมาเร็ว ๆ นี้'), findsOneWidget);
  });

  testWidgets('tapping the store card opens StoreScreen', (tester) async {
    await tester.pumpWidget(buildProductDetail(outOfStockRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    // The store card is the very last item in the scroll body --
    // scrollUntilVisible's minimal-movement stops right at its edge,
    // which is unreliable to tap precisely, so drag further to give it
    // clear room above the fixed bottom action bar.
    await scrollToFind(tester, find.text('ร้านทดสอบ'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ร้านทดสอบ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(StoreScreen), findsOneWidget);
  });
}
