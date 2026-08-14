import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/category.dart';
import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/data/store.dart';
import 'package:wyn/features/zoky/data/zoky_repository.dart';
import 'package:wyn/features/zoky/presentation/product_detail_screen.dart';
import 'package:wyn/features/zoky/presentation/store_screen.dart';
import 'package:wyn/features/zoky/presentation/widgets/product_grid_tile.dart';
import 'package:wyn/features/zoky/presentation/zoky_search_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for ZokySearchScreen (ZOKY-002), per
/// .wyn/docs/design/zoky-002-search-and-filter.md.
void main() {
  final product = Product(
    id: 'p1',
    storeId: 'store-1',
    storeName: 'ร้านทดสอบ',
    name: 'เสื้อยืดสีแดง',
    price: 199,
    stock: 10,
    imageUrls: const ['https://example.supabase.co/products/p1.jpg'],
    createdAt: DateTime.now(),
  );

  final store = Store(
    id: 'store-1',
    ownerId: 'owner-1',
    name: 'ร้านทดสอบ',
    createdAt: DateTime.now(),
    productCount: 3,
  );

  const category = Category(id: 'cat-1', name: 'Fashion');

  late RecordingZokyRepository repo;
  late RecordingZokyRepository emptyRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    repo = RecordingZokyRepository(
      categories: [category],
      searchProductResults: [product],
      searchStoreResults: [store],
      store: store,
    );
    emptyRepo = RecordingZokyRepository(categories: [category]);
  });

  Widget buildSearch(RecordingZokyRepository repo, {Category? initialCategory}) {
    return MaterialApp(
      home: ZokySearchScreen(zokyRepository: repo, initialCategory: initialCategory),
    );
  }

  Future<void> typeQuery(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('shows a type-to-search prompt on both tabs before typing', (tester) async {
    await tester.pumpWidget(buildSearch(repo));
    await tester.pumpAndSettle();

    expect(find.text('พิมพ์ชื่อสินค้าเพื่อค้นหา'), findsOneWidget);

    await tester.tap(find.text('ร้านค้า'));
    await tester.pumpAndSettle();
    expect(find.text('พิมพ์ชื่อร้านค้าเพื่อค้นหา'), findsOneWidget);
  });

  testWidgets('typing in the Product tab searches after the debounce and shows results',
      (tester) async {
    await tester.pumpWidget(buildSearch(repo));
    await tester.pumpAndSettle();

    await typeQuery(tester, 'เสื้อ');
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastSearchProductsQuery, 'เสื้อ');
    expect(find.byType(ProductDetailScreen), findsNothing);
  });

  testWidgets('typing in the Store tab searches after the debounce and shows results',
      (tester) async {
    await tester.pumpWidget(buildSearch(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ร้านค้า'));
    await tester.pumpAndSettle();

    await typeQuery(tester, 'ร้าน');
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastSearchStoresQuery, 'ร้าน');
    expect(find.text('ร้านทดสอบ'), findsOneWidget);
  });

  testWidgets('shows "ไม่พบสินค้า" when the search comes back empty', (tester) async {
    await tester.pumpWidget(buildSearch(emptyRepo));
    await tester.pumpAndSettle();

    await typeQuery(tester, 'ไม่มีจริง');
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบสินค้าสำหรับ "ไม่มีจริง"'), findsOneWidget);
  });

  testWidgets('opening with an initialCategory pre-fills the filter and passes it through',
      (tester) async {
    await tester.pumpWidget(buildSearch(repo, initialCategory: category));
    await tester.pumpAndSettle();

    expect(find.text('ตัวกรอง (1)'), findsOneWidget);

    await typeQuery(tester, 'เสื้อ');
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastSearchProductsCategoryId, 'cat-1');
  });

  testWidgets('selecting a category and price range in the filter sheet applies them',
      (tester) async {
    await tester.pumpWidget(buildSearch(repo));
    await tester.pumpAndSettle();

    await typeQuery(tester, 'เสื้อ');
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithText(OutlinedButton, 'ตัวกรอง'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Fashion'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'ราคาต่ำสุด'), '100');
    await tester.enterText(find.widgetWithText(TextField, 'ราคาสูงสุด'), '500');
    await tester.tap(find.widgetWithText(FilledButton, 'แสดงผลลัพธ์'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastSearchProductsCategoryId, 'cat-1');
    expect(repo.lastSearchProductsMinPrice, 100);
    expect(repo.lastSearchProductsMaxPrice, 500);
    expect(find.text('ตัวกรอง (2)'), findsOneWidget);
  });

  testWidgets('choosing a sort option searches again with the new sort', (tester) async {
    await tester.pumpWidget(buildSearch(repo));
    await tester.pumpAndSettle();

    await typeQuery(tester, 'เสื้อ');
    await tester.pumpAndSettle();
    tester.takeException();
    expect(repo.lastSearchProductsSortBy, ProductSortBy.newest);

    await tester.tap(find.widgetWithText(OutlinedButton, 'เรียงลำดับ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ราคา: ต่ำ → สูง'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.lastSearchProductsSortBy, ProductSortBy.priceLowToHigh);
  });

  testWidgets('tapping a product result opens ProductDetailScreen', (tester) async {
    await tester.pumpWidget(buildSearch(repo));
    await tester.pumpAndSettle();

    await typeQuery(tester, 'เสื้อ');
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byType(ProductGridTile));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a store result opens StoreScreen', (tester) async {
    await tester.pumpWidget(buildSearch(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ร้านค้า'));
    await tester.pumpAndSettle();

    await typeQuery(tester, 'ร้าน');
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ร้านทดสอบ'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(StoreScreen), findsOneWidget);
  });
}
