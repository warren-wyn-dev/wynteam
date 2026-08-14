import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/data/store.dart';
import 'package:wyn/features/zoky/presentation/product_detail_screen.dart';
import 'package:wyn/features/zoky/presentation/store_screen.dart';
import 'package:wyn/features/zoky/presentation/widgets/product_grid_tile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Regression tests for StoreScreen (ZOKY-001), per
/// .wyn/docs/design/zoky-001-marketplace-foundation.md, Screen 3. Chat
/// Seller is omitted entirely per the Design spec -- confirmed absent
/// below, not just untested.
void main() {
  final store = Store(
    id: 'store-1',
    ownerId: 'owner-1',
    name: 'ร้านทดสอบ',
    description: 'ร้านขายเสื้อผ้าแฟชั่น',
    createdAt: DateTime.now(),
    productCount: 1,
  );

  final product = Product(
    id: 'p1',
    storeId: 'store-1',
    storeName: 'ร้านทดสอบ',
    name: 'เสื้อยืด',
    price: 199,
    stock: 5,
    imageUrls: const ['https://example.supabase.co/products/p1.jpg'],
    createdAt: DateTime.now(),
  );

  late RecordingZokyRepository populatedRepo;
  late RecordingZokyRepository emptyRepo;
  late RecordingZokyRepository notFoundRepo;

  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  setUp(() {
    populatedRepo = RecordingZokyRepository(
      store: store,
      storeProducts: [product],
      storeProductCount: 1,
    );
    emptyRepo = RecordingZokyRepository(store: store, storeProductCount: 0);
    notFoundRepo = RecordingZokyRepository();
  });

  Widget buildStoreScreen(RecordingZokyRepository repo) {
    return MaterialApp(
      home: StoreScreen(zokyRepository: repo, storeId: 'store-1'),
    );
  }

  testWidgets('shows store name, description, and 0 followers placeholder',
      (tester) async {
    await tester.pumpWidget(buildStoreScreen(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ร้านทดสอบ'), findsOneWidget);
    expect(find.text('ร้านขายเสื้อผ้าแฟชั่น'), findsOneWidget);
    expect(find.textContaining('0 ผู้ติดตาม'), findsOneWidget);
  });

  testWidgets('shows "ไม่พบร้านค้านี้" when the store does not exist', (tester) async {
    await tester.pumpWidget(buildStoreScreen(notFoundRepo));
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบร้านค้านี้'), findsOneWidget);
  });

  testWidgets('tapping "ติดตามร้าน" shows a coming-soon SnackBar', (tester) async {
    await tester.pumpWidget(buildStoreScreen(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ติดตามร้าน'));
    await tester.pump();

    expect(find.text('ฟีเจอร์นี้จะมาเร็ว ๆ นี้'), findsOneWidget);
  });

  testWidgets('never shows a Chat Seller button', (tester) async {
    await tester.pumpWidget(buildStoreScreen(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.textContaining('แชท'), findsNothing);
  });

  testWidgets('shows empty state on Products tab when the store has no products',
      (tester) async {
    await tester.pumpWidget(buildStoreScreen(emptyRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ร้านนี้ยังไม่มีสินค้า'), findsOneWidget);
  });

  testWidgets('tapping a product in the Products tab opens ProductDetailScreen',
      (tester) async {
    await tester.pumpWidget(buildStoreScreen(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    // ProductGridTile shows only a price badge visually (the product
    // name is Semantics-only) -- tap the tile itself, not its name text.
    await tester.tap(find.byType(ProductGridTile));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets('switching to the Reviews tab shows "ยังไม่มีรีวิว"', (tester) async {
    await tester.pumpWidget(buildStoreScreen(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('รีวิว'));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีรีวิว'), findsOneWidget);
  });
}
