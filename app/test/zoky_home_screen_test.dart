import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/cart_item.dart';
import 'package:wyn/features/zoky/data/category.dart';
import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/data/store.dart';
import 'package:wyn/features/zoky/presentation/product_detail_screen.dart';
import 'package:wyn/features/zoky/presentation/store_screen.dart';
import 'package:wyn/features/zoky/presentation/widgets/product_grid_tile.dart';
import 'package:wyn/features/zoky/presentation/zoky_cart_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_home_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_order_list_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_search_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ZokyHomeScreen (ZOKY-001), per
/// .wyn/docs/design/zoky-001-marketplace-foundation.md, Screen 1.
void main() {
  Product product({
    String id = 'p1',
    String name = 'เสื้อยืด',
    double price = 199,
    double? originalPrice,
    List<String>? imageUrls,
  }) =>
      Product(
        id: id,
        storeId: 'store-1',
        storeName: 'ร้านทดสอบ',
        name: name,
        price: price,
        originalPrice: originalPrice,
        stock: 10,
        imageUrls: imageUrls ?? const ['https://example.supabase.co/products/p1.jpg'],
        createdAt: DateTime.now(),
      );

  Store store({String id = 'store-1', String name = 'ร้านทดสอบ', int productCount = 3}) => Store(
        id: id,
        ownerId: 'owner-1',
        name: name,
        createdAt: DateTime.now(),
        productCount: productCount,
      );

  const category = Category(id: 'cat-1', name: 'Fashion');

  late RecordingZokyRepository emptyRepo;
  late RecordingZokyRepository populatedRepo;
  late RecordingZokyRepository repoWithCart;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    emptyRepo = RecordingZokyRepository();
    repoWithCart = RecordingZokyRepository(
      cartItems: [
        CartItem(id: 'ci1', product: product(), variantSelection: '', quantity: 2),
        CartItem(
          id: 'ci2',
          product: product(id: 'p2', name: 'กางเกงยีนส์'),
          variantSelection: '',
          quantity: 1,
        ),
      ],
    );
    populatedRepo = RecordingZokyRepository(
      categories: [category],
      newProducts: [product()],
      recommendedStores: [store()],
      gridProducts: [product(id: 'p2', name: 'กางเกงยีนส์', price: 599)],
    );
  });

  Widget buildZokyHome(RecordingZokyRepository repo) {
    return MaterialApp(home: ZokyHomeScreen(zokyRepository: repo));
  }

  // Content below the banner/coming-soon sections sits below the fold
  // in this 800x600 test viewport -- see .wyn/learning/PATTERNS.md.
  Future<void> scrollToFind(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
        finder,
        500,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('shows empty-state text for New Products/Recommended Stores/grid '
      'when there is no data', (tester) async {
    await tester.pumpWidget(buildZokyHome(emptyRepo));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีสินค้าในระบบ'), findsNWidgets(3));
  });

  testWidgets('shows "เร็ว ๆ นี้" placeholder for Recommended/Best Selling sections',
      (tester) async {
    await tester.pumpWidget(buildZokyHome(emptyRepo));
    await tester.pumpAndSettle();

    expect(find.text('แนะนำสำหรับคุณ'), findsOneWidget);
    expect(find.text('ขายดี'), findsOneWidget);
    expect(find.text('เร็ว ๆ นี้'), findsNWidgets(2));
  });

  testWidgets('renders New Products when populated', (tester) async {
    await tester.pumpWidget(buildZokyHome(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('เสื้อยืด'), findsOneWidget);
  });

  testWidgets('renders Recommended Stores and the main grid when populated',
      (tester) async {
    await tester.pumpWidget(buildZokyHome(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    // Recommended Stores and the main grid both sit below the fold in
    // this 800x600 test viewport -- see .wyn/learning/PATTERNS.md.
    await scrollToFind(tester, find.text('ร้านทดสอบ'));
    tester.takeException();
    expect(find.text('ร้านทดสอบ'), findsOneWidget);

    // ProductGridTile (the main grid) shows only a price badge visually
    // -- the product name is Semantics-only, so assert on the tile type.
    await scrollToFind(tester, find.byType(ProductGridTile));
    tester.takeException();
    expect(find.byType(ProductGridTile), findsOneWidget);
  });

  testWidgets('renders category chips from fetchCategories', (tester) async {
    await tester.pumpWidget(buildZokyHome(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('Fashion'), findsOneWidget);
  });

  testWidgets('tapping the search bar opens ZokySearchScreen (ZOKY-002)', (tester) async {
    await tester.pumpWidget(buildZokyHome(emptyRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ค้นหาสินค้า/ร้านค้า'));
    await tester.pumpAndSettle();

    expect(find.byType(ZokySearchScreen), findsOneWidget);
  });

  testWidgets('tapping the Cart icon opens ZokyCartScreen (ZOKY-003)', (tester) async {
    await tester.pumpWidget(buildZokyHome(emptyRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.shopping_cart_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(ZokyCartScreen), findsOneWidget);
  });

  testWidgets('tapping the Orders icon opens ZokyOrderListScreen (ZOKY-003)', (tester) async {
    await tester.pumpWidget(buildZokyHome(emptyRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(ZokyOrderListScreen), findsOneWidget);
  });

  testWidgets('shows a Cart badge reflecting the number of distinct cart lines (ZOKY-003)',
      (tester) async {
    await tester.pumpWidget(buildZokyHome(repoWithCart));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('tapping a category chip opens ZokySearchScreen pre-filtered (ZOKY-002)',
      (tester) async {
    await tester.pumpWidget(buildZokyHome(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('Fashion'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ZokySearchScreen), findsOneWidget);
    final searchScreen = tester.widget<ZokySearchScreen>(find.byType(ZokySearchScreen));
    expect(searchScreen.initialCategory?.name, 'Fashion');
  });

  testWidgets('tapping a product in the grid opens ProductDetailScreen', (tester) async {
    await tester.pumpWidget(buildZokyHome(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    // ProductGridTile shows only a price badge visually (the product
    // name is Semantics-only) -- scroll/tap the tile itself.
    await scrollToFind(tester, find.byType(ProductGridTile));
    tester.takeException();

    await tester.tap(find.byType(ProductGridTile));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a store card opens StoreScreen', (tester) async {
    await tester.pumpWidget(buildZokyHome(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    // scrollUntilVisible's minimal-movement stops right at the target's
    // edge, which is unreliable to tap precisely -- nudge a bit further.
    await scrollToFind(tester, find.text('ร้านทดสอบ'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -100));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ร้านทดสอบ').first);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(StoreScreen), findsOneWidget);
  });
}
