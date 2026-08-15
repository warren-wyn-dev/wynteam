import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/order_item.dart';
import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/data/product_variant.dart';
import 'package:wyn/features/zoky/data/review.dart';
import 'package:wyn/features/zoky/presentation/product_detail_screen.dart';
import 'package:wyn/features/zoky/presentation/product_reviews_screen.dart';
import 'package:wyn/features/zoky/presentation/store_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_cart_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_order_list_screen.dart';

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
  late RecordingZokyRepository withReviewsRepo;
  late RecordingZokyRepository manyReviewsRepo;
  late RecordingZokyRepository oneReviewableRepo;
  late RecordingZokyRepository twoReviewableRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    discountedRepo = RecordingZokyRepository();
    outOfStockRepo = RecordingZokyRepository();
    variantsRepo = RecordingZokyRepository(productVariants: [colorVariant, sizeVariant]);
    withReviewsRepo = RecordingZokyRepository(
      productRating: (4.0, 2),
      productReviews: [
        Review(
          id: 'r1',
          orderItemId: 'oi1',
          productId: outOfStockProduct.id,
          userId: 'u1',
          authorUsername: 'somchai',
          authorDisplayName: 'สมชาย',
          rating: 4,
          textContent: 'สินค้าดีมาก',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );
    manyReviewsRepo = RecordingZokyRepository(productRating: (4.5, 10));
    oneReviewableRepo = RecordingZokyRepository(
      reviewableOrderItems: const [
        OrderItem(
          id: 'oi1',
          productId: 'p2',
          productName: 'กระเป๋า',
          variantSelection: '',
          unitPrice: 500,
          quantity: 1,
          imageUrl: null,
        ),
      ],
    );
    twoReviewableRepo = RecordingZokyRepository(
      reviewableOrderItems: const [
        OrderItem(
          id: 'oi1',
          productId: 'p2',
          productName: 'กระเป๋า',
          variantSelection: '',
          unitPrice: 500,
          quantity: 1,
          imageUrl: null,
        ),
        OrderItem(
          id: 'oi2',
          productId: 'p2',
          productName: 'กระเป๋า',
          variantSelection: '',
          unitPrice: 500,
          quantity: 1,
          imageUrl: null,
        ),
      ],
    );
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

  testWidgets(
      'shows stock count when in stock, "สินค้าหมด" (stock line + both disabled '
      'action buttons) when out of stock (ZOKY-003)', (tester) async {
    await tester.pumpWidget(buildProductDetail(outOfStockRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    // The fixed bottom action bar's "สินค้าหมด" buttons are always
    // mounted, so scrollUntilVisible on the bare text would already be
    // ambiguous before ever scrolling -- scope to the scrollable body
    // to find just the stock-count line.
    final stockLineInBody = find.descendant(
      of: find.byType(ListView),
      matching: find.text('สินค้าหมด'),
    );
    await tester.scrollUntilVisible(stockLineInBody, 500, scrollable: find.byType(Scrollable).first);
    tester.takeException();

    expect(stockLineInBody, findsOneWidget);
    // Both "เพิ่มลงตะกร้า"/"ซื้อเลย" buttons relabel to "สินค้าหมด" too
    // (ZOKY-003 Design, Screen 1).
    expect(find.text('สินค้าหมด'), findsNWidgets(3));
  });

  testWidgets('shows "ยังไม่มีรีวิว" when the product has no reviews yet (ZOKY-004)',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(outOfStockRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await scrollToFind(tester, find.text('ยังไม่มีรีวิว'));
    tester.takeException();

    expect(find.text('ยังไม่มีรีวิว'), findsOneWidget);
  });

  testWidgets('shows the average rating and review tiles when reviews exist (ZOKY-004)',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(withReviewsRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await scrollToFind(tester, find.text('4.0 (2 รีวิว)'));
    tester.takeException();
    expect(find.text('4.0 (2 รีวิว)'), findsOneWidget);

    // The review tile itself sits further down than the rating summary
    // -- same "still out of the lazily-built sliver range" situation as
    // the store card test below, so scroll again to reach it.
    await scrollToFind(tester, find.text('สมชาย'));
    tester.takeException();

    expect(find.text('สมชาย'), findsOneWidget);
    expect(find.text('สินค้าดีมาก'), findsOneWidget);
    // Only 2 reviews total (<= the 3-item preview limit) -- no "ดูรีวิวทั้งหมด" link.
    expect(find.text('ดูรีวิวทั้งหมด'), findsNothing);
  });

  testWidgets('"ดูรีวิวทั้งหมด" opens ProductReviewsScreen when there are more than 3 reviews '
      '(ZOKY-004)', (tester) async {
    await tester.pumpWidget(buildProductDetail(manyReviewsRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await scrollToFind(tester, find.text('ดูรีวิวทั้งหมด'));
    tester.takeException();

    await tester.tap(find.text('ดูรีวิวทั้งหมด'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ProductReviewsScreen), findsOneWidget);
  });

  testWidgets(
      'shows a direct "เขียนรีวิว" entry point when exactly one delivered order_item is '
      'reviewable (ZOKY-004)', (tester) async {
    await tester.pumpWidget(buildProductDetail(oneReviewableRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await scrollToFind(tester, find.text('เขียนรีวิว'));
    tester.takeException();

    expect(find.text('เขียนรีวิว'), findsOneWidget);

    await tester.tap(find.text('เขียนรีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    // ReviewFormSheet opened as a modal bottom sheet.
    expect(find.text('ส่งรีวิว'), findsOneWidget);
  });

  testWidgets(
      'points at Order List instead of a picker when more than one delivered order_item is '
      'reviewable (ZOKY-004)', (tester) async {
    await tester.pumpWidget(buildProductDetail(twoReviewableRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    final entryPoint = find.text('คุณมีสินค้าที่ยังไม่ได้รีวิว ไปที่คำสั่งซื้อของคุณ');
    await scrollToFind(tester, entryPoint);
    tester.takeException();

    expect(entryPoint, findsOneWidget);
    expect(find.text('เขียนรีวิว'), findsNothing);

    await tester.tap(entryPoint);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ZokyOrderListScreen), findsOneWidget);
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

  testWidgets(
      'out-of-stock product disables both action buttons (tap does nothing, no crash) '
      '(ZOKY-003)', (tester) async {
    await tester.pumpWidget(buildProductDetail(outOfStockRepo, outOfStockProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithText(OutlinedButton, 'สินค้าหมด'), warnIfMissed: false);
    await tester.tap(find.widgetWithText(FilledButton, 'สินค้าหมด'), warnIfMissed: false);
    await tester.pump();
    tester.takeException();

    expect(outOfStockRepo.lastAddToCartProductId, isNull);
  });

  testWidgets('tapping Add to Cart adds the item and shows a confirmation SnackBar (ZOKY-003)',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(discountedRepo, discountedProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('เพิ่มลงตะกร้า'));
    await tester.pump();

    expect(discountedRepo.lastAddToCartProductId, discountedProduct.id);
    expect(find.text('เพิ่มลงตะกร้าแล้ว'), findsOneWidget);
  });

  testWidgets('tapping Buy Now adds the item and opens ZokyCartScreen (ZOKY-003)',
      (tester) async {
    await tester.pumpWidget(buildProductDetail(discountedRepo, discountedProduct));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ซื้อเลย'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(discountedRepo.lastAddToCartProductId, discountedProduct.id);
    expect(find.byType(ZokyCartScreen), findsOneWidget);
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
