import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/data/review.dart';
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

  // SELLER-004: a store with a banner and full address/contact/hours,
  // to prove the new banner + "ข้อมูลร้านค้า" section render correctly --
  // `store` above (no banner/address/contact/hours) stays untouched so
  // every pre-existing test above keeps proving the regression-safe
  // "no new UI at all for a store with none of these fields" case.
  final storeWithBannerAndInfo = Store(
    id: 'store-2',
    ownerId: 'owner-2',
    name: 'ร้านครบเครื่อง',
    description: 'ร้านที่มีข้อมูลครบทุกฟิลด์',
    bannerUrl: 'https://example.supabase.co/store-media/store-2/banner.jpg',
    address: '123 ถนนสุขุมวิท กรุงเทพฯ',
    contactPhone: '0891234567',
    businessHours: 'จันทร์-ศุกร์ 9:00-18:00 น.',
    createdAt: DateTime.now(),
    productCount: 0,
  );

  // Only 1 of the 3 new fields set, to prove the section renders that
  // field alone (not empty rows for the other 2).
  final partialStore = Store(
    id: 'store-3',
    ownerId: 'owner-3',
    name: 'ร้านมีที่อยู่อย่างเดียว',
    address: 'ที่อยู่เท่านั้น',
    createdAt: DateTime.now(),
    productCount: 0,
  );

  late RecordingZokyRepository populatedRepo;
  late RecordingZokyRepository emptyRepo;
  late RecordingZokyRepository notFoundRepo;
  late RecordingZokyRepository ratedRepo;
  late RecordingZokyRepository reviewsTabRepo;
  late RecordingZokyRepository bannerAndInfoRepo;
  late RecordingZokyRepository partialRepo;

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
    ratedRepo = RecordingZokyRepository(
      store: store,
      storeProducts: [product],
      storeProductCount: 1,
      storeRating: (4.5, 3),
    );
    reviewsTabRepo = RecordingZokyRepository(
      store: store,
      storeProducts: [product],
      storeProductCount: 1,
      storeRating: (5.0, 1),
      storeReviews: [
        Review(
          id: 'r1',
          orderItemId: 'oi1',
          productId: product.id,
          userId: 'u1',
          authorUsername: 'somchai',
          rating: 5,
          textContent: 'ประทับใจมาก',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          productName: 'เสื้อยืด',
        ),
      ],
    );
    bannerAndInfoRepo = RecordingZokyRepository(store: storeWithBannerAndInfo);
    partialRepo = RecordingZokyRepository(store: partialStore);
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

  testWidgets('header shows the store\'s aggregate rating when reviews exist (ZOKY-004)',
      (tester) async {
    await tester.pumpWidget(buildStoreScreen(ratedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.textContaining('4.5'), findsOneWidget);
  });

  testWidgets('Reviews tab shows every product\'s reviews with the product name attached '
      '(ZOKY-004)', (tester) async {
    await tester.pumpWidget(buildStoreScreen(reviewsTabRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('รีวิว'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ประทับใจมาก'), findsOneWidget);
    // ReviewTile shows the author's name and the product name attached
    // -- 'เสื้อยืด' appears both here and (offscreen) on the Products
    // tab's grid tile, but only this tab is currently visible/attached.
    expect(find.text('เสื้อยืด'), findsOneWidget);
  });

  testWidgets('AppBar shows Share and Copy Link buttons (WYN-010)', (tester) async {
    await tester.pumpWidget(buildStoreScreen(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    // Not tapped -- same as every existing Share/Copy Link button
    // elsewhere in the app (Drop/Pop/Club post): share_plus and
    // Clipboard.setData both go through platform channels this sandbox
    // never mocks, so tapping either hangs the await forever with no
    // exception raised at all. Presence is what every prior test of
    // this button checks; see .wyn/learning/PATTERNS.md.
    expect(find.widgetWithIcon(IconButton, Icons.share_outlined), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.link), findsOneWidget);
  });

  // -- SELLER-004: banner + "ข้อมูลร้านค้า" section ------------------------

  testWidgets('does not show a banner image when the store has none (regression)',
      (tester) async {
    await tester.pumpWidget(buildStoreScreen(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    // ProductGridTile also uses AspectRatio (1:1, for the product photo)
    // so this can't just check "no AspectRatio at all" -- it must check
    // specifically for the banner's 16:9 one.
    expect(
      find.byWidgetPredicate((w) => w is AspectRatio && w.aspectRatio == 16 / 9),
      findsNothing,
    );
  });

  testWidgets(
      'does not show the "ข้อมูลร้านค้า" section when address/contact/hours '
      'are all null (regression)', (tester) async {
    await tester.pumpWidget(buildStoreScreen(populatedRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    expect(find.byIcon(Icons.call_outlined), findsNothing);
    expect(find.byIcon(Icons.access_time_outlined), findsNothing);
  });

  testWidgets('shows a 16:9 banner image when store.bannerUrl is set',
      (tester) async {
    await tester.pumpWidget(buildStoreScreen(bannerAndInfoRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspectRatio.aspectRatio, 16 / 9);
    expect(find.byType(Image), findsWidgets);
  });

  testWidgets(
      'shows the "ข้อมูลร้านค้า" section with address, contact, and hours '
      'when all 3 are set', (tester) async {
    await tester.pumpWidget(buildStoreScreen(bannerAndInfoRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('123 ถนนสุขุมวิท กรุงเทพฯ'), findsOneWidget);
    expect(find.text('0891234567'), findsOneWidget);
    expect(find.text('จันทร์-ศุกร์ 9:00-18:00 น.'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(Icons.call_outlined), findsOneWidget);
    expect(find.byIcon(Icons.access_time_outlined), findsOneWidget);
  });

  testWidgets(
      'shows the "ข้อมูลร้านค้า" section with only the fields that are set '
      'when only some are non-null', (tester) async {
    await tester.pumpWidget(buildStoreScreen(partialRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ที่อยู่เท่านั้น'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    expect(find.byIcon(Icons.call_outlined), findsNothing);
    expect(find.byIcon(Icons.access_time_outlined), findsNothing);
  });
}
