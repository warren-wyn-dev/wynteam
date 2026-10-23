// QA & Security round: ZOKY Food page (FoodHomeScreen), 2026-10-18.
//
// Complements test/food_home_screen_test.dart (Full-Stack suite) with what
// it does not cover: scroll-offset sweep of the pinned header/chips and the
// status bar layer, real-device size/inset/text-scale matrix (568-932pt,
// insets 0/20/47/59 + 34, text 1.0-2.0), semantics reading order, 44pt
// guideline, contrast math on the pale surfaces, hostile store data, back
// gestures, reduced motion and font-icon usage.
//
// Known open bugs are reproduced by tests marked `skip:` with the bug id;
// remove the skip to re-run the repro. Heavy matrix tests carry the tag
// `qa-heavy` (`flutter test --exclude-tags qa-heavy` for a fast run).
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/zoky_app.dart';
import 'package:zoky_app/core/adaptive/zoky_icons.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_chip.dart';
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
import 'package:zoky_app/features/food/widgets/zoky_food_coupon_section.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_header.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_mode_toggle.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_search_field.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_store_row.dart';
import 'package:zoky_app/features/fulfillment/fulfillment_mode_controller.dart';
import 'package:zoky_app/features/home/data/demo_home_content_repository.dart';
import 'package:zoky_app/features/home/home_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

const _heavy = ['qa-heavy'];

class _Stores implements StoreRepository {
  _Stores(this.stores, {this.fail = false, this.latency = Duration.zero});

  List<ZokyStoreSummary> stores;
  bool fail;
  Duration latency;
  int calls = 0;

  @override
  Future<List<ZokyStoreSummary>> fetchDirectory({String query = ''}) async {
    calls++;
    await Future<void>.delayed(latency);
    if (fail) throw StateError('offline');
    return stores;
  }

  @override
  Future<List<ZokyStoreSummary>> fetchRecommended() async => const [];

  @override
  Future<List<ZokyMenuItem>> fetchMenu(String storeId) async => const [];
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
  DeliveryAddressController? addresses,
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  final inset = FakeViewPadding(top: top, bottom: bottom);
  tester.view.padding = inset;
  tester.view.viewPadding = inset;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  }
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  _mode = FulfillmentModeController();
  await tester.pumpWidget(
    ZokyApp(
      config: AppConfig.demo,
      storeRepository: stores ?? DemoStoreRepository(),
      promotionRepository: const DemoPromotionRepository(),
      homeContentRepository: const DemoHomeContentRepository(),
      deliveryAddresses:
          addresses ?? DeliveryAddressController(const DemoAddressRepository()),
      fulfillmentMode: _mode,
      collectedPromos: CollectedPromosController(),
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
  final hero = find.text(ZokyStrings.heroSearchButton);
  await tester.ensureVisible(hero);
  await tester.pumpAndSettle();
  await tester.tap(hero);
  await tester.pumpAndSettle();
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

/// Status bar style the OS would read (top edge of the composited layers).
SystemUiOverlayStyle? _statusBarStyle(WidgetTester tester, double width) {
  final layer = tester.binding.renderViews.first.debugLayer!;
  return layer.find<SystemUiOverlayStyle>(Offset(width / 2, 0));
}

double _luminance(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every semantics label in traversal order under the food page.
List<String> _readingOrder(WidgetTester tester) {
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

  visit(tester.getSemantics(find.byType(FoodHomeScreen)));
  return out;
}

void main() {
  group('scroll sweep: pinned search + chips, status bar', () {
    for (final (w, h, top, bottom) in [
      (375.0, 667.0, 20.0, 0.0),
      (430.0, 932.0, 59.0, 34.0),
    ]) {
      testWidgets('${w.toInt()}x${h.toInt()} inset $top/$bottom', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _pumpFood(tester, width: w, height: h, top: top, bottom: bottom);
        final position = _feed(tester);
        final max = position.maxScrollExtent;
        expect(max, greaterThan(0));
        final failures = <String>[];
        for (var y = 0.0; y <= max + 0.1; y += 23) {
          position.jumpTo(math.min(y, max));
          await tester.pump();
          final e = tester.takeException();
          if (e != null) failures.add('$y: exception $e');
          final surface = tester.getRect(find.byKey(ZokyFoodHeader.surfaceKey));
          final search = tester.getRect(find.byType(ZokyFoodSearchField));
          if (surface.top != 0 || surface.left != 0 || surface.right != w) {
            failures.add('$y: header not full-bleed $surface');
          }
          if (search.top < top || search.bottom > surface.bottom + 0.5) {
            failures.add('$y: search outside header $search vs $surface');
          }
          // Search always tappable (hit test lands in the field).
          final hit = tester.hitTestOnBinding(search.center);
          final field = tester.renderObject(find.byType(ZokyFoodSearchField));
          if (!hit.path.any((e) => e.target == field)) {
            failures.add('$y: search not hit-testable');
          }
          final style = _statusBarStyle(tester, w);
          if (style?.statusBarIconBrightness != Brightness.dark ||
              style?.statusBarBrightness != Brightness.light) {
            failures.add('$y: status bar style $style');
          }
          final chips = find.byKey(FoodHomeScreen.filtersKey);
          if (chips.evaluate().isNotEmpty) {
            final c = tester.getRect(chips);
            if (c.top < surface.bottom - 0.5 && c.bottom > 0) {
              failures.add('$y: chips under the header $c vs $surface');
            }
          }
        }
        // Bottom: chips pinned right under the compact header.
        position.jumpTo(max);
        await tester.pumpAndSettle();
        final surface = tester.getRect(find.byKey(ZokyFoodHeader.surfaceKey));
        final chips = tester.getRect(find.byKey(FoodHomeScreen.filtersKey));
        expect((chips.top - surface.bottom).abs(), lessThan(24));
        expect(failures, isEmpty, reason: failures.take(10).join('\n'));
        semantics.dispose();
      });
    }
  });

  group('layout matrix (real sizes, insets, text 1.0-2.0)', () {
    const devices = [
      (320.0, 568.0, 20.0, 0.0),
      (360.0, 640.0, 0.0, 0.0),
      (375.0, 667.0, 20.0, 0.0),
      (390.0, 844.0, 47.0, 34.0),
      (430.0, 932.0, 59.0, 34.0),
    ];
    for (final (w, h, top, bottom) in devices) {
      for (final scale in [1.0, 1.3, 1.6, 2.0]) {
        testWidgets('${w.toInt()}x${h.toInt()} inset $top/$bottom text '
            '$scale', (tester) async {
          final semantics = tester.ensureSemantics();
          await _pumpFood(
            tester,
            width: w,
            height: h,
            top: top,
            bottom: bottom,
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          for (final mode in FulfillmentMode.values) {
            final r = tester.getRect(
              find.byKey(ZokyFoodModeToggle.keyFor(mode)),
            );
            expect(r.right, lessThanOrEqualTo(w), reason: '$mode chip');
            expect(r.height, greaterThanOrEqualTo(44 - 1e-6));
          }
          // Pickup at this size.
          await tester.tap(
            find.byKey(ZokyFoodModeToggle.keyFor(FulfillmentMode.pickup)),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Collapsed: usable list area below the pinned header + chips.
          final position = _feed(tester);
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final chips = tester.getRect(find.byKey(FoodHomeScreen.filtersKey));
          final free = h - bottom - chips.bottom;
          // ignore: avoid_print
          print(
            'QA-FREE ${w.toInt()}x${h.toInt()} t$scale: '
            'pinned ${chips.bottom.toStringAsFixed(0)}pt, '
            'list ${free.toStringAsFixed(0)}pt '
            '(${(100 * free / h).toStringAsFixed(0)}%)',
          );
          expect(
            free,
            greaterThan(h * 0.4),
            reason: 'pinned header + chips leave too little list',
          );
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          semantics.dispose();
        }, tags: _heavy);
      }
    }
  });

  group('header address keeps the demo label readable (Anuphan)', () {
    setUpAll(_loadAnuphan);
    for (final w in [320.0, 375.0, 430.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('${w.toInt()}pt text $scale', (tester) async {
          final controller = DeliveryAddressController(
            const DemoAddressRepository(),
          );
          await _pumpFood(
            tester,
            width: w,
            height: 844,
            textScale: scale,
            addresses: controller,
          );
          final cut = <String>[];
          for (final address in DemoAddressRepository.addresses) {
            controller.select(address);
            await tester.pumpAndSettle();
            final title = tester.renderObject<RenderParagraph>(
              find.descendant(
                of: find.byType(ZokyFoodAddressButton),
                matching: find.text(address.label),
              ),
            );
            if (title.didExceedMaxLines) cut.add(address.label);
          }
          expect(cut, isEmpty, reason: 'demo label ellipsized: $cut');
        }); // ZOKY-129 (fixed)
      }
    }
  });

  group('no truncated store/coupon text (Anuphan, design 10.2)', () {
    setUpAll(_loadAnuphan);
    for (final w in [320.0, 375.0, 430.0]) {
      for (final scale in [1.0, 1.3, 1.6, 2.0]) {
        testWidgets('${w.toInt()}pt text $scale', (tester) async {
          await _pumpFood(tester, width: w, height: 844, textScale: scale);
          final cut = <String>{};
          void scan() {
            for (final type in [ZokyFoodStoreRow, ZokyFoodCouponCard]) {
              for (final e
                  in find
                      .descendant(
                        of: find.byType(type),
                        matching: find.byType(RichText),
                      )
                      .evaluate()) {
                final p = e.renderObject! as RenderParagraph;
                if (p.didExceedMaxLines) {
                  cut.add('$type: "${p.text.toPlainText()}"');
                }
              }
            }
          }

          final position = _feed(tester);
          for (var y = 0.0; ; y += 250) {
            position.jumpTo(math.min(y, position.maxScrollExtent));
            await tester.pumpAndSettle();
            scan();
            if (y >= position.maxScrollExtent) break;
          }
          for (final c in cut) {
            // ignore: avoid_print
            print('QA-TRUNCATED ${w.toInt()} x$scale $c');
          }
          expect(cut, isEmpty);
        }, tags: _heavy); // ZOKY-129 (fixed)
      }
    }
  });

  group('accessibility', () {
    testWidgets('reading order follows the visual order', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester, width: 390, height: 844, top: 47, bottom: 34);
      final order = _readingOrder(tester);
      // ignore: avoid_print
      print('QA-ORDER ${order.join(' | ')}');
      int at(bool Function(String) test, String what) {
        final i = order.indexWhere(test);
        expect(i, isNonNegative, reason: '$what missing in $order');
        return i;
      }

      final seq = [
        at((l) => l == ZokyStrings.back, 'back'),
        at((l) => l.startsWith(ZokyStrings.deliverAt), 'address'),
        at((l) => l == ZokyStrings.favoriteStores, 'heart'),
        at((l) => l == ZokyStrings.coupons, 'coupons'),
        at((l) => l == ZokyStrings.modeDelivery, 'delivery chip'),
        at((l) => l == ZokyStrings.modePickup, 'pickup chip'),
        at((l) => l == ZokyStrings.foodSearchPlaceholder, 'search'),
        at((l) => l == ZokyStrings.couponsTitle, 'coupons title'),
        at((l) => l == ZokyStrings.allStoresTitle, 'stores title'),
        at((l) => l == ZokyStrings.filters, 'filter button'),
        at((l) => l == ZokyStrings.filterAll, 'all chip'),
        at((l) => l.contains(ZokyStrings.viewMenu), 'first row'),
        at((l) => l == ZokyStrings.cart, 'cart'),
      ];
      final sorted = [...seq]..sort();
      expect(seq, sorted, reason: order.join(' | '));
      semantics.dispose();
    }); // ZOKY-130 (fixed)

    testWidgets('selected / toggled states are exposed and update', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      SemanticsData data(Finder f) => tester.getSemantics(f).getSemanticsData();
      final delivery = find.byKey(
        ZokyFoodModeToggle.keyFor(FulfillmentMode.delivery),
      );
      final pickup = find.byKey(
        ZokyFoodModeToggle.keyFor(FulfillmentMode.pickup),
      );
      expect(data(delivery).flagsCollection.isSelected, Tristate.isTrue);
      expect(data(pickup).flagsCollection.isSelected, Tristate.isFalse);
      await tester.tap(pickup);
      await tester.pumpAndSettle();
      expect(data(pickup).flagsCollection.isSelected, Tristate.isTrue);
      expect(data(delivery).flagsCollection.isSelected, Tristate.isFalse);
      // Pickup header announces pickup (no "จัดส่งที่").
      expect(
        data(find.byType(ZokyFoodAddressButton)).label,
        ZokyStrings.modePickup,
      );
      // Coupon toggle.
      final collect = find.byType(ZokyCollectButton).first;
      await tester.ensureVisible(collect);
      await tester.pumpAndSettle();
      expect(data(collect).flagsCollection.isToggled, Tristate.isFalse);
      await tester.tap(collect);
      await tester.pumpAndSettle();
      expect(data(collect).flagsCollection.isToggled, Tristate.isTrue);
      semantics.dispose();
    });

    test('contrast of text on the pale surfaces >= 4.5:1', () {
      Color over(Color fg, Color bg) => Color.alphaBlend(fg, bg);
      final cases = <String, (Color, Color)>{
        'จัดส่งที่ on headerPale': (
          ZokyColors.textSecondary,
          ZokyColors.headerPale,
        ),
        'search placeholder on white': (
          ZokyColors.textSecondary,
          ZokyColors.surface,
        ),
        'coupon condition on #FDEEF3': (
          ZokyColors.textSecondary,
          ZokyFoodCouponCard.background,
        ),
        'coupon label ink on #FDEEF3': (
          ZokyColors.textPrimary,
          ZokyFoodCouponCard.background,
        ),
        'รับเองได้ success on successContainer': (
          ZokyColors.success,
          ZokyColors.successContainer,
        ),
        'โฆษณา white on ink 72% over white': (
          ZokyColors.neutral0,
          over(ZokyColors.neutral900.withValues(alpha: 0.72), Colors.white),
        ),
        'ปิดอยู่ white on ink 80% over white': (
          ZokyColors.neutral0,
          over(ZokyColors.neutral900.withValues(alpha: 0.8), Colors.white),
        ),
        'promo white on brandDeep': (ZokyColors.onAction, ZokyColors.brandDeep),
        'ดูเมนู brandDeep on white': (ZokyColors.brandDeep, Colors.white),
        'meta gray on white': (ZokyColors.textSecondary, Colors.white),
        'chip ink on chip gray': (ZokyColors.textPrimary, ZokyColors.chip),
        'collected brandDeep on white': (ZokyColors.brandDeep, Colors.white),
        'mode chip white on brandDeep': (
          ZokyColors.onAction,
          ZokyFoodModeToggle.selectedFill,
        ),
      };
      final low = <String>[];
      cases.forEach((name, pair) {
        final ratio = _contrast(pair.$1, pair.$2);
        if (ratio < 4.5) low.add('$name ${ratio.toStringAsFixed(2)}');
      });
      expect(low, isEmpty, reason: low.join(', '));
    });

    testWidgets('reduced motion: loading state settles (no endless '
        'animation)', (tester) async {
      final stores = _Stores(
        DemoStoreRepository.stores,
        latency: const Duration(seconds: 5),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpWidget(
        ZokyApp(
          config: AppConfig.demo,
          storeRepository: stores,
          promotionRepository: const DemoPromotionRepository(),
          homeContentRepository: const DemoHomeContentRepository(),
          deliveryAddresses: DeliveryAddressController(
            const DemoAddressRepository(),
          ),
          fulfillmentMode: FulfillmentModeController(),
          collectedPromos: CollectedPromosController(),
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZokyStrings.heroSearchButton));
      await tester.pump();
      // Let the page transition finish; the directory is still loading.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(ZokyFoodCouponSection.skeletonKey), findsOneWidget);
      // With animations disabled nothing may keep scheduling frames.
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });
  });

  group('navigation and flows', () {
    for (final y in [100.0, 420.0, 650.0]) {
      testWidgets('iOS edge swipe at y=$y returns to Home', (tester) async {
        await _pumpFood(tester, top: 47, bottom: 34);
        final gesture = await tester.startGesture(Offset(4, y));
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(30, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.byType(FoodHomeScreen), findsNothing);
        expect(find.byType(HomeScreen), findsOneWidget);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }

    testWidgets('Android system back returns to Home (app stays open)', (
      tester,
    ) async {
      await _pumpFood(tester);
      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(handled, isTrue);
      expect(find.byType(FoodHomeScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('mode switches keep a valid filter in every order', (
      tester,
    ) async {
      await _pumpFood(tester);
      final pickup = find.byKey(
        ZokyFoodModeToggle.keyFor(FulfillmentMode.pickup),
      );
      final delivery = find.byKey(
        ZokyFoodModeToggle.keyFor(FulfillmentMode.delivery),
      );
      Future<void> chip(String label) async {
        final f = find.widgetWithText(ZokyChip, label);
        await tester.ensureVisible(f);
        await tester.pumpAndSettle();
        await tester.tap(f);
        await tester.pumpAndSettle();
      }

      bool selected(String label) => tester
          .widget<ZokyChip>(find.widgetWithText(ZokyChip, label))
          .selected;

      for (final label in [
        ZokyStrings.filterPromo,
        ZokyStrings.filterNear,
        ZokyStrings.filterFreeDelivery,
      ]) {
        _feed(tester).jumpTo(0);
        await tester.pumpAndSettle();
        await chip(label);
        _feed(tester).jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(pickup);
        await tester.pumpAndSettle();
        // Free delivery chip gone; something is selected.
        expect(
          find.widgetWithText(ZokyChip, ZokyStrings.filterFreeDelivery),
          findsNothing,
        );
        final selectedChips = tester
            .widgetList<ZokyChip>(find.byType(ZokyChip))
            .where((c) => c.selected);
        expect(selectedChips, hasLength(1));
        // No free-delivery promo label in pickup rows.
        for (final row in tester.widgetList<ZokyFoodStoreRow>(
          find.byType(ZokyFoodStoreRow),
        )) {
          expect(row.store.supportsPickup, isTrue);
          expect(row.semanticLabel(), isNot(contains('ส่งฟรี')));
          expect(row.semanticLabel(), isNot(contains('ส่งประมาณ')));
        }
        await tester.tap(delivery);
        await tester.pumpAndSettle();
        if (label != ZokyStrings.filterFreeDelivery) {
          expect(selected(label), isTrue, reason: '$label kept');
        }
        await chip(ZokyStrings.filterAll);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('retry from the error state shows loading feedback', (
      tester,
    ) async {
      final stores = _Stores(DemoStoreRepository.stores, fail: true);
      await _pumpFood(tester, stores: stores);
      stores
        ..fail = false
        ..latency = const Duration(seconds: 2);
      final retry = find.descendant(
        of: find.byType(ZokyStateView),
        matching: find.text(ZokyStrings.retry),
      );
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pump(const Duration(milliseconds: 300));
      // Expected: skeleton (or spinner) instead of the unchanged error.
      expect(find.text(ZokyStrings.offlineTitle), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byType(ZokyFoodStoreRow), findsWidgets);
    }); // ZOKY-131 (fixed)

    testWidgets('pull to refresh that fails keeps the list on screen', (
      tester,
    ) async {
      final stores = _Stores(DemoStoreRepository.stores);
      await _pumpFood(tester, stores: stores);
      expect(find.byType(ZokyFoodStoreRow), findsWidgets);
      stores.fail = true;
      await tester.fling(
        find.byKey(FoodHomeScreen.allStoresKey),
        const Offset(0, 500),
        1200,
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZokyFoodStoreRow), findsWidgets);
    }); // ZOKY-131 (fixed)

    testWidgets('store row opens StoreScreen in pickup too', (tester) async {
      await _pumpFood(tester);
      await tester.tap(
        find.byKey(ZokyFoodModeToggle.keyFor(FulfillmentMode.pickup)),
      );
      await tester.pumpAndSettle();
      final row = find.byType(ZokyFoodStoreRow).first;
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(StoreScreen), findsOneWidget);
    });
  });

  group('hostile / edge store data', () {
    final long = 'ร้าน${'ยาวมาก' * 30}';
    final hostile = [
      ZokyStoreSummary(
        id: 'x1',
        name: long,
        isOpen: false,
        deliveryFee: 0,
        isAd: true,
        promoLabel: 'ลด 20% เมื่อสั่งครบ ฿300 ${'โปร' * 20}',
        promoName: 'p' * 300,
        promoMinSubtotal: 999999999,
        ratingAverage: 5,
        ratingCount: 0, // no reviews -> no score
        categories: const [],
        coverUrl: 'javascript:alert(1)',
        supportsPickup: true,
      ),
      const ZokyStoreSummary(
        id: 'x2',
        name: '<script>alert(1)</script>',
        isOpen: true,
        deliveryFee: 10,
        etaMinMinutes: 30, // max missing -> no ETA
        ratingAverage: double.nan,
        ratingCount: 3,
        distanceKm: double.infinity,
        coverUrl: 'file:///etc/passwd',
      ),
      const ZokyStoreSummary(
        id: 'x3',
        name: 'http cover',
        isOpen: true,
        deliveryFee: 10,
        coverUrl: 'http://127.0.0.1:1/x.png',
        distanceKm: -1,
      ),
    ];

    for (final scale in [1.0, 2.0]) {
      testWidgets('no crash/overflow, no fake score/ETA at text $scale', (
        tester,
      ) async {
        await _pumpFood(
          tester,
          width: 320,
          height: 568,
          top: 20,
          textScale: scale,
          stores: _Stores(hostile),
        );
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final position = _feed(tester);
        for (var y = 0.0; y <= position.maxScrollExtent; y += 200) {
          position.jumpTo(y);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'at $y');
        }
        final rows = tester
            .widgetList<ZokyFoodStoreRow>(find.byType(ZokyFoodStoreRow))
            .toList();
        for (final row in rows) {
          final label = row.semanticLabel();
          expect(label, isNot(contains('คะแนน')), reason: label);
          expect(label, isNot(contains('ส่งประมาณ')), reason: label);
        }
        // NaN/Infinity distance copy: see "distance renders sanely" below.
        // Coupons sheet with hostile promo.
        position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ZokyFoodHeader.couponsKey));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    test('distance renders sanely for odd values', () {
      for (final d in [double.infinity, double.nan, -1.0]) {
        final row = ZokyFoodStoreRow(
          store: ZokyStoreSummary(
            id: 'd',
            name: 'd',
            isOpen: true,
            deliveryFee: 0,
            distanceKm: d,
          ),
          mode: FulfillmentMode.delivery,
          onTap: () {},
        );
        final label = row.semanticLabel();
        expect(label, isNot(contains('Infinity')), reason: label);
        expect(label, isNot(contains('NaN')), reason: label);
        expect(label, isNot(contains('-1.0')), reason: label);
      }
    }); // ZOKY-131 (fixed)
  });

  group('icon robustness (no font-dependent icons, Founder iPad bug)', () {
    final names = <IconData, String>{
      CupertinoIcons.back: 'CupertinoIcons.back (food back)',
      Icons.arrow_back: 'Icons.arrow_back (food back)',
      ZokyIcons.search: 'search (food search field)',
      ZokyIcons.clock: 'clock (closed label)',
      ZokyIcons.info: 'info (address demo note)',
      Icons.check_circle_rounded: 'check_circle (selected address)',
      ZokyIcons.location: 'location (address tile)',
      ZokyIcons.add: 'add (new address)',
      ZokyIcons.chevronRight: 'chevronRight (section see-all)',
      ZokyIcons.wifiOff: 'wifiOff (offline state)',
      ZokyIcons.store: 'store (empty state)',
      ZokyIcons.favorite: 'favorite (favorites sheet)',
      ZokyIcons.food: 'food (cover placeholder)',
      ZokyIcons.error: 'error',
    };
    Set<String> fontIcons(WidgetTester tester, String where) => {
      for (final e in find.byType(Icon).evaluate())
        if ((e.widget as Icon).icon case final icon?)
          '$where: ${names[icon] ?? '${icon.fontFamily} 0x${icon.codePoint.toRadixString(16)}'}',
    };

    testWidgets('Home + Food (and their sheets/states) use painted icons '
        'only', (tester) async {
      final found = <String>{};
      final stores = _Stores(DemoStoreRepository.stores);
      await _pumpFood(tester, height: 2000, stores: stores);
      found.addAll(fontIcons(tester, 'food'));
      await tester.tap(find.byType(ZokyFoodAddressButton));
      await tester.pumpAndSettle();
      found.addAll(fontIcons(tester, 'address sheet'));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZokyFoodHeader.favoritesKey));
      await tester.pumpAndSettle();
      found.addAll(fontIcons(tester, 'favorites sheet'));
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZokyFoodHeader.backKey));
      await tester.pumpAndSettle();
      found.addAll(fontIcons(tester, 'home'));
      // Error state on first load (a failed refresh keeps the list since
      // ZOKY-131).
      final flaky = _Stores(DemoStoreRepository.stores, fail: true);
      await _pumpFood(tester, stores: flaky);
      Future<void> refresh() async {
        _feed(tester).jumpTo(0);
        await tester.pumpAndSettle();
        await tester.fling(
          find.byKey(FoodHomeScreen.allStoresKey),
          const Offset(0, 500),
          1200,
        );
        await tester.pumpAndSettle();
      }

      expect(find.byType(ZokyStateView), findsOneWidget);
      found.addAll(fontIcons(tester, 'food error'));
      flaky
        ..fail = false
        ..stores = const [];
      await refresh();
      found.addAll(fontIcons(tester, 'food empty'));
      // ignore: avoid_print
      print('QA-FONT-ICONS\n${(found.toList()..sort()).join('\n')}');
      expect(found, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    // ZOKY-128 (fixed)
  });
}
