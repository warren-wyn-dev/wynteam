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
/// SELLER-004 BUG-1 fixtures: stores rendered at real phone viewports.
/// Declared at file level (not inside a test body) because building a
/// [Store] is free, while building a [RecordingZokyRepository] is not --
/// see the `late` repositories in [main].
const _bannerUrl = 'https://example.supabase.co/store-media/store-1/banner.jpg';

/// A standard Thai address, 65 characters -- far below the 300-character
/// ceiling the DB puts on `stores.address`.
const _realAddress =
    '123/45 หมู่ 6 ถนนพหลโยธิน แขวงจตุจักร เขตจตุจักร กรุงเทพมหานคร 10900';

/// ~280 characters: still a value the DB accepts today.
final _longAddress = List.filled(4, _realAddress).join(' ');

Store _phoneStore({
  String? bannerUrl,
  String? address,
  String? contactPhone,
  String? businessHours,
}) =>
    Store(
      id: 'store-1',
      ownerId: 'owner-1',
      name: 'ร้านทดสอบ',
      description: 'ร้านขายเสื้อผ้าแฟชั่น',
      bannerUrl: bannerUrl,
      address: address,
      contactPhone: contactPhone,
      businessHours: businessHours,
      createdAt: DateTime.now(),
      productCount: 1,
    );

final _fullHeaderStore = _phoneStore(
  bannerUrl: _bannerUrl,
  address: _realAddress,
  contactPhone: '0891234567',
  businessHours: 'จันทร์-ศุกร์ 9:00-18:00 น.',
);

typedef _ViewportCase = ({String name, Size size, double textScale, Store store});

/// Every viewport/store combination QA measured the bug on, plus the
/// pre-SELLER-004 baseline (no banner, no info fields) that must keep
/// behaving exactly as it did before.
final _viewportCases = <_ViewportCase>[
  (
    name: '360x640 (small Android) with banner + all 3 info fields',
    size: const Size(360, 640),
    textScale: 1.0,
    store: _fullHeaderStore,
  ),
  (
    name: '375x667 (iPhone SE) with banner + all 3 info fields',
    size: const Size(375, 667),
    textScale: 1.0,
    store: _phoneStore(
      bannerUrl: _bannerUrl,
      address: '123 ถนนสุขุมวิท กรุงเทพฯ',
      contactPhone: '0891234567',
      businessHours: 'จันทร์-ศุกร์ 9:00-18:00 น.',
    ),
  ),
  (
    name: '390x844 (iPhone 14) with banner + info at textScaler 1.3',
    size: const Size(390, 844),
    textScale: 1.3,
    store: _fullHeaderStore,
  ),
  (
    name: '430x932 (iPhone 15 Pro Max) with banner + info at textScaler 1.3',
    size: const Size(430, 932),
    textScale: 1.3,
    store: _fullHeaderStore,
  ),
  (
    name: '360x640 with a 280-character address and no banner at all',
    size: const Size(360, 640),
    textScale: 1.0,
    store: _phoneStore(address: _longAddress),
  ),
  (
    name: '667x375 (landscape) with a banner',
    size: const Size(667, 375),
    textScale: 1.0,
    store: _phoneStore(bannerUrl: _bannerUrl),
  ),
  (
    name: '360x640 with no banner and no info fields (pre-SELLER-004 baseline)',
    size: const Size(360, 640),
    textScale: 1.0,
    store: _phoneStore(),
  ),
];

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

  /// SELLER-004 BUG-1: one repository per [_viewportCases] entry, keyed by
  /// case name. Built in setUp, not at registration time, because
  /// RecordingZokyRepository builds a SupabaseClient, which needs a test
  /// zone (its HttpClient) and starts a periodic auth-refresh Timer.
  late Map<String, RecordingZokyRepository> viewportRepos;
  late RecordingZokyRepository fullHeaderRepo;

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
    viewportRepos = {
      for (final testCase in _viewportCases)
        testCase.name: RecordingZokyRepository(
          store: testCase.store,
          storeProducts: [product],
          storeProductCount: 1,
        ),
    };
    fullHeaderRepo = RecordingZokyRepository(
      store: _fullHeaderStore,
      storeProducts: [product],
      storeProductCount: 1,
    );
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

  // -- SELLER-004 BUG-1: header height vs. the tab content ------------------
  //
  // Regression memory for
  // .wyn/tasks/bugs/SELLER-004-store-screen-header-overflow.md: the banner
  // + "ข้อมูลร้านค้า" section made the (previously short, near-fixed-height)
  // header taller than a real phone screen, which squeezed the tab content
  // to height 0 -- customers saw no products at all.
  //
  // Two things every case below does that the tests above deliberately do
  // NOT do, because both are what let the bug ship green:
  //   1. it renders at a real phone viewport, not flutter_test's 800x600
  //      default (which is wider *and* shorter than any real phone, so it
  //      under-reports banner height and over-reports available height);
  //   2. it collects every FlutterError through FlutterError.onError instead
  //      of tester.takeException(), which only ever yields ONE exception --
  //      the Image.network failure swallowed the overflow behind it.
  // And the assertion is on the *measured height* of the tab content, not
  // on "no exception was thrown": a 0-height TabBarView is the actual user
  // harm, and it can happen with or without an overflow being reported.

  /// Runs [body] with every FlutterError collected into the returned list
  /// instead of being reported. This is what replaces
  /// `tester.takeException()` in the cases below: takeException() yields at
  /// most ONE exception per call, so the pre-existing Image.network
  /// failure was enough to hide the overflow behind it. FlutterError.onError
  /// must be restored before any expect() runs, hence the try/finally.
  Future<List<String>> captureErrors(Future<void> Function() body) async {
    final errors = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details.exceptionAsString());
    try {
      await body();
    } finally {
      FlutterError.onError = previousOnError;
    }
    return errors;
  }

  /// Pumps [StoreScreen] at [size] logical pixels with `devicePixelRatio 1.0`.
  Future<void> pumpAtViewport(
    WidgetTester tester,
    RecordingZokyRepository repo, {
    required Size size,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: StoreScreen(zokyRepository: repo, storeId: 'store-1'),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectNoOverflow(List<String> errors) {
    final overflows = errors.where((e) => e.contains('overflowed')).toList();
    expect(overflows, isEmpty, reason: 'RenderFlex overflow(s): $overflows');
  }

  /// Scrolls the page up until the tab content stops growing. On a tall
  /// header (big banner, long address, large text scale) the tabs start
  /// below the fold, which is fine and normal for a scrolling page -- what
  /// is NOT fine, and what this bug was, is the tab content being stuck at
  /// zero height at every scroll offset there is.
  Future<void> revealTabContent(WidgetTester tester) async {
    double tabContentHeight() {
      final tabView = find.byType(TabBarView);
      return tabView.evaluate().isEmpty ? 0 : tester.getSize(tabView).height;
    }

    var previousHeight = -1.0;
    for (var i = 0; i < 8 && tabContentHeight() != previousHeight; i++) {
      previousHeight = tabContentHeight();
      await tester.drag(find.byType(StoreScreen), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
  }

  /// The tab content must have real height on screen, and the product grid
  /// inside it must actually be laid out -- "the widget exists in the tree"
  /// is not enough, a 0-height TabBarView still "has" its children.
  void expectTabContentVisible(WidgetTester tester, {required Size viewport}) {
    final tabView = find.byType(TabBarView);
    expect(
      tabView,
      findsOneWidget,
      reason: 'the tab content never appeared at any scroll offset',
    );
    expect(
      tester.getSize(tabView).height,
      greaterThan(0),
      reason: 'TabBarView was squeezed to zero height -- the customer sees no '
          'products at all.',
    );
    // Not just "> 0": once the header is out of the way the tab content
    // owns essentially the whole screen (viewport minus the AppBar and the
    // pinned TabBar), so anything under half the screen means it is being
    // squeezed by the header again.
    expect(
      tester.getSize(tabView).height,
      greaterThanOrEqualTo(viewport.height / 2),
      reason: 'TabBarView only got ${tester.getSize(tabView).height} px of a '
          '${viewport.height} px tall screen.',
    );
    expect(find.byType(ProductGridTile), findsOneWidget);
    expect(tester.getSize(find.byType(ProductGridTile)).height, greaterThan(0));
  }

  for (final testCase in _viewportCases) {
    testWidgets(
        'tab content is reachable at full height and never overflows -- '
        '${testCase.name}', (tester) async {
      final errors = await captureErrors(() async {
        await pumpAtViewport(
          tester,
          viewportRepos[testCase.name]!,
          size: testCase.size,
          textScale: testCase.textScale,
        );
        await revealTabContent(tester);
      });

      expectNoOverflow(errors);
      expectTabContentVisible(tester, viewport: testCase.size);
    });
  }

  testWidgets(
      'a typical phone (390x844) shows the product grid without scrolling at all, '
      'banner and store info included', (tester) async {
    final errors = await captureErrors(
      () => pumpAtViewport(tester, fullHeaderRepo, size: const Size(390, 844)),
    );

    expectNoOverflow(errors);
    // No drag: the banner, the store info card AND the products are all on
    // the first screen.
    expect(find.byType(AspectRatio), findsWidgets);
    expect(find.text(_realAddress), findsOneWidget);
    expect(find.byType(TabBarView), findsOneWidget);
    expect(tester.getSize(find.byType(TabBarView)).height, greaterThan(0));
    expect(find.byType(ProductGridTile), findsOneWidget);
  });

  testWidgets(
      'products are still tappable on a small phone with a full header (360x640)',
      (tester) async {
    final errors = await captureErrors(() async {
      await pumpAtViewport(tester, fullHeaderRepo, size: const Size(360, 640));
      await revealTabContent(tester);
      await tester.tap(find.byType(ProductGridTile));
      await tester.pumpAndSettle();
    });

    expectNoOverflow(errors);
    expect(find.byType(ProductDetailScreen), findsOneWidget);
  });

  testWidgets(
      'both tabs are reachable on a small phone with a full header (360x640)',
      (tester) async {
    final errors = await captureErrors(() async {
      await pumpAtViewport(tester, fullHeaderRepo, size: const Size(360, 640));
      await revealTabContent(tester);
      await tester.tap(find.text('รีวิว'));
      await tester.pumpAndSettle();
    });

    expectNoOverflow(errors);
    expect(find.text('ยังไม่มีรีวิว'), findsOneWidget);
  });

  testWidgets(
      'the banner and store info stay reachable after scrolling back up (360x640)',
      (tester) async {
    final errors = await captureErrors(() async {
      await pumpAtViewport(tester, fullHeaderRepo, size: const Size(360, 640));
      await revealTabContent(tester);
      await tester.drag(find.byType(StoreScreen), const Offset(0, 1200));
      await tester.pumpAndSettle();
    });

    expectNoOverflow(errors);
    expect(find.text('ร้านทดสอบ'), findsOneWidget);
    expect(find.text(_realAddress), findsOneWidget);
    expect(find.text('0891234567'), findsOneWidget);
  });
}
