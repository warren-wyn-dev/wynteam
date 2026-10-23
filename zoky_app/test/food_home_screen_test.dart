import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/app_dependencies.dart';
import 'package:zoky_app/app/zoky_app.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_chip.dart';
import 'package:zoky_app/core/widgets/zoky_line_icon.dart';
import 'package:zoky_app/core/widgets/zoky_state_view.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/address/address_sheet.dart';
import 'package:zoky_app/features/address/data/address_repository.dart';
import 'package:zoky_app/features/address/data/demo_address_repository.dart';
import 'package:zoky_app/features/address/delivery_address_controller.dart';
import 'package:zoky_app/features/address/domain/address_models.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/data/store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';
import 'package:zoky_app/features/food/collected_promos_controller.dart';
import 'package:zoky_app/features/food/food_home_screen.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_address_button.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_cart_button.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_category_row.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_coupon_section.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_header.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_mode_toggle.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_search_field.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_store_row.dart';
import 'package:zoky_app/features/fulfillment/fulfillment_mode_controller.dart';
import 'package:zoky_app/features/home/data/demo_home_content_repository.dart';
import 'package:zoky_app/features/home/data/home_content_repository.dart';
import 'package:zoky_app/features/home/domain/home_content_models.dart';
import 'package:zoky_app/features/home/widgets/zoky_food_hero_card.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import 'support/pump_zoky.dart';

const _categories = DemoHomeContentRepository.categories;
const _addresses = DemoAddressRepository.addresses;
const _stores = DemoStoreRepository.stores;

/// Directory stub: fixed [stores], or an error while [fail]; counts calls.
class _FakeStores implements StoreRepository {
  _FakeStores(this.stores, {this.fail = false, this.latency = Duration.zero});

  List<ZokyStoreSummary> stores;
  bool fail;
  final Duration latency;
  int directoryCalls = 0;

  @override
  Future<List<ZokyStoreSummary>> fetchDirectory({String query = ''}) async {
    directoryCalls++;
    await Future<void>.delayed(latency);
    if (fail) throw StateError('offline');
    return stores;
  }

  @override
  Future<List<ZokyStoreSummary>> fetchRecommended() async => const [];

  @override
  Future<List<ZokyMenuItem>> fetchMenu(String storeId) async => const [];
}

class _FakeContent implements HomeContentRepository {
  _FakeContent({this.fail = false});

  bool fail;
  int categoryCalls = 0;

  @override
  Future<List<ZokyHomeBanner>> fetchActiveBanners() async => const [];

  @override
  Future<List<ZokyFoodCategory>> fetchFoodCategories() async {
    categoryCalls++;
    if (fail) throw StateError('offline');
    return _categories;
  }
}

class _CountingAddresses implements AddressRepository {
  int calls = 0;

  @override
  Future<List<ZokyDeliveryAddress>> fetchSavedAddresses() async {
    calls++;
    return _addresses;
  }
}

/// App deps of the last [_pumpFood] (to inspect controllers).
late FulfillmentModeController _mode;
late CollectedPromosController _collected;

/// Pumps the app and opens the food page from the Home hero card
/// (Founder, 2026-10-18). Optional repositories replace the demo ones.
Future<void> _pumpFood(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  double bottomInset = 0,
  double topInset = 0,
  StoreRepository? stores,
  HomeContentRepository? content,
}) async {
  setPhoneViewport(
    tester,
    width: width,
    height: height,
    textScale: textScale,
    bottomInset: bottomInset,
  );
  if (topInset > 0) {
    final inset = FakeViewPadding(top: topInset, bottom: bottomInset);
    tester.view.padding = inset;
    tester.view.viewPadding = inset;
  }
  _mode = FulfillmentModeController();
  _collected = CollectedPromosController();
  await tester.pumpWidget(
    ZokyApp(
      config: AppConfig.demo,
      storeRepository: stores ?? DemoStoreRepository(),
      promotionRepository: const DemoPromotionRepository(),
      homeContentRepository: content ?? const DemoHomeContentRepository(),
      deliveryAddresses: DeliveryAddressController(
        const DemoAddressRepository(),
      ),
      fulfillmentMode: _mode,
      collectedPromos: _collected,
    ),
  );
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
  // Short viewports: bring the hero button on screen first.
  await tester.ensureVisible(find.text(ZokyStrings.heroSearchButton));
  await tester.pumpAndSettle();
  await tester.tap(find.text(ZokyStrings.heroSearchButton));
  await tester.pumpAndSettle();
  expect(find.byType(FoodHomeScreen), findsOneWidget);
}

/// The food page's vertical scroll position.
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

Finder _addressButton() => find.byType(ZokyFoodAddressButton);
Finder _searchField() => find.byType(ZokyFoodSearchField);
Finder _rows() => find.byType(ZokyFoodStoreRow);

/// Scrolls the feed to its real end. Rows wrap (ZOKY-129), so their
/// heights differ and the list's estimated extent settles only once the
/// last rows are laid out.
Future<void> _jumpToEnd(WidgetTester tester) async {
  final position = _feed(tester);
  for (var i = 0; i < 10; i++) {
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    if (position.pixels >= position.maxScrollExtent) return;
  }
}

Finder _pill(FulfillmentMode mode) =>
    find.byKey(ZokyFoodModeToggle.keyFor(mode));
Finder _chip(String label) => find.widgetWithText(ZokyChip, label);

/// Every store id shown in the list (scrolls through it).
Future<Set<String>> _shownIds(WidgetTester tester) async {
  final ids = <String>{};
  final position = _feed(tester);
  position.jumpTo(0);
  await tester.pumpAndSettle();
  for (var i = 0; i < 20; i++) {
    for (final e in _rows().evaluate()) {
      ids.add((e.widget as ZokyFoodStoreRow).store.id);
    }
    if (position.pixels >= position.maxScrollExtent) break;
    position.jumpTo(
      (position.pixels + 300).clamp(0.0, position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
  }
  return ids;
}

Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(_chip(label));
  await tester.pumpAndSettle();
  await tester.tap(_chip(label));
  await tester.pumpAndSettle();
}

void main() {
  group('order', () {
    testWidgets('full-bleed header (row, chips, search), categories, '
        'coupons, all stores, chips, rows', (tester) async {
      await _pumpFood(tester, height: 3000, topInset: 59);
      double top(Finder f) => tester.getTopLeft(f).dy;
      final surface = tester.getRect(find.byKey(ZokyFoodHeader.surfaceKey));
      // Blush from the very top (under the status bar) and edge to edge.
      expect(surface.top, 0);
      expect(surface.left, 0);
      expect(surface.right, 390);
      final back = tester.getRect(find.byKey(ZokyFoodHeader.backKey));
      final title = tester.getRect(_addressButton());
      final heart = tester.getRect(find.byKey(ZokyFoodHeader.favoritesKey));
      final coupon = tester.getRect(find.byKey(ZokyFoodHeader.couponsKey));
      // Content respects the status bar.
      expect(back.top, greaterThanOrEqualTo(59));
      expect(title.top, greaterThanOrEqualTo(59));
      expect(back.right, lessThanOrEqualTo(title.left));
      expect(title.right, lessThanOrEqualTo(heart.left));
      expect(heart.right, lessThanOrEqualTo(coupon.left));
      expect(coupon.right, lessThanOrEqualTo(390));
      // Address block left-aligned, right after the back button.
      final label = tester.getRect(
        find.descendant(
          of: _addressButton(),
          matching: find.text(ZokyStrings.deliverAt),
        ),
      );
      expect(label.left - back.right, lessThan(12));
      // Mode chips inside the header under the row, left-aligned; then
      // the search field, inside the header (which fades to white).
      final toggle = tester.getRect(find.byType(ZokyFoodModeToggle));
      expect(toggle.top, greaterThanOrEqualTo(title.bottom - 0.5));
      expect(toggle.left, 16);
      final search = tester.getRect(_searchField());
      expect(search.top, greaterThan(toggle.bottom - 0.5));
      expect(search.bottom, lessThan(surface.bottom));
      expect(
        surface.bottom,
        lessThanOrEqualTo(top(find.byType(ZokyFoodCategoryRow))),
      );
      expect(
        top(find.byType(ZokyFoodCategoryRow)),
        lessThan(top(find.byKey(ZokyFoodCouponSection.sectionKey))),
      );
      expect(
        top(find.byKey(ZokyFoodCouponSection.sectionKey)),
        lessThan(top(find.byKey(FoodHomeScreen.allStoresKey))),
      );
      expect(
        top(find.byKey(FoodHomeScreen.allStoresKey)),
        lessThan(top(find.byKey(FoodHomeScreen.filtersKey))),
      );
      expect(
        top(find.byKey(FoodHomeScreen.filtersKey)),
        lessThan(top(_rows().first)),
      );
      // Rows, not the grid; the hero lives on Home only.
      expect(find.byType(ZokyStoreCard), findsNothing);
      expect(find.byType(ZokyFoodHeroCard), findsNothing);
    });

    testWidgets('back button is adaptive and labelled', (tester) async {
      // Painted glyphs, so a stale icon font cannot blank them (ZOKY-128).
      for (final (platform, glyph) in [
        (TargetPlatform.iOS, ZokyLineGlyph.chevronLeft),
        (TargetPlatform.android, ZokyLineGlyph.arrowLeft),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        await _pumpFood(tester);
        expect(
          find.descendant(
            of: find.byKey(ZokyFoodHeader.backKey),
            matching: find.byKey(ZokyLineIcon.keyFor(glyph)),
          ),
          findsOneWidget,
        );
        expect(find.byTooltip(ZokyStrings.back), findsOneWidget);
        expect(
          tester.getSize(find.byKey(ZokyFoodHeader.backKey)).height,
          greaterThanOrEqualTo(44),
        );
        await tester.tap(find.byKey(ZokyFoodHeader.backKey));
        await tester.pumpAndSettle();
        expect(find.byType(FoodHomeScreen), findsNothing);
      }
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('header actions', () {
    testWidgets('heart opens the ร้านโปรด sheet', (tester) async {
      await _pumpFood(tester);
      expect(find.byTooltip(ZokyStrings.favoriteStores), findsOneWidget);
      await tester.tap(find.byKey(ZokyFoodHeader.favoritesKey));
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.comingSoon), findsOneWidget);
    });

    testWidgets('coupon icon opens the รวมโค้ดลดเพิ่ม sheet', (tester) async {
      await _pumpFood(tester);
      expect(find.byTooltip(ZokyStrings.coupons), findsOneWidget);
      expect(
        tester.getSize(find.byKey(ZokyFoodHeader.couponsKey)).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byKey(ZokyFoodHeader.couponsKey));
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.couponsSheetTitle), findsOneWidget);
      final promos = _stores.where((s) => s.hasPromo).length;
      // The section (behind) and the sheet each show every coupon.
      expect(promos, lessThanOrEqualTo(ZokyFoodCouponSection.maxCards));
      expect(find.byType(ZokyFoodCouponCard), findsNWidgets(2 * promos));
    });

    testWidgets('coupons sheet says so when there are none', (tester) async {
      await _pumpFood(
        tester,
        stores: _FakeStores([
          for (final s in _stores)
            if (!s.hasPromo) s,
        ]),
      );
      await tester.tap(find.byKey(ZokyFoodHeader.couponsKey));
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.couponsEmpty), findsOneWidget);
    });

    testWidgets('status bar uses dark icons over the pale blush, open and '
        'pinned', (tester) async {
      await _pumpFood(tester, topInset: 59);
      expect(
        ZokyFoodHeader.systemOverlayStyle.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(
        ZokyFoodHeader.systemOverlayStyle.statusBarBrightness,
        Brightness.light,
      );
      AnnotatedRegion<SystemUiOverlayStyle> region() => tester.widget(
        find
            .ancestor(
              of: find.byKey(ZokyFoodHeader.surfaceKey),
              matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
            )
            .first,
      );
      expect(region().value, ZokyFoodHeader.systemOverlayStyle);
      _feed(tester).jumpTo(600);
      await tester.pumpAndSettle();
      expect(region().value, ZokyFoodHeader.systemOverlayStyle);
      expect(tester.getRect(find.byKey(ZokyFoodHeader.surfaceKey)).top, 0);
    });
  });

  group('address', () {
    testWidgets('two lines: small "จัดส่งที่" over the bold address ▾', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      final def = _addresses.firstWhere((a) => a.isDefault);
      Finder inButton(Finder f) =>
          find.descendant(of: _addressButton(), matching: f);
      final label = tester.getRect(inButton(find.text(ZokyStrings.deliverAt)));
      final name = tester.getRect(inButton(find.text(def.label)));
      final caret = tester.getRect(
        inButton(find.byKey(ZokyLineIcon.keyFor(ZokyLineGlyph.caretDown))),
      );
      expect(label.bottom, lessThanOrEqualTo(name.top + 0.5));
      expect(label.left, name.left);
      expect(caret.left, greaterThanOrEqualTo(name.right));
      expect(
        tester.widget<Text>(inButton(find.text(def.label))).style!.fontWeight,
        FontWeight.w700,
      );
      expect(def.label, contains('ตัวอย่าง'));
      final node = tester.getSemantics(
        find.bySemanticsLabel('${ZokyStrings.deliverAt} ${def.label}'),
      );
      expect(node, isSemantics(isButton: true));
      expect(tester.getSize(_addressButton()).height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('sheet lists addresses, selects one and closes '
          '(${platform.name})', (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        await _pumpFood(tester);
        await tester.tap(_addressButton());
        await tester.pumpAndSettle();
        expect(find.byType(ZokyAddressSheet), findsOneWidget);
        expect(find.text(ZokyStrings.demoAddressLabel), findsOneWidget);
        expect(find.byType(ZokyAddressTile), findsNWidgets(_addresses.length));
        final work = _addresses[1];
        await tester.tap(
          find.descendant(
            of: find.byType(ZokyAddressSheet),
            matching: find.text(work.label),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ZokyAddressSheet), findsNothing);
        expect(
          find.descendant(
            of: _addressButton(),
            matching: find.textContaining(work.label),
          ),
          findsOneWidget,
        );
        debugDefaultTargetPlatformOverride = null;
      });
    }

    test('controller loads once, defaults, ignores unknown picks', () async {
      final repo = _CountingAddresses();
      final controller = DeliveryAddressController(repo);
      await controller.load();
      await controller.load();
      expect(repo.calls, 1);
      expect(controller.selected?.id, 'demo-address-1');
      controller.select(
        const ZokyDeliveryAddress(id: 'evil', label: 'x', address: 'y'),
      );
      expect(controller.selected?.id, 'demo-address-1');
      controller.dispose();
    });
  });

  group('search field', () {
    testWidgets('is a button labelled with the placeholder, 44pt+', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      expect(ZokyStrings.foodSearchPlaceholder, 'ค้นหาร้านอาหารหรือเมนู');
      expect(
        tester.getSemantics(_searchField()),
        isSemantics(isButton: true, label: ZokyStrings.foodSearchPlaceholder),
      );
      expect(tester.getSize(_searchField()).height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    testWidgets('opens store search with the keyboard up', (tester) async {
      await _pumpFood(tester);
      await tester.tap(_searchField());
      await tester.pumpAndSettle();
      final screen = tester.widget<StoreSearchScreen>(
        find.byType(StoreSearchScreen),
      );
      expect(screen.autofocus, isTrue);
      expect(screen.category, isNull);
      expect(
        tester.widget<TextField>(find.byType(TextField)).autofocus,
        isTrue,
      );
    });
  });

  group('fulfillment mode toggle', () {
    testWidgets('two buttons; จัดส่ง selected by default', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      expect(_mode.mode, FulfillmentMode.delivery);
      expect(
        tester.getSemantics(_pill(FulfillmentMode.delivery)),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          label: ZokyStrings.modeDelivery,
        ),
      );
      expect(
        tester.getSemantics(_pill(FulfillmentMode.pickup)),
        isSemantics(
          isButton: true,
          isSelected: false,
          isInMutuallyExclusiveGroup: true,
          label: ZokyStrings.modePickup,
        ),
      );
      expect(find.text(ZokyStrings.comingSoon), findsNothing);
      for (final mode in FulfillmentMode.values) {
        // 44pt tap box around a compact ~32pt pill.
        expect(tester.getSize(_pill(mode)).height, greaterThanOrEqualTo(44));
        final pill = tester.getSize(
          find.descendant(
            of: _pill(mode),
            matching: find.byType(AnimatedContainer),
          ),
        );
        expect(pill.height, inInclusiveRange(30, 36));
        expect(pill.width, greaterThanOrEqualTo(44));
      }
      // Tapping the invisible part of the box (above the pill) works.
      final box = tester.getRect(_pill(FulfillmentMode.pickup));
      await tester.tapAt(Offset(box.center.dx, box.top + 2));
      await tester.pumpAndSettle();
      expect(_mode.mode, FulfillmentMode.pickup);
      expect(
        tester.getSemantics(_pill(FulfillmentMode.pickup)),
        isSemantics(
          isButton: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          label: ZokyStrings.modePickup,
        ),
      );
      semantics.dispose();
    });

    testWidgets('pickup: header label, pickup stores only, no ETA, '
        'รับเองได้, no ส่งฟรี chip; back to delivery restores', (tester) async {
      await _pumpFood(tester, height: 2400);
      await tester.tap(_pill(FulfillmentMode.pickup));
      await tester.pumpAndSettle();
      expect(_mode.mode, FulfillmentMode.pickup);
      // Bold "รับเองที่ร้าน ▾" title, no "จัดส่งที่" label line.
      expect(
        find.descendant(
          of: _addressButton(),
          matching: find.text(ZokyStrings.modePickup),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _addressButton(),
          matching: find.text(ZokyStrings.deliverAt),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: _addressButton(),
          matching: find.byKey(ZokyLineIcon.keyFor(ZokyLineGlyph.caretDown)),
        ),
        findsOneWidget,
      );
      expect(_chip(ZokyStrings.filterFreeDelivery), findsNothing);
      final pickupIds = {
        for (final s in _stores)
          if (s.supportsPickup) s.id,
      };
      expect(pickupIds.length, lessThan(_stores.length));
      expect(await _shownIds(tester), pickupIds);
      for (final row in tester.widgetList<ZokyFoodStoreRow>(_rows())) {
        expect(row.mode, FulfillmentMode.pickup);
        final label = row.semanticLabel();
        expect(label, contains(ZokyStrings.pickupAvailable));
        expect(label, isNot(contains('ส่งประมาณ')));
      }
      expect(find.text(ZokyStrings.pickupAvailable), findsWidgets);
      expect(find.textContaining(ZokyStrings.minutes), findsNothing);

      await tester.tap(_pill(FulfillmentMode.delivery));
      await tester.pumpAndSettle();
      expect(_mode.mode, FulfillmentMode.delivery);
      expect(_chip(ZokyStrings.filterFreeDelivery), findsOneWidget);
      expect(find.text(ZokyStrings.pickupAvailable), findsNothing);
      expect(await _shownIds(tester), {for (final s in _stores) s.id});
    });

    testWidgets('switching to pickup clears the ส่งฟรี filter', (tester) async {
      await _pumpFood(tester, height: 2400);
      await _tapChip(tester, ZokyStrings.filterFreeDelivery);
      _feed(tester).jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(_pill(FulfillmentMode.pickup));
      await tester.pumpAndSettle();
      expect(
        tester.widget<ZokyChip>(_chip(ZokyStrings.filterAll)).selected,
        isTrue,
      );
    });

    testWidgets('pickup drops free-delivery coupons', (tester) async {
      await _pumpFood(tester, height: 2400);
      Set<String> couponIds() => {
        for (final c in tester.widgetList<ZokyFoodCouponCard>(
          find.byType(ZokyFoodCouponCard),
        ))
          c.store.id,
      };
      expect(couponIds(), contains('demo-store-2'));
      await tester.tap(_pill(FulfillmentMode.pickup));
      await tester.pumpAndSettle();
      expect(couponIds(), isNot(contains('demo-store-2')));
      expect(
        couponIds(),
        couponStores(_stores, FulfillmentMode.pickup).map((s) => s.id).toSet(),
      );
    });

    test('applyFilter in pickup keeps pickup stores only', () {
      final shown = FoodHomeScreen.applyFilter(
        _stores,
        StoreFilter.all,
        mode: FulfillmentMode.pickup,
      );
      expect(shown, isNotEmpty);
      expect(shown.every((s) => s.supportsPickup), isTrue);
      expect(
        FoodHomeScreen.filtersFor(FulfillmentMode.pickup),
        isNot(contains(StoreFilter.freeDelivery)),
      );
    });

    test('controller notifies only on change', () {
      final controller = FulfillmentModeController();
      var calls = 0;
      controller.addListener(() => calls++);
      controller.select(FulfillmentMode.delivery);
      expect(calls, 0);
      controller.select(FulfillmentMode.pickup);
      expect(calls, 1);
      expect(controller.isPickup, isTrue);
    });
  });

  group('category row', () {
    testWidgets('first four fill the width; labelled 44pt buttons', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      final items = find.byType(ZokyFoodCategoryItem);
      final first = tester.getRect(items.at(0));
      final fourth = tester.getRect(items.at(3));
      expect(first.left, closeTo(16, 0.5));
      expect(fourth.right, closeTo(390 - 16, 0.5));
      expect(first.width, closeTo(fourth.width, 0.01));
      expect(
        [
          for (var i = 0; i < 4; i++)
            tester.widget<ZokyFoodCategoryItem>(items.at(i)).category.label,
        ],
        ['ตามสั่ง', 'ก๋วยเตี๋ยว', 'อีสาน', 'เครื่องดื่ม'],
      );
      expect(
        tester.getSemantics(items.first),
        isSemantics(isButton: true, label: _categories.first.label),
      );
      expect(first.height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    for (final category in _categories) {
      testWidgets('${category.label} opens the filtered store list', (
        tester,
      ) async {
        await _pumpFood(tester);
        final item = find.byWidgetPredicate(
          (w) => w is ZokyFoodCategoryItem && w.category.id == category.id,
        );
        await tester.scrollUntilVisible(
          item,
          80,
          scrollable: find.descendant(
            of: find.byKey(ZokyFoodCategoryRow.rowKey),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.tap(item);
        await tester.pumpAndSettle();
        final screen = tester.widget<StoreSearchScreen>(
          find.byType(StoreSearchScreen),
        );
        expect(screen.category?.id, category.id);
        expect(screen.autofocus, isFalse);
        expect(_stores.where(category.matches), isNotEmpty);
      });
    }

    testWidgets('failing categories: offline line with retry', (tester) async {
      final content = _FakeContent(fail: true);
      await _pumpFood(tester, content: content);
      expect(find.byKey(ZokyFoodCategoryRow.errorKey), findsOneWidget);
      expect(find.byType(ZokyFoodCategoryItem), findsNothing);
      content.fail = false;
      await tester.tap(
        find.descendant(
          of: find.byKey(ZokyFoodCategoryRow.errorKey),
          matching: find.text(ZokyStrings.retry),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZokyFoodCategoryRow.errorKey), findsNothing);
      expect(find.byType(ZokyFoodCategoryItem), findsWidgets);
    });

    test('matches() compares menu categories case-insensitively', () {
      final fastFood = _categories.firstWhere((c) => c.id == 'fast-food');
      expect(
        fastFood.matches(_stores.firstWhere((s) => s.id == 'demo-store-8')),
        isTrue,
      );
      expect(
        fastFood.matches(_stores.firstWhere((s) => s.id == 'demo-store-2')),
        isFalse,
      );
    });
  });

  group('coupons', () {
    testWidgets('promo stores only, demo labelled, title + see all', (
      tester,
    ) async {
      await _pumpFood(tester, height: 2400);
      expect(find.text(ZokyStrings.couponsTitle), findsOneWidget);
      final cards = tester
          .widgetList<ZokyFoodCouponCard>(find.byType(ZokyFoodCouponCard))
          .toList();
      expect(cards.map((c) => c.store.id).toSet(), {
        for (final s in _stores)
          if (s.hasPromo) s.id,
      });
      expect(cards.every((c) => c.store.isDemo), isTrue);
      expect(
        find.descendant(
          of: find.byType(ZokyFoodCouponCard).first,
          matching: find.text(ZokyStrings.demoBadge),
        ),
        findsOneWidget,
      );
      final withMin = _stores.firstWhere((s) => s.promoMinSubtotal > 0);
      expect(
        ZokyFoodCouponCard.conditionFor(withMin),
        contains('${ZokyStrings.promoMinSubtotal} ฿'),
      );
      await tester.tap(find.bySemanticsLabel(ZokyStrings.seeAllCoupons));
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.couponsSheetTitle), findsOneWidget);
    });

    testWidgets('เก็บโค้ด toggles to เก็บแล้ว and back, kept app-wide', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester, height: 2400);
      final card = find.byType(ZokyFoodCouponCard).first;
      final id = tester.widget<ZokyFoodCouponCard>(card).store.id;
      final button = find.descendant(
        of: card,
        matching: find.byType(ZokyCollectButton),
      );
      expect(
        tester.getSemantics(button),
        isSemantics(
          isButton: true,
          hasToggledState: true,
          isToggled: false,
          label: ZokyStrings.collectCode,
        ),
      );
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(_collected.isCollected(id), isTrue);
      expect(
        find.descendant(
          of: card,
          matching: find.text(ZokyStrings.codeCollected),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(button),
        isSemantics(
          isButton: true,
          hasToggledState: true,
          isToggled: true,
          label: ZokyStrings.codeCollected,
        ),
      );
      // Leaving and reopening the page keeps it (in-memory controller).
      await tester.tap(find.byKey(ZokyFoodHeader.backKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZokyStrings.heroSearchButton));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(ZokyFoodCouponCard).first,
          matching: find.text(ZokyStrings.codeCollected),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(ZokyFoodCouponCard).first,
          matching: find.byType(ZokyCollectButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(_collected.isCollected(id), isFalse);
      semantics.dispose();
    });

    testWidgets('section hidden when no store has a promo', (tester) async {
      await _pumpFood(
        tester,
        stores: _FakeStores([
          for (final s in _stores)
            if (!s.hasPromo) s,
        ]),
      );
      expect(find.byKey(ZokyFoodCouponSection.sectionKey), findsNothing);
      expect(find.text(ZokyStrings.couponsTitle), findsNothing);
      expect(_rows(), findsWidgets);
    });
  });

  group('all stores, chips and filter sheet', () {
    testWidgets('chips in mockup order, ทั้งหมด selected, every store', (
      tester,
    ) async {
      await _pumpFood(tester, height: 2400);
      final chips = tester
          .widgetList<ZokyChip>(
            find.descendant(
              of: find.byKey(FoodHomeScreen.filtersKey),
              matching: find.byType(ZokyChip),
            ),
          )
          .toList();
      expect(chips.map((c) => c.label), [
        ZokyStrings.filterAll,
        ZokyStrings.filterNear,
        ZokyStrings.filterFreeDelivery,
        ZokyStrings.filterPromo,
      ]);
      expect(chips.first.selected, isTrue);
      expect(chips.skip(1).every((c) => !c.selected), isTrue);
      expect(
        chips.every((c) => c.unselectedStyle == ZokyChipUnselectedStyle.filled),
        isTrue,
      );
      expect(await _shownIds(tester), {for (final s in _stores) s.id});
    });

    for (final (label, filter) in [
      (ZokyStrings.filterNear, StoreFilter.near),
      (ZokyStrings.filterFreeDelivery, StoreFilter.freeDelivery),
      (ZokyStrings.filterPromo, StoreFilter.promo),
    ]) {
      testWidgets('$label chip narrows the list like the web', (tester) async {
        await _pumpFood(tester, height: 2400);
        await _tapChip(tester, label);
        final expected = FoodHomeScreen.applyFilter(
          _stores,
          filter,
        ).map((s) => s.id).toSet();
        expect(expected, isNotEmpty);
        expect(await _shownIds(tester), expected);
      });
    }

    testWidgets('ตัวกรอง opens the sheet; เรตติ้ง 4.5+ applies and shows '
        'as a chip', (tester) async {
      await _pumpFood(tester, height: 2400);
      final button = find.byKey(FoodHomeScreen.filterButtonKey);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      await tester.pumpAndSettle();
      for (final f in StoreFilter.values) {
        expect(
          find.text(FoodHomeScreen.labelFor(f)),
          findsWidgets,
          reason: f.name,
        );
      }
      await tester.tap(find.text(ZokyStrings.filterRating).last);
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.filters), findsOneWidget); // sheet closed
      expect(
        tester.widget<ZokyChip>(_chip(ZokyStrings.filterRating)).selected,
        isTrue,
      );
      expect(
        await _shownIds(tester),
        FoodHomeScreen.applyFilter(
          _stores,
          StoreFilter.rating,
        ).map((s) => s.id).toSet(),
      );
    });

    testWidgets('filter sheet in pickup has no ส่งฟรี', (tester) async {
      await _pumpFood(tester);
      await tester.tap(_pill(FulfillmentMode.pickup));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(FoodHomeScreen.filterButtonKey));
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.filterFreeDelivery), findsNothing);
      expect(find.text(ZokyStrings.filterRating), findsOneWidget);
    });

    testWidgets('no match: empty state with ล้างตัวกรอง', (tester) async {
      final far = _stores.where((s) => (s.distanceKm ?? 99) > 3).toList();
      await _pumpFood(tester, height: 2400, stores: _FakeStores(far));
      await _tapChip(tester, ZokyStrings.filterNear);
      expect(find.text(ZokyStrings.noFilteredStores), findsOneWidget);
      await tester.tap(find.text(ZokyStrings.clearFilters));
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.noFilteredStores), findsNothing);
      expect(
        tester.widget<ZokyChip>(_chip(ZokyStrings.filterAll)).selected,
        isTrue,
      );
      expect(_rows(), findsNWidgets(far.length));
    });

    testWidgets('no stores at all: area empty state', (tester) async {
      await _pumpFood(tester, stores: _FakeStores([]));
      expect(find.text(ZokyStrings.noStoresTitle), findsOneWidget);
      expect(find.byKey(ZokyFoodCouponSection.sectionKey), findsNothing);
    });

    test('applyFilter: open first, then nearest', () {
      final all = FoodHomeScreen.applyFilter(_stores, StoreFilter.all);
      expect(all.length, _stores.length);
      final firstClosed = all.indexWhere((s) => !s.isOpen);
      expect(all.skip(firstClosed).every((s) => !s.isOpen), isTrue);
    });
  });

  group('store rows', () {
    testWidgets('demo badge, art instead of the gray placeholder, ดูเมนู', (
      tester,
    ) async {
      await _pumpFood(tester, height: 2400);
      final row = find.byType(ZokyFoodStoreRow).first;
      expect(
        find.descendant(of: row, matching: find.text(ZokyStrings.demoBadge)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text(ZokyStrings.viewMenu)),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.restaurant_rounded), findsNothing);
      final noArt = _stores.firstWhere((s) => s.coverArt == null);
      expect(FoodHomeScreen.fallbackArtFor(noArt, _categories), isNotNull);
      final photo = ZokyFoodStoreRow.photoSize(390);
      expect(photo, closeTo(109.2, 0.1));
    });

    testWidgets('closed / ad / promo labels stay readable', (tester) async {
      await _pumpFood(tester, height: 2400);
      await _shownIds(tester); // build all rows once
      _feed(tester).jumpTo(0);
      await tester.pumpAndSettle();
      final labels = <String>[];
      for (var i = 0; i < 15; i++) {
        for (final e in find.byType(Text).evaluate()) {
          final data = (e.widget as Text).data;
          if (data != null) labels.add(data);
        }
        _feed(tester).jumpTo(_feed(tester).pixels + 300);
        await tester.pumpAndSettle();
      }
      expect(labels, contains(ZokyStrings.closedLabel));
      expect(labels, contains(ZokyStrings.adLabel));
      expect(labels, contains('ลด 20%'));
    });

    testWidgets('row tap opens the store page', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester, height: 2400);
      final row = _rows().first;
      final store = tester.widget<ZokyFoodStoreRow>(row).store;
      expect(tester.getSemantics(row), isSemantics(isButton: true));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        tester.widget<StoreScreen>(find.byType(StoreScreen)).store.id,
        store.id,
      );
      semantics.dispose();
    });
  });

  group('sticky header and chips', () {
    testWidgets('header folds to a full-bleed blush bar with the search '
        'field; chips pin under it', (tester) async {
      await _pumpFood(
        tester,
        width: 430,
        height: 932,
        topInset: 59,
        bottomInset: 34,
      );
      final openCard = tester.getRect(find.byKey(ZokyFoodHeader.surfaceKey));
      _feed(tester).jumpTo(400);
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byKey(ZokyFoodHeader.surfaceKey));
      final search = tester.getRect(_searchField());
      expect(card.top, 0);
      expect(card.left, 0);
      expect(card.right, 430);
      expect(card.height, lessThan(openCard.height));
      expect(search.top, greaterThanOrEqualTo(59));
      expect(search.bottom, lessThanOrEqualTo(card.bottom));
      // Collapsed: the bar still ends on white under the search field.
      final gradient =
          (tester
                          .widget<DecoratedBox>(
                            find.byKey(ZokyFoodHeader.surfaceKey),
                          )
                          .decoration
                      as BoxDecoration)
                  .gradient!
              as LinearGradient;
      expect(gradient.colors.last, const Color(0xFFFFFFFF));
      expect(
        card.top + gradient.stops!.last * card.height,
        closeTo(search.center.dy, 0.5),
      );
      expect(find.byKey(ZokyFoodHeader.backKey).hitTestable(), findsNothing);
      expect(_pill(FulfillmentMode.pickup).hitTestable(), findsNothing);
      await tester.tap(_searchField());
      await tester.pumpAndSettle();
      expect(find.byType(StoreSearchScreen), findsOneWidget);
      await tester.tap(find.byTooltip(ZokyStrings.back));
      await tester.pumpAndSettle();

      final position = _feed(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final chips = tester.getRect(find.byKey(FoodHomeScreen.filtersKey));
      final pinnedCard = tester.getRect(find.byKey(ZokyFoodHeader.surfaceKey));
      expect(chips.top, greaterThan(pinnedCard.bottom - 1));
      expect(chips.top, lessThan(pinnedCard.bottom + 24));
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.byKey(ZokyFoodHeader.backKey).hitTestable(), findsOneWidget);
      expect(_pill(FulfillmentMode.pickup).hitTestable(), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('skeletons while loading', (tester) async {
      setPhoneViewport(tester);
      final stores = _FakeStores(_stores, latency: const Duration(seconds: 2));
      _mode = FulfillmentModeController();
      await tester.pumpWidget(
        ZokyApp(
          config: AppConfig.demo,
          storeRepository: stores,
          promotionRepository: const DemoPromotionRepository(),
          homeContentRepository: const DemoHomeContentRepository(),
          deliveryAddresses: DeliveryAddressController(
            const DemoAddressRepository(),
          ),
          fulfillmentMode: _mode,
          collectedPromos: CollectedPromosController(),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.tap(find.text(ZokyStrings.heroSearchButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(ZokyFoodCouponSection.skeletonKey), findsOneWidget);
      expect(_rows(), findsNothing);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(ZokyFoodCouponSection.skeletonKey), findsNothing);
      expect(_rows(), findsWidgets);
    });

    testWidgets('directory error: offline copy, retry reloads', (tester) async {
      final stores = _FakeStores(_stores, fail: true);
      await _pumpFood(tester, stores: stores);
      expect(find.text(ZokyStrings.offlineTitle), findsOneWidget);
      expect(find.text(ZokyStrings.offlineBody), findsOneWidget);
      expect(find.byKey(ZokyFoodCouponSection.sectionKey), findsNothing);
      stores.fail = false;
      final retry = find.descendant(
        of: find.byType(ZokyStateView),
        matching: find.text(ZokyStrings.retry),
      );
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.offlineTitle), findsNothing);
      expect(_rows(), findsWidgets);
    });

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      testWidgets('pull to refresh reloads all sections (${platform.name})', (
        tester,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        final stores = _FakeStores(_stores);
        final content = _FakeContent();
        await _pumpFood(tester, stores: stores, content: content);
        final before = (stores.directoryCalls, content.categoryCalls);
        await tester.fling(
          find.byType(ZokyFoodCategoryRow),
          const Offset(0, 400),
          1000,
        );
        await tester.pumpAndSettle();
        expect(stores.directoryCalls, before.$1 + 1);
        expect(content.categoryCalls, before.$2 + 1);
        expect(_rows(), findsWidgets);
        debugDefaultTargetPlatformOverride = null;
      });
    }
  });

  group('floating cart button', () {
    testWidgets('empty circle, labelled, opens the cart placeholder', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester, width: 430, height: 932, bottomInset: 34);
      final fab = find.byKey(FoodHomeScreen.cartKey);
      final rect = tester.getRect(fab);
      expect(rect.width, ZokyFoodCartButton.height);
      expect(rect.height, ZokyFoodCartButton.height);
      expect(rect.right, 430 - 16);
      expect(rect.bottom, lessThanOrEqualTo(932 - 34));
      expect(
        tester.getSemantics(fab),
        isSemantics(isButton: true, label: ZokyStrings.cart),
      );
      await tester.tap(fab);
      await tester.pump();
      expect(find.text(ZokyStrings.demoCartPending), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('never covers the last row', (tester) async {
      await _pumpFood(tester, width: 430, height: 932, bottomInset: 34);
      expect(find.byType(ZokyBottomNav).hitTestable(), findsNothing);
      await _jumpToEnd(tester);
      final last = tester.getRect(_rows().last);
      final fab = tester.getRect(find.byKey(FoodHomeScreen.cartKey));
      expect(last.bottom, lessThanOrEqualTo(fab.top));
    });

    testWidgets('with items: pill with count and total', (tester) async {
      await pumpZokyWidget(
        tester,
        Center(
          child: ZokyFoodCartButton(itemCount: 3, total: 245, onPressed: () {}),
        ),
      );
      expect(find.text('3 · ฿245'), findsOneWidget);
      final size = tester.getSize(find.byType(ZokyFoodCartButton));
      expect(size.height, ZokyFoodCartButton.height);
      expect(size.width, greaterThan(ZokyFoodCartButton.height));
      expect(tester.takeException(), isNull);
    });
  });

  group('layout', () {
    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets('no overflow at ${width.toInt()}pt x $scale', (
          tester,
        ) async {
          await _pumpFood(
            tester,
            width: width,
            height: 2400,
            textScale: scale,
            topInset: 59,
            bottomInset: 34,
          );
          expect(tester.takeException(), isNull);
          // Compact chips stay on screen in both modes.
          expect(
            tester.getRect(find.byType(ZokyFoodModeToggle)).right,
            lessThanOrEqualTo(width - 16),
          );
          final position = _feed(tester);
          await _jumpToEnd(tester);
          expect(tester.takeException(), isNull);
          // FAB never covers the last row.
          final last = tester.getRect(_rows().last);
          final fab = tester.getRect(find.byKey(FoodHomeScreen.cartKey));
          expect(last.bottom, lessThanOrEqualTo(fab.top));
          position.jumpTo(0);
          await tester.pumpAndSettle();
          // Header row inside the screen.
          expect(
            tester.getRect(find.byKey(ZokyFoodHeader.couponsKey)).right,
            lessThanOrEqualTo(width),
          );
          // Pickup mode.
          await tester.tap(_pill(FulfillmentMode.pickup));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(_pill(FulfillmentMode.delivery));
          await tester.pumpAndSettle();
          // Sheets.
          await tester.tap(find.byKey(FoodHomeScreen.filterButtonKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ZokyFoodHeader.couponsKey));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();
          await tester.tap(_addressButton());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  testWidgets('dependencies expose the mode and collected controllers', (
    tester,
  ) async {
    await _pumpFood(tester);
    final context = tester.element(find.byType(FoodHomeScreen));
    final deps = AppDependencies.of(context);
    expect(deps.fulfillmentMode, same(_mode));
    expect(deps.collectedPromos, same(_collected));
  });

  group('ZOKY-131 low-severity fixes', () {
    testWidgets('an older directory response never overwrites a newer one', (
      tester,
    ) async {
      final stores = _ManualStores();
      await _pumpFood(tester, stores: stores);
      expect(find.text(ZokyStrings.offlineTitle), findsOneWidget);
      // Retry: skeletons while loading (call 1 pending).
      await tester.tap(find.text(ZokyStrings.retry));
      await tester.pump();
      expect(find.text(ZokyStrings.offlineTitle), findsNothing);
      expect(stores.pending, hasLength(2));
      // Pull to refresh during the retry (call 2).
      await tester.fling(
        find.byKey(FoodHomeScreen.allStoresKey),
        const Offset(0, 500),
        1200,
      );
      for (var i = 0; i < 20 && stores.pending.length < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(stores.pending, hasLength(3));
      stores.pending[2].complete([_stores.first]);
      await tester.pump();
      stores.pending[1].complete(_stores);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_rows(), findsOneWidget);
    });

    testWidgets('pickup store page hides the delivery fee', (tester) async {
      await _pumpFood(tester);
      Future<void> openFirst() async {
        final row = _rows().first;
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        expect(find.byType(StoreScreen), findsOneWidget);
      }

      final fee = find.textContaining(ZokyStrings.deliveryFee);
      await openFirst();
      expect(fee, findsOneWidget);
      await tester.tap(find.byTooltip(ZokyStrings.back));
      await tester.pumpAndSettle();
      _feed(tester).jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(_pill(FulfillmentMode.pickup));
      await tester.pumpAndSettle();
      await openFirst();
      expect(fee, findsNothing);
    });

    for (final scale in [1.0, 1.3]) {
      for (final mode in FulfillmentMode.values) {
        testWidgets('cart button never covers "เก็บโค้ด" at 320x568 x$scale '
            '(${mode.name})', (tester) async {
          await _pumpFood(
            tester,
            width: 320,
            height: 568,
            textScale: scale,
            topInset: 20,
          );
          if (mode == FulfillmentMode.pickup) {
            await tester.tap(_pill(mode));
            await tester.pumpAndSettle();
          }
          final fab = tester.getRect(find.byKey(FoodHomeScreen.cartKey));
          for (final e in find.byType(ZokyCollectButton).evaluate()) {
            final r = tester.getRect(find.byWidget(e.widget));
            expect(r.overlaps(fab), isFalse, reason: '$r under $fab');
          }
        });
      }
    }

    for (final (width, scale) in [(320.0, 1.3), (375.0, 2.0)]) {
      testWidgets('category labels stay one unbroken line at '
          '${width.toInt()}pt x$scale', (tester) async {
        await _pumpFood(tester, width: width, textScale: scale);
        for (final c in _categories) {
          final label = find.descendant(
            of: find.byKey(ZokyFoodCategoryRow.rowKey),
            matching: find.text(c.label),
          );
          final p = tester.renderObject<RenderParagraph>(label);
          // One line high (no break inside the word).
          final style = p.text.style!;
          final line = p.textScaler.scale(style.fontSize!) * style.height!;
          expect(p.size.height, lessThan(line * 1.5), reason: c.label);
          expect(p.didExceedMaxLines, isFalse, reason: c.label);
        }
      });
    }
  });
}

/// Directory stub: the first call fails at once, later calls wait for the
/// test to complete them ([pending]).
class _ManualStores implements StoreRepository {
  final pending = <Completer<List<ZokyStoreSummary>>>[];

  @override
  Future<List<ZokyStoreSummary>> fetchDirectory({String query = ''}) {
    final call = Completer<List<ZokyStoreSummary>>();
    pending.add(call);
    if (pending.length == 1) call.completeError(StateError('offline'));
    return call.future;
  }

  @override
  Future<List<ZokyStoreSummary>> fetchRecommended() async => const [];

  @override
  Future<List<ZokyMenuItem>> fetchMenu(String storeId) async => const [];
}
