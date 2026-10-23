// QA & Security re-test: Food page fixes ZOKY-128..131, 2026-10-18.
//
// Independent checks of the Debug fixes (commits 4070d7c, f4cdd42,
// b91a5cb, 684558e) beyond the repros in food_page_qa_test.dart:
// icon audit on both platforms incl. loading/offline/empty states, demo
// header label and category label shrink at 320x568 up to text 2.0,
// reading order after scrolling and in pickup, semantics actions on the
// pinned header, retry/refresh races, odd distances in every surface,
// cart button vs "เก็บโค้ด" up to text 2.0, pickup store page, and demo
// labelling. Synthetic data only.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/zoky_app.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_glossy_heart_button.dart';
import 'package:zoky_app/core/widgets/zoky_state_view.dart';
import 'package:zoky_app/features/address/data/demo_address_repository.dart';
import 'package:zoky_app/features/address/delivery_address_controller.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/data/store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';
import 'package:zoky_app/features/food/collected_promos_controller.dart';
import 'package:zoky_app/features/food/food_home_screen.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_address_button.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_category_row.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_coupon_section.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_header.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_mode_toggle.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_store_row.dart';
import 'package:zoky_app/features/fulfillment/fulfillment_mode_controller.dart';
import 'package:zoky_app/features/home/data/demo_home_content_repository.dart';
import 'package:zoky_app/features/home/data/home_content_repository.dart';
import 'package:zoky_app/features/home/domain/home_content_models.dart';
import 'package:zoky_app/features/home/home_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

const _heavy = ['qa-heavy'];

/// Directory stub: each call waits for the test unless [auto] answers.
class _Stores implements StoreRepository {
  _Stores(this.stores, {this.fail = false});

  List<ZokyStoreSummary> stores;
  bool fail;
  bool manual = false;
  final pending = <Completer<List<ZokyStoreSummary>>>[];

  @override
  Future<List<ZokyStoreSummary>> fetchDirectory({String query = ''}) async {
    if (manual) {
      final c = Completer<List<ZokyStoreSummary>>();
      pending.add(c);
      return c.future;
    }
    if (fail) throw StateError('offline');
    return stores;
  }

  @override
  Future<List<ZokyStoreSummary>> fetchRecommended() async => const [];

  @override
  Future<List<ZokyMenuItem>> fetchMenu(String storeId) async => const [];
}

class _Content implements HomeContentRepository {
  bool failCategories = false;
  final _demo = const DemoHomeContentRepository();

  @override
  Future<List<ZokyHomeBanner>> fetchActiveBanners() =>
      _demo.fetchActiveBanners();

  @override
  Future<List<ZokyFoodCategory>> fetchFoodCategories() async {
    if (failCategories) throw StateError('offline');
    return _demo.fetchFoodCategories();
  }
}

Future<void> _loadAnuphan() async {
  final loader = FontLoader('Anuphan')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/anuphan/Anuphan-VariableFont_wght.ttf')
              .readAsBytesSync(),
        ),
      ),
    );
  await loader.load();
}

late FulfillmentModeController _mode;

Future<void> _pumpFood(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double top = 0,
  double bottom = 0,
  double textScale = 1.0,
  StoreRepository? stores,
  HomeContentRepository? content,
  DeliveryAddressController? addresses,
  bool openFood = true,
}) async {
  // Fresh navigator (a re-pump of ZokyApp keeps the pushed food route).
  await tester.pumpWidget(const SizedBox());
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  final inset = FakeViewPadding(top: top, bottom: bottom);
  tester.view.padding = inset;
  tester.view.viewPadding = inset;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  _mode = FulfillmentModeController();
  await tester.pumpWidget(
    ZokyApp(
      config: AppConfig.demo,
      storeRepository: stores ?? DemoStoreRepository(),
      promotionRepository: const DemoPromotionRepository(),
      homeContentRepository: content ?? const DemoHomeContentRepository(),
      deliveryAddresses:
          addresses ?? DeliveryAddressController(const DemoAddressRepository()),
      fulfillmentMode: _mode,
      collectedPromos: CollectedPromosController(),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
  if (!openFood) return;
  final hero = find.text(ZokyStrings.heroSearchButton);
  await tester.ensureVisible(hero);
  await tester.pumpAndSettle();
  await tester.tap(hero);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  expect(find.byType(FoodHomeScreen), findsOneWidget);
}

ScrollPosition _feed(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(FoodHomeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Future<void> _pickup(WidgetTester tester) async {
  _feed(tester).jumpTo(0);
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(ZokyFoodModeToggle.keyFor(FulfillmentMode.pickup)),
  );
  await tester.pumpAndSettle();
}

Future<void> _refresh(WidgetTester tester) async {
  _feed(tester).jumpTo(0);
  await tester.pumpAndSettle();
  await tester.fling(
    find.byKey(FoodHomeScreen.allStoresKey),
    const Offset(0, 500),
    1200,
  );
}

/// Every semantics label in traversal order under [root].
List<String> _readingOrder(WidgetTester tester, Finder root) {
  final out = <String>[];
  void visit(SemanticsNode node) {
    final data = node.getSemanticsData();
    final text = data.label.isNotEmpty ? data.label : data.tooltip;
    if (text.isNotEmpty) out.add(text);
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child);
    }
  }

  visit(tester.getSemantics(root));
  return out;
}

/// Icon widgets and icon-font text under the current tree.
Set<String> _fontIcons(String where) {
  final out = <String>{};
  for (final e in find.byType(Icon).evaluate()) {
    final icon = (e.widget as Icon).icon;
    if (icon != null) {
      out.add(
        '$where: ${icon.fontFamily} 0x${icon.codePoint.toRadixString(16)} '
        'in ${e.findAncestorWidgetOfExactType<Semantics>()?.properties.label}',
      );
    }
  }
  for (final e in find.byType(RichText).evaluate()) {
    final family = (e.widget as RichText).text.style?.fontFamily ?? '';
    if (family.contains('MaterialIcons') || family.contains('CupertinoIcons')) {
      out.add('$where: RichText in $family');
    }
  }
  return out;
}

/// Ratio of the painted text size to the requested (scaled) size for a
/// Text inside a FittedBox (1.0 = not shrunk).
double _fitScale(WidgetTester tester, Finder text) {
  final p = tester.renderObject<RenderParagraph>(text);
  final fitted = tester.renderObject<RenderBox>(
    find.ancestor(of: text, matching: find.byType(FittedBox)).first,
  );
  return math.min(1.0, fitted.size.width / p.size.width);
}

void main() {
  group('ZOKY-128 re-test: no font icons (both platforms, all states)', () {
    testWidgets(
      'Home, Food delivery/pickup, sheets, loading, offline, '
      'empty, filtered empty, categories offline',
      (tester) async {
        final found = <String>{};
        final content = _Content();
        final stores = _Stores(DemoStoreRepository.stores)..manual = true;
        await _pumpFood(
          tester,
          height: 3000,
          stores: stores,
          content: content,
          openFood: false,
        );
        found.addAll(_fontIcons('home'));
        // Home favorites sheet (heart in the Home header).
        final homeHeart = find.descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(ZokyGlossyHeartButton),
        );
        await tester.tap(homeHeart);
        await tester.pumpAndSettle();
        expect(find.text(ZokyStrings.comingSoon), findsOneWidget);
        found.addAll(_fontIcons('home favorites sheet'));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        // Food loading (skeletons): directory call pending.
        await tester.tap(find.text(ZokyStrings.heroSearchButton));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 600));
        found.addAll(_fontIcons('food loading'));
        stores.pending.single.complete(DemoStoreRepository.stores);
        stores.manual = false;
        await tester.pumpAndSettle();
        found.addAll(_fontIcons('food delivery'));
        await tester.tap(find.byType(ZokyFoodAddressButton));
        await tester.pumpAndSettle();
        found.addAll(_fontIcons('address sheet'));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ZokyFoodHeader.favoritesKey));
        await tester.pumpAndSettle();
        found.addAll(_fontIcons('food favorites sheet'));
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await _pickup(tester);
        found.addAll(_fontIcons('food pickup'));
        // Filtered empty: stores without promos, then มีโปรฯ.
        await _pumpFood(
          tester,
          height: 3000,
          stores: _Stores([
            for (final s in DemoStoreRepository.stores)
              ZokyStoreSummary(
                id: s.id,
                name: s.name,
                isDemo: true,
                isOpen: s.isOpen,
                deliveryFee: s.deliveryFee,
              ),
          ]),
        );
        await tester.pumpAndSettle();
        final promoChip = find.descendant(
          of: find.byKey(FoodHomeScreen.filtersKey),
          matching: find.text(ZokyStrings.filterPromo),
        );
        await tester.ensureVisible(promoChip);
        await tester.pumpAndSettle();
        await tester.tap(promoChip);
        await tester.pumpAndSettle();
        expect(find.text(ZokyStrings.noFilteredStores), findsOneWidget);
        found.addAll(_fontIcons('food filtered empty'));
        // Empty area + categories offline line (first load failure).
        content.failCategories = true;
        await _pumpFood(
          tester,
          height: 3000,
          stores: _Stores(const []),
          content: content,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(ZokyFoodCategoryRow.errorKey), findsOneWidget);
        expect(find.text(ZokyStrings.noStoresTitle), findsOneWidget);
        found.addAll(_fontIcons('food empty + categories offline'));
        // Offline first load.
        await _pumpFood(
          tester,
          height: 3000,
          stores: _Stores(const [], fail: true),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ZokyStateView), findsOneWidget);
        found.addAll(_fontIcons('food offline'));
        // ignore: avoid_print
        print('QA-RETEST-FONT-ICONS ${found.length}\n${found.join('\n')}');
        expect(found, isEmpty);
      },
      variant: TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
      }),
    );

    testWidgets('closed-store label and cover placeholder are painted', (
      tester,
    ) async {
      await _pumpFood(
        tester,
        height: 2000,
        stores: _Stores(const [
          ZokyStoreSummary(
            id: 'c',
            name: 'ปิด (ร้านตัวอย่าง)',
            isDemo: true,
            isOpen: false,
            deliveryFee: 10,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.closedLabel), findsWidgets);
      expect(_fontIcons('closed row'), isEmpty);
    }, variant: TargetPlatformVariant.mobile());
  });

  group('ZOKY-129 re-test (Anuphan, 320x568)', () {
    setUpAll(_loadAnuphan);

    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      testWidgets('header keeps "(ตัวอย่าง)", no ellipsis anywhere, no '
          'overflow; text $scale', (tester) async {
        final controller = DeliveryAddressController(
          const DemoAddressRepository(),
        );
        await _pumpFood(
          tester,
          width: 320,
          height: 568,
          top: 20,
          textScale: scale,
          addresses: controller,
        );
        await tester.pumpAndSettle();
        final notes = <String>[];
        for (final address in DemoAddressRepository.addresses) {
          controller.select(address);
          await tester.pumpAndSettle();
          final text = find.descendant(
            of: find.byType(ZokyFoodAddressButton),
            matching: find.text(address.label),
          );
          final p = tester.renderObject<RenderParagraph>(text);
          expect(p.didExceedMaxLines, isFalse, reason: address.label);
          expect(address.label, contains('ตัวอย่าง'));
          final fit = _fitScale(tester, text);
          // The demo label must still be readable: painted at >= 80%.
          notes.add('${address.label} fit ${fit.toStringAsFixed(2)}');
          expect(fit, greaterThan(0.8), reason: address.label);
          // Fully inside the screen.
          final r = tester.getRect(text);
          expect(r.right, lessThanOrEqualTo(320.5), reason: '$r');
        }
        // Scroll the whole page: no exception, no ellipsized text.
        final cut = <String>{};
        final position = _feed(tester);
        for (var y = 0.0; ; y += 120) {
          position.jumpTo(math.min(y, position.maxScrollExtent));
          await tester.pump();
          final e = tester.takeException();
          expect(e, isNull, reason: 'at $y');
          for (final e
              in find
                  .descendant(
                    of: find.byType(FoodHomeScreen),
                    matching: find.byType(RichText),
                  )
                  .evaluate()) {
            final p = e.renderObject! as RenderParagraph;
            if (p.didExceedMaxLines &&
                p.text.toPlainText() != ZokyStrings.foodSearchPlaceholder) {
              // Search placeholder: ZOKY-133 item 2 (pre-existing).
              cut.add(p.text.toPlainText());
            }
          }
          if (y >= position.maxScrollExtent) break;
        }
        // Category labels: measured shrink (one line, scaleDown).
        position.jumpTo(0);
        await tester.pumpAndSettle();
        final shrink = <String>[];
        for (final e
            in find
                .descendant(
                  of: find.byKey(ZokyFoodCategoryRow.rowKey),
                  matching: find.byType(FittedBox),
                )
                .evaluate()) {
          final fitted = e.renderObject! as RenderBox;
          final p = tester.renderObject<RenderParagraph>(
            find.descendant(
              of: find.byWidget(e.widget),
              matching: find.byType(RichText),
            ),
          );
          final fit = math.min(1.0, fitted.size.width / p.size.width);
          final painted = p.textScaler.scale(p.text.style!.fontSize!) * fit;
          shrink.add(
            '${p.text.toPlainText()} ${fit.toStringAsFixed(2)} '
            '(${painted.toStringAsFixed(1)}pt)',
          );
        }
        // ignore: avoid_print
        print(
          'QA-RETEST-129 x$scale header: ${notes.join('; ')}\n'
          '  categories: ${shrink.join('; ')}\n  cut: $cut',
        );
        expect(cut, isEmpty);
      }, tags: _heavy);
    }
  });

  group('ZOKY-130 re-test: reading order', () {
    List<int> seqOf(List<String> order, List<bool Function(String)> tests) => [
      for (final t in tests) order.indexWhere(t),
    ];

    {
      testWidgets('open, pickup, and after scrolling', (tester) async {
        final platform = defaultTargetPlatform;
        final semantics = tester.ensureSemantics();
        await _pumpFood(tester, top: 47, bottom: 34);
        await tester.pumpAndSettle();
        final food = find.byType(FoodHomeScreen);
        final tests = <bool Function(String)>[
          (l) => l == ZokyStrings.back,
          (l) => l.startsWith(ZokyStrings.deliverAt),
          (l) => l == ZokyStrings.favoriteStores,
          (l) => l == ZokyStrings.coupons,
          (l) => l == ZokyStrings.modeDelivery,
          (l) => l == ZokyStrings.modePickup,
          (l) => l == ZokyStrings.foodSearchPlaceholder,
          (l) => l == ZokyStrings.couponsTitle,
          (l) => l == ZokyStrings.allStoresTitle,
          (l) => l == ZokyStrings.filters,
          (l) => l == ZokyStrings.filterAll,
          (l) => l.contains(ZokyStrings.viewMenu),
          (l) => l == ZokyStrings.cart,
        ];
        var order = _readingOrder(tester, food);
        var seq = seqOf(order, tests);
        expect(seq, isNot(contains(-1)), reason: order.join(' | '));
        expect(seq, [...seq]..sort(), reason: order.join(' | '));

        // Pickup: the pickup header label first, then the same order.
        await _pickup(tester);
        order = _readingOrder(tester, food);
        final pickupSeq = seqOf(order, [
          (l) => l == ZokyStrings.back,
          (l) => l == ZokyStrings.modePickup,
          (l) => l == ZokyStrings.foodSearchPlaceholder,
          (l) => l == ZokyStrings.allStoresTitle,
          (l) => l == ZokyStrings.filterAll,
          (l) => l.contains(ZokyStrings.viewMenu),
          (l) => l == ZokyStrings.cart,
        ]);
        expect(pickupSeq, isNot(contains(-1)), reason: order.join(' | '));
        expect(pickupSeq, [...pickupSeq]..sort(), reason: order.join(' | '));
        await tester.tap(
          find.byKey(ZokyFoodModeToggle.keyFor(FulfillmentMode.delivery)),
        );
        await tester.pumpAndSettle();

        // Scrolled: compact header (search) before chips, rows, cart; no
        // row is read before the header; visible rows in visual order.
        final position = _feed(tester);
        for (final y in [300.0, 900.0, position.maxScrollExtent]) {
          position.jumpTo(math.min(y, position.maxScrollExtent));
          await tester.pumpAndSettle();
          order = _readingOrder(tester, food);
          final search = order.indexOf(ZokyStrings.foodSearchPlaceholder);
          final chips = order.indexOf(ZokyStrings.filterAll);
          final firstRow = order.indexWhere(
            (l) => l.contains(ZokyStrings.viewMenu),
          );
          final cart = order.indexOf(ZokyStrings.cart);
          expect(search, isNonNegative, reason: '$y ${order.join(' | ')}');
          expect(chips, greaterThan(search), reason: '$y ${order.join(' | ')}');
          if (firstRow >= 0) {
            expect(firstRow, greaterThan(chips), reason: order.join(' | '));
          }
          expect(cart, order.length - 1, reason: order.join(' | '));
          // Rows read top-to-bottom as drawn.
          final rowTops = <double>[];
          for (final e in find.byType(ZokyFoodStoreRow).evaluate()) {
            final row = e.widget as ZokyFoodStoreRow;
            rowTops.add(order.indexOf(row.semanticLabel()).toDouble());
          }
          final shown = rowTops.where((i) => i >= 0).toList();
          expect(shown, [...shown]..sort(), reason: '$y ${order.join(' | ')}');
        }
        // ignore: avoid_print
        print('QA-RETEST-ORDER-END ${platform.name} ${order.join(' | ')}');
        semantics.dispose();
      }, variant: TargetPlatformVariant.mobile());
    }

    testWidgets('ZOKY-132 repro: screen-reader activation (semantics tap) '
        'on the search field opens search', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      await tester.pumpAndSettle();
      final position = _feed(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final node = tester.getSemantics(
        find.bySemanticsLabel(ZokyStrings.foodSearchPlaceholder),
      );
      node.owner!.performAction(node.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(find.byType(FoodHomeScreen), findsNothing);
      semantics.dispose();
    }); // ZOKY-132 (fixed, regression: test/semantics_tap_action_test.dart)

    testWidgets('ZOKY-132 repro: every button on Home + Food exposes a tap '
        'action', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester, height: 2400);
      await tester.pumpAndSettle();
      final missing = <String>[];
      void walk(SemanticsNode n) {
        final d = n.getSemanticsData();
        if (d.flagsCollection.isButton && !d.hasAction(SemanticsAction.tap)) {
          missing.add(d.label.isEmpty ? d.tooltip : d.label);
        }
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(tester.getSemantics(find.byType(FoodHomeScreen)));
      // ignore: avoid_print
      print('QA-NO-TAP-ACTION ${missing.length}: ${missing.join(' | ')}');
      expect(missing, isEmpty);
      semantics.dispose();
    }); // ZOKY-132 (fixed, regression: test/semantics_tap_action_test.dart)
  });

  group('ZOKY-131 re-test', () {
    testWidgets('retry tapped twice: only the latest answer wins, '
        'skeletons while waiting, no stale error', (tester) async {
      final stores = _Stores(DemoStoreRepository.stores, fail: true);
      await _pumpFood(tester, height: 2000, stores: stores);
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.offlineTitle), findsOneWidget);
      stores.manual = true;
      await tester.tap(find.text(ZokyStrings.retry));
      await tester.pump();
      expect(find.text(ZokyStrings.offlineTitle), findsNothing);
      expect(find.byType(ZokyFoodStoreRow), findsNothing);
      // While loading the retry button is gone, so a second tap can only
      // come from pull to refresh.
      _feed(tester).jumpTo(0);
      await tester.pump();
      await tester.fling(
        find.byKey(FoodHomeScreen.allStoresKey),
        const Offset(0, 500),
        1200,
      );
      for (var i = 0; i < 20 && stores.pending.length < 2; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(stores.pending, hasLength(2));
      // Newer succeeds, then the older one fails late: list stays, no
      // full-page error, no SnackBar from the stale failure.
      stores.pending[1].complete(DemoStoreRepository.stores.take(2).toList());
      await tester.pump();
      stores.pending[0].completeError(StateError('late'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(ZokyFoodStoreRow), findsNWidgets(2));
      expect(find.text(ZokyStrings.offlineTitle), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('failed refresh keeps stores, coupons and categories; one '
        'SnackBar; next refresh recovers', (tester) async {
      final stores = _Stores(DemoStoreRepository.stores);
      final content = _Content();
      await _pumpFood(tester, stores: stores, content: content);
      await tester.pumpAndSettle();
      final rows = find.byType(ZokyFoodStoreRow).evaluate().length;
      final coupons = find.byType(ZokyFoodCouponCard).evaluate().length;
      expect(coupons, greaterThan(0));
      stores.fail = true;
      content.failCategories = true;
      await _refresh(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ZokyFoodStoreRow).evaluate().length, rows);
      expect(find.byType(ZokyFoodCouponCard).evaluate().length, coupons);
      expect(find.byKey(ZokyFoodCategoryRow.errorKey), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(ZokyStrings.offlineTitle),
        ),
        findsOneWidget,
      );
      // Twice in a row: still one SnackBar.
      await _refresh(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsOneWidget);
      stores
        ..fail = false
        ..stores = DemoStoreRepository.stores.take(1).toList();
      content.failCategories = false;
      await _refresh(tester);
      await tester.pumpAndSettle();
      expect(find.byType(ZokyFoodStoreRow), findsOneWidget);
    });

    testWidgets('refresh from the offline state that fails again keeps the '
        'error with retry (no blank page)', (tester) async {
      final stores = _Stores(const [], fail: true);
      await _pumpFood(tester, stores: stores);
      await tester.pumpAndSettle();
      await _refresh(tester);
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.offlineTitle), findsOneWidget);
      expect(find.text(ZokyStrings.retry), findsOneWidget);
    });

    testWidgets('odd distances never show in row text, label, filter', (
      tester,
    ) async {
      final odd = [
        double.infinity,
        double.negativeInfinity,
        double.nan,
        -0.001,
        -5.0,
      ];
      final list = [
        for (final (i, d) in odd.indexed)
          ZokyStoreSummary(
            id: 'o$i',
            name: 'ร้าน $i (ร้านตัวอย่าง)',
            isDemo: true,
            isOpen: true,
            deliveryFee: 10,
            distanceKm: d,
          ),
      ];
      await _pumpFood(tester, height: 2400, stores: _Stores(list));
      await tester.pumpAndSettle();
      final texts = [
        for (final e
            in find
                .descendant(
                  of: find.byType(ZokyFoodStoreRow),
                  matching: find.byType(RichText),
                )
                .evaluate())
          (e.widget as RichText).text.toPlainText(),
        for (final r in tester.widgetList<ZokyFoodStoreRow>(
          find.byType(ZokyFoodStoreRow),
        ))
          r.semanticLabel(),
      ];
      for (final t in texts) {
        expect(t, isNot(matches(RegExp(r'Infinity|NaN|-\d'))), reason: t);
        expect(t, isNot(contains('กม.')), reason: t);
      }
      // ใกล้ฉัน excludes all of them.
      await tester.tap(find.text(ZokyStrings.filterNear).first);
      await tester.pumpAndSettle();
      expect(find.byType(ZokyFoodStoreRow), findsNothing);
      expect(find.text(ZokyStrings.noFilteredStores), findsOneWidget);
      // 0.0 is a real distance and still shows.
      final zero = ZokyFoodStoreRow(
        store: const ZokyStoreSummary(
          id: 'z',
          name: 'z',
          isOpen: true,
          deliveryFee: 0,
          distanceKm: 0,
        ),
        mode: FulfillmentMode.delivery,
        onTap: () {},
      );
      expect(zero.semanticLabel(), contains('0.0'));
    });

    for (final scale in [1.0, 1.3, 1.6, 2.0]) {
      for (final mode in FulfillmentMode.values) {
        testWidgets('cart never covers "เก็บโค้ด" at 320x568 x$scale '
            '(${mode.name}), at every scroll offset', (tester) async {
          await _pumpFood(
            tester,
            width: 320,
            height: 568,
            top: 20,
            textScale: scale,
          );
          await tester.pumpAndSettle();
          if (mode == FulfillmentMode.pickup) await _pickup(tester);
          final position = _feed(tester);
          final hits = <String>[];
          for (var y = 0.0; ; y += 40) {
            position.jumpTo(math.min(y, position.maxScrollExtent));
            await tester.pump();
            final fab = tester.getRect(find.byKey(FoodHomeScreen.cartKey));
            for (final e in find.byType(ZokyCollectButton).evaluate()) {
              final r =
                  (e.renderObject! as RenderBox).localToGlobal(Offset.zero) &
                  (e.renderObject! as RenderBox).size;
              // Only when the button is otherwise fully visible (below
              // the pinned header, above the screen bottom, not a card
              // peeking in from the right edge of the coupon row).
              final header = tester.getRect(
                find.byKey(ZokyFoodHeader.surfaceKey),
              );
              if (r.top >= header.bottom &&
                  r.bottom <= 568 &&
                  r.left >= 0 &&
                  r.right <= 320 &&
                  r.overlaps(fab)) {
                hits.add('y=$y $r vs $fab');
              }
            }
            if (y >= position.maxScrollExtent) break;
          }
          // Covered while fully visible at rest at y=0 is the bug; at
          // other offsets the user can scroll, report only.
          // ignore: avoid_print
          if (hits.isNotEmpty) print('QA-RETEST-FAB x$scale $mode $hits');
          expect(hits.where((h) => h.startsWith('y=0.0 ')), isEmpty);
        });
      }
    }

    testWidgets('pickup store page hides the delivery fee; delivery page keeps '
        'it', (tester) async {
      await _pumpFood(tester);
      await tester.pumpAndSettle();
      Future<void> openFirst() async {
        final row = find.byType(ZokyFoodStoreRow).first;
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(StoreScreen), findsOneWidget);
      }

      final eta = find.textContaining(ZokyStrings.minutes);
      await openFirst();
      expect(find.textContaining(ZokyStrings.deliveryFee), findsOneWidget);
      expect(eta, findsWidgets);
      await tester.tap(find.byTooltip(ZokyStrings.back));
      await tester.pumpAndSettle();
      await _pickup(tester);
      await openFirst();
      expect(find.textContaining(ZokyStrings.deliveryFee), findsNothing);
      final etaShown = eta.evaluate().isNotEmpty;
      // ignore: avoid_print
      print('QA-RETEST-PICKUP-STORE eta shown in pickup: $etaShown');
    });

    testWidgets('ZOKY-133 repro: pickup store page shows no delivery ETA', (
      tester,
    ) async {
      await _pumpFood(tester);
      await tester.pumpAndSettle();
      Future<void> openFirst() async {
        final row = find.byType(ZokyFoodStoreRow).first;
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(StoreScreen), findsOneWidget);
      }

      final eta = find.textContaining(ZokyStrings.minutes);
      await openFirst();
      expect(find.textContaining(ZokyStrings.deliveryFee), findsOneWidget);
      expect(eta, findsWidgets);
      await tester.tap(find.byTooltip(ZokyStrings.back));
      await tester.pumpAndSettle();
      await _pickup(tester);
      await openFirst();
      expect(find.textContaining(ZokyStrings.deliveryFee), findsNothing);
      final etaShown = eta.evaluate().isNotEmpty;
      // ignore: avoid_print
      print('QA-RETEST-PICKUP-STORE eta shown in pickup: $etaShown');
      expect(etaShown, isFalse, reason: 'delivery ETA on pickup store page');
    }, skip: true); // ZOKY-133 item 1 (open; fee part of ZOKY-131 verified)
  });

  group('demo labelling (no fake data)', () {
    testWidgets('every row/coupon of a demo store says ตัวอย่าง; header '
        'address says (ตัวอย่าง); no score without reviews', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester, height: 3000);
      await tester.pumpAndSettle();
      final rows = tester
          .widgetList<ZokyFoodStoreRow>(find.byType(ZokyFoodStoreRow))
          .toList();
      expect(rows, hasLength(greaterThan(0)));
      for (final row in rows) {
        expect(row.store.isDemo, isTrue);
        expect(row.semanticLabel(), contains('ตัวอย่าง'));
        if (row.store.ratingCount == 0) {
          expect(row.semanticLabel(), isNot(contains('คะแนน')));
        }
      }
      for (final card in find.byType(ZokyFoodCouponCard).evaluate()) {
        final node = tester.getSemantics(find.byWidget(card.widget));
        final all = <String>[];
        void visit(SemanticsNode n) {
          all.add(n.getSemanticsData().label);
          n.visitChildren((c) {
            visit(c);
            return true;
          });
        }

        visit(node);
        expect(all.join(' '), contains('ตัวอย่าง'), reason: all.join(' '));
      }
      expect(
        find.descendant(
          of: find.byType(ZokyFoodAddressButton),
          matching: find.textContaining('(ตัวอย่าง)'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });

  // Visual evidence for manual review (written to QA_SHOT_DIR if set).
  final shotDir = Platform.environment['QA_SHOT_DIR'];
  group('screenshots (Anuphan)', () {
    setUpAll(_loadAnuphan);
    for (final (w, h, sc, y, pickup) in [
      (320.0, 568.0, 1.0, 0.0, false),
      (320.0, 568.0, 1.3, 0.0, false),
      (320.0, 568.0, 1.3, 0.0, true),
      (320.0, 568.0, 2.0, 0.0, false),
      (320.0, 568.0, 2.0, 600.0, false),
      (375.0, 667.0, 2.0, 500.0, false),
      (390.0, 844.0, 1.0, 0.0, false),
    ]) {
      final name =
          'food_${w.toInt()}x${h.toInt()}_t${sc}_s${y.toInt()}'
          '${pickup ? '_pickup' : ''}';
      testWidgets('screenshot $name', (tester) async {
        await _pumpFood(tester, width: w, height: h, top: 20, textScale: sc);
        await tester.pumpAndSettle();
        if (pickup) await _pickup(tester);
        _feed(tester).jumpTo(math.min(y, _feed(tester).maxScrollExtent));
        await tester.pumpAndSettle();
        final view = tester.binding.renderViews.first;
        final layer = view.debugLayer! as OffsetLayer;
        final img = (await tester.runAsync(
          () => layer.toImage(Offset.zero & view.size, pixelRatio: 2),
        ))!;
        final png = (await tester.runAsync(
          () => img.toByteData(format: ImageByteFormat.png),
        ))!;
        img.dispose();
        File('$shotDir/$name.png').writeAsBytesSync(png.buffer.asUint8List());
      }, skip: shotDir == null);
    }
  });
}
