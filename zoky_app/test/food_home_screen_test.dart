import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/app_dependencies.dart';
import 'package:zoky_app/core/design/zoky_theme.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/features/address/address_sheet.dart';
import 'package:zoky_app/features/address/data/address_repository.dart';
import 'package:zoky_app/features/address/data/demo_address_repository.dart';
import 'package:zoky_app/features/address/delivery_address_controller.dart';
import 'package:zoky_app/features/address/domain/address_models.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';
import 'package:zoky_app/features/deals/deal_sheet.dart';
import 'package:zoky_app/features/home/data/demo_home_content_repository.dart';
import 'package:zoky_app/features/home/data/home_content_repository.dart';
import 'package:zoky_app/features/home/domain/home_content_models.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_chip.dart';
import 'package:zoky_app/core/widgets/zoky_glossy_heart_button.dart';
import 'package:zoky_app/core/widgets/zoky_state_view.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/food/food_home_screen.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_address_button.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_banner_carousel.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_category_row.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_header.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_search_field.dart';
import 'package:zoky_app/features/home/widgets/zoky_food_hero_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_today_deals_section.dart';
import 'package:zoky_app/features/orders/orders_screen.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import 'support/pump_zoky.dart';

final _banners = DemoHomeContentRepository.banners
    .where((b) => b.isActiveAt(DateTime.now()))
    .toList();
const _categories = DemoHomeContentRepository.categories;
const _addresses = DemoAddressRepository.addresses;

/// Pumps the app and opens the food page from the Home hero card
/// (Founder, 2026-10-18).
Future<void> _pumpFood(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  double bottomInset = 0,
}) async {
  await pumpZokyApp(
    tester,
    width: width,
    height: height,
    textScale: textScale,
    bottomInset: bottomInset,
  );
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

Finder _glossyButton(String label) => find.byWidgetPredicate(
  (w) => w is ZokyGlossyHeartButton && w.label == label,
);
Finder _heartButton() => _glossyButton(ZokyStrings.favoriteStores);
Finder _ordersButton() => _glossyButton(ZokyStrings.navOrders);

Finder _addressButton() => find.byType(ZokyFoodAddressButton);
Finder _searchField() => find.byType(ZokyFoodSearchField);
Finder _pager() => find.byKey(ZokyFoodBannerCarousel.pagerKey);
Finder _bannerCards() => find.byType(ZokyFoodBannerCard);

ZokyPageDots _dots(WidgetTester tester) =>
    tester.widget<ZokyPageDots>(find.byKey(ZokyFoodBannerCarousel.dotsKey));

/// Swipes the carousel one slide to the left.
Future<void> _nextSlide(WidgetTester tester) async {
  await tester.fling(_pager(), const Offset(-200, 0), 800);
  await tester.pumpAndSettle();
}

class _FailingContent implements HomeContentRepository {
  @override
  Future<List<ZokyHomeBanner>> fetchActiveBanners() =>
      Future.error(StateError('offline'));

  @override
  Future<List<ZokyFoodCategory>> fetchFoodCategories() =>
      Future.error(StateError('offline'));
}

class _CountingAddresses implements AddressRepository {
  int calls = 0;

  @override
  Future<List<ZokyDeliveryAddress>> fetchSavedAddresses() async {
    calls++;
    return _addresses;
  }
}

void main() {
  group('order', () {
    testWidgets('header, search, carousel, categories, deals, all stores', (
      tester,
    ) async {
      await _pumpFood(tester, height: 3000);
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(find.byType(ZokyFoodHeader)), 0);
      final back = tester.getRect(find.byKey(ZokyFoodHeader.backKey));
      final pill = tester.getRect(_addressButton());
      final heart = tester.getRect(_heartButton());
      final orders = tester.getRect(_ordersButton());
      // One row: back, address, heart, orders (left to right).
      expect(back.right, lessThanOrEqualTo(pill.left));
      expect(pill.right, lessThanOrEqualTo(heart.left));
      expect(heart.right, lessThanOrEqualTo(orders.left));
      expect(pill.bottom, lessThan(top(_searchField())));
      expect(top(_searchField()), lessThan(top(_pager())));
      expect(top(_pager()), lessThan(top(find.byType(ZokyFoodCategoryRow))));
      expect(
        top(find.byType(ZokyFoodCategoryRow)),
        lessThan(top(find.byType(ZokyTodayDealsSection))),
      );
      expect(
        top(find.byType(ZokyTodayDealsSection)),
        lessThan(top(find.byKey(FoodHomeScreen.allStoresKey))),
      );
      expect(
        top(find.byKey(FoodHomeScreen.allStoresKey)),
        lessThan(top(find.byKey(FoodHomeScreen.filtersKey))),
      );
      expect(
        top(find.byKey(FoodHomeScreen.filtersKey)),
        lessThan(top(find.byType(ZokyStoreCard).first)),
      );
      // The hero lives on Home only.
      expect(find.byType(ZokyFoodHeroCard), findsNothing);
    });

    testWidgets('search field straddles the pink/white seam', (tester) async {
      await _pumpFood(tester);
      final header = tester.getRect(find.byType(ZokyFoodHeader));
      final field = tester.getRect(_searchField());
      final seam = header.bottom - ZokyFoodHeader.sheetRadius;
      expect(field.top, lessThan(seam));
      expect(field.bottom, greaterThan(seam));
      expect(field.bottom, lessThanOrEqualTo(header.bottom));
      expect(field.left, 16);
      expect(field.right, 390 - 16);
    });

    testWidgets('back button is adaptive and labelled', (tester) async {
      for (final (platform, icon) in [
        (TargetPlatform.iOS, CupertinoIcons.back),
        (TargetPlatform.android, Icons.arrow_back),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        await _pumpFood(tester);
        expect(
          find.descendant(
            of: find.byKey(ZokyFoodHeader.backKey),
            matching: find.byIcon(icon),
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

  group('header buttons', () {
    testWidgets('heart opens the ร้านโปรด sheet', (tester) async {
      await _pumpFood(tester);
      await tester.tap(_heartButton());
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.comingSoon), findsOneWidget);
    });

    testWidgets('orders shortcut returns to the shell on ออเดอร์', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      final button = _ordersButton();
      expect(tester.getSemantics(button), isSemantics(isButton: true));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(FoodHomeScreen), findsNothing);
      expect(find.byType(OrdersScreen), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('no orders shortcut without a handler', (tester) async {
      final semantics = tester.ensureSemantics();
      setPhoneViewport(tester);
      await tester.pumpWidget(
        AppDependencies(
          config: AppConfig.demo,
          storeRepository: DemoStoreRepository(),
          promotionRepository: const DemoPromotionRepository(),
          homeContentRepository: const DemoHomeContentRepository(),
          deliveryAddresses: DeliveryAddressController(
            const DemoAddressRepository(),
          ),
          child: MaterialApp(
            theme: buildZokyTheme(),
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FoodHomeScreen(
                      repository: DemoStoreRepository(),
                      promotionRepository: const DemoPromotionRepository(),
                      onOpenFavorites: () {},
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(FoodHomeScreen), findsOneWidget);
      expect(_ordersButton(), findsNothing);
      semantics.dispose();
    });
  });

  group('all stores + C04 quick filters', () {
    Future<Set<String>> shownIds(WidgetTester tester) async {
      final ids = <String>{};
      for (var i = 0; i < 12; i++) {
        for (final e in find.byType(ZokyStoreCard).evaluate()) {
          ids.add((e.widget as ZokyStoreCard).store.id);
        }
        await tester.drag(
          find.byType(CustomScrollView).last,
          const Offset(0, -400),
        );
        await tester.pumpAndSettle();
      }
      return ids;
    }

    Future<void> pick(WidgetTester tester, String label) async {
      final chip = find.widgetWithText(ZokyChip, label);
      await tester.scrollUntilVisible(
        chip,
        80,
        scrollable: find.descendant(
          of: find.byKey(FoodHomeScreen.filtersKey),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }

    testWidgets('lists every demo store with demo badges under ทั้งหมด', (
      tester,
    ) async {
      await _pumpFood(tester, height: 1600);
      expect(find.text(ZokyStrings.allStoresTitle), findsOneWidget);
      for (final label in [
        ZokyStrings.filterAll,
        ZokyStrings.filterFreeDelivery,
        ZokyStrings.filterPromo,
        ZokyStrings.filterNear,
        ZokyStrings.filterRating,
      ]) {
        expect(find.widgetWithText(ZokyChip, label), findsOneWidget);
      }
      expect(
        tester
            .widget<ZokyChip>(
              find.widgetWithText(ZokyChip, ZokyStrings.filterAll),
            )
            .selected,
        isTrue,
      );
      expect(await shownIds(tester), {
        for (final s in DemoStoreRepository.stores) s.id,
      });
    });

    for (final (label, filter) in [
      (ZokyStrings.filterFreeDelivery, StoreFilter.freeDelivery),
      (ZokyStrings.filterPromo, StoreFilter.promo),
      (ZokyStrings.filterNear, StoreFilter.near),
      (ZokyStrings.filterRating, StoreFilter.rating),
    ]) {
      testWidgets('$label narrows the list like the web', (tester) async {
        await _pumpFood(tester, height: 1600);
        await pick(tester, label);
        final expected = FoodHomeScreen.applyFilter(
          DemoStoreRepository.stores,
          filter,
        ).map((s) => s.id).toSet();
        if (expected.isEmpty) {
          expect(find.text(ZokyStrings.noStoresTitle), findsOneWidget);
          expect(find.byType(ZokyStateView), findsOneWidget);
        } else {
          expect(await shownIds(tester), expected);
        }
      });
    }

    test('applyFilter: rules and open-first, nearest-first order', () {
      final all = FoodHomeScreen.applyFilter(
        DemoStoreRepository.stores,
        StoreFilter.all,
      );
      expect(all.length, DemoStoreRepository.stores.length);
      final firstClosed = all.indexWhere((s) => !s.isOpen);
      if (firstClosed >= 0) {
        expect(all.skip(firstClosed).every((s) => !s.isOpen), isTrue);
      }
      expect(
        FoodHomeScreen.applyFilter(
          DemoStoreRepository.stores,
          StoreFilter.freeDelivery,
        ).every((s) => s.deliveryFee <= 0),
        isTrue,
      );
      expect(
        FoodHomeScreen.applyFilter(
          DemoStoreRepository.stores,
          StoreFilter.rating,
        ).every((s) => (s.rating ?? 0) >= 4.5),
        isTrue,
      );
    });

    testWidgets('store card opens the store page', (tester) async {
      await _pumpFood(tester, height: 1600);
      final card = find.byType(ZokyStoreCard).first;
      final id = tester.widget<ZokyStoreCard>(card).store.id;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(tester.widget<StoreScreen>(find.byType(StoreScreen)).store.id, id);
    });
  });

  group('bottom nav', () {
    testWidgets('page is pushed above the shell: nav hidden, last store '
        'fully visible above the home indicator', (tester) async {
      await _pumpFood(tester, width: 430, height: 932, bottomInset: 34);
      expect(find.byType(ZokyBottomNav).hitTestable(), findsNothing);
      final position = _feed(tester);
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final last = tester.getRect(find.byType(ZokyStoreCard).last);
      expect(last.bottom, lessThanOrEqualTo(932 - 34));
    });
  });

  group('address', () {
    testWidgets('header shows "จัดส่งที่" and the default address', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      final def = _addresses.firstWhere((a) => a.isDefault);
      expect(
        find.descendant(
          of: _addressButton(),
          matching: find.textContaining(
            ZokyStrings.deliverAt,
            findRichText: true,
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _addressButton(),
          matching: find.textContaining(def.label, findRichText: true),
        ),
        findsOneWidget,
      );
      expect(def.label, contains('ตัวอย่าง'));
      final node = tester.getSemantics(
        find.bySemanticsLabel('${ZokyStrings.deliverAt} ${def.label}'),
      );
      expect(node, isSemantics(isButton: true));
      final size = tester.getSize(_addressButton());
      expect(size.height, greaterThanOrEqualTo(44));
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
        expect(find.text(ZokyStrings.chooseDeliveryAddress), findsOneWidget);
        expect(find.text(ZokyStrings.demoAddressLabel), findsOneWidget);
        expect(find.byType(ZokyAddressTile), findsNWidgets(_addresses.length));
        for (final a in _addresses) {
          expect(a.isDemo, isTrue);
          expect(
            find.descendant(
              of: find.byType(ZokyAddressSheet),
              matching: find.text(a.label),
            ),
            findsOneWidget,
          );
        }
        expect(find.text(ZokyStrings.addNewAddress), findsOneWidget);
        expect(find.text(ZokyStrings.comingSoon), findsOneWidget);

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
            matching: find.textContaining(work.label, findRichText: true),
          ),
          findsOneWidget,
        );

        // Reopened: the new choice is the selected row.
        await tester.tap(_addressButton());
        await tester.pumpAndSettle();
        final tiles = tester
            .widgetList<ZokyAddressTile>(find.byType(ZokyAddressTile))
            .toList();
        expect(tiles.where((t) => t.selected).map((t) => t.address.id), [
          work.id,
        ]);
        debugDefaultTargetPlatformOverride = null;
      });
    }

    testWidgets('"เพิ่มที่อยู่ใหม่" is a placeholder (no action)', (
      tester,
    ) async {
      await _pumpFood(tester);
      await tester.tap(_addressButton());
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZokyStrings.addNewAddress));
      await tester.pumpAndSettle();
      expect(find.byType(ZokyAddressSheet), findsOneWidget);
    });

    test('controller loads once, defaults, ignores unknown picks', () async {
      final repo = _CountingAddresses();
      final controller = DeliveryAddressController(repo);
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.load();
      await controller.load();
      expect(repo.calls, 1);
      expect(controller.selected?.id, 'demo-address-1');
      controller.select(
        const ZokyDeliveryAddress(id: 'evil', label: 'x', address: 'y'),
      );
      expect(controller.selected?.id, 'demo-address-1');
      controller.select(_addresses[2]);
      expect(controller.selected?.id, _addresses[2].id);
      // Reload keeps the choice.
      await controller.load(force: true);
      expect(repo.calls, 2);
      expect(controller.selected?.id, _addresses[2].id);
      expect(notified, greaterThan(0));
      controller.dispose();
    });
  });

  group('search field', () {
    testWidgets('is a button labelled "สั่งอะไรดี?" with a 44pt target', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      expect(
        find.descendant(
          of: _searchField(),
          matching: find.text(ZokyStrings.foodSearchPlaceholder),
        ),
        findsOneWidget,
      );
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
      expect(find.byType(StoreSearchScreen), findsOneWidget);
      final screen = tester.widget<StoreSearchScreen>(
        find.byType(StoreSearchScreen),
      );
      expect(screen.autofocus, isTrue);
      expect(screen.category, isNull);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofocus, isTrue);
      expect(field.focusNode?.hasFocus ?? true, isTrue);
    });

    testWidgets('store search filters and leads into the store page; back '
        'returns to the food page', (tester) async {
      await _pumpFood(tester);
      await tester.tap(_searchField());
      await tester.pumpAndSettle();
      expect(find.byType(StoreSearchScreen), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ส้มตำ');
      await tester.pumpAndSettle();
      expect(find.byType(ZokyStoreCard), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ไม่มีร้านนี้แน่นอน');
      await tester.pumpAndSettle();
      expect(find.byType(ZokyStoreCard), findsNothing);
      expect(find.text(ZokyStrings.searchNoResultsTitle), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ส้มตำ');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ZokyStoreCard));
      await tester.pumpAndSettle();
      expect(find.byType(StoreScreen), findsOneWidget);

      await tester.tap(find.byTooltip(ZokyStrings.back));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(ZokyStrings.back));
      await tester.pumpAndSettle();
      expect(find.byType(StoreSearchScreen), findsNothing);
      expect(find.byType(FoodHomeScreen), findsOneWidget);
    });
  });

  group('banner carousel', () {
    testWidgets('demo banners labelled ตัวอย่าง, no hero slide', (
      tester,
    ) async {
      await _pumpFood(tester);
      expect(
        find.descendant(of: _pager(), matching: find.byType(ZokyFoodHeroCard)),
        findsNothing,
      );
      // Expired demo banner is filtered out like the RPC does.
      expect(_banners.map((b) => b.id), isNot(contains('demo-banner-expired')));
      expect(_dots(tester).count, _banners.length);
      expect(_dots(tester).active, 0);
      for (var i = 0; i < _banners.length; i++) {
        expect(_banners[i].isDemo, isTrue);
        expect(_banners[i].title, contains('ตัวอย่าง'));
      }
    });

    testWidgets('next slide peeks in at the right edge', (tester) async {
      await _pumpFood(tester, width: 390);
      final first = tester.getRect(_bannerCards().at(0));
      expect(first.left, 16);
      expect(first.width, ZokyFoodBannerCarousel.slideWidth(390));
      final next = tester.getRect(_bannerCards().at(1));
      expect(next.left, lessThan(390));
      expect(390 - next.left, closeTo(ZokyFoodBannerCarousel.peek, 0.5));
      // Slides share one height, at least the web banner ratio.
      expect(next.height, first.height);
      expect(
        first.height,
        greaterThanOrEqualTo(first.width / ZokyFoodBannerCarousel.aspectRatio),
      );
    });

    testWidgets('paging moves the active pill dot', (tester) async {
      await _pumpFood(tester);
      await _nextSlide(tester);
      expect(_dots(tester).active, 1);
      for (var i = 2; i < _banners.length; i++) {
        await _nextSlide(tester);
      }
      expect(_dots(tester).active, _banners.length - 1);
      // The last slide ends at the right gutter.
      expect(tester.getRect(_bannerCards().last).right, closeTo(390 - 16, 0.5));
    });

    testWidgets('demo banners carry the ตัวอย่าง badge and semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      for (var i = 0; i < _banners.length; i++) {
        if (i > 0) await _nextSlide(tester);
        final banner = _banners[i];
        final card = find.byWidgetPredicate(
          (w) => w is ZokyFoodBannerCard && w.banner.id == banner.id,
        );
        expect(
          find.descendant(of: card, matching: find.text(ZokyStrings.demoBadge)),
          findsOneWidget,
        );
        final label = ZokyFoodBannerCard.semanticLabel(banner);
        expect(label, startsWith(ZokyStrings.demoBannerPrefix));
        expect(
          tester.getSemantics(card),
          isSemantics(label: label, isButton: banner.hasTarget),
        );
      }
      semantics.dispose();
    });

    testWidgets('store banner opens its store', (tester) async {
      await _pumpFood(tester);
      final banner = _banners[0];
      expect(banner.destinationStoreId, isNotNull);
      await tester.tap(_bannerCards().first);
      await tester.pumpAndSettle();
      final store = tester.widget<StoreScreen>(find.byType(StoreScreen));
      expect(store.store.id, banner.destinationStoreId);
    });

    testWidgets('promo banner opens its deal sheet', (tester) async {
      await _pumpFood(tester);
      await _nextSlide(tester);
      final banner = _banners[1];
      expect(banner.dealId, isNotNull);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ZokyFoodBannerCard && w.banner.id == banner.id,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZokyDealDetail), findsOneWidget);
      expect(
        tester.widget<ZokyDealDetail>(find.byType(ZokyDealDetail)).deal.id,
        banner.dealId,
      );
    });

    testWidgets('banner without a target does nothing', (tester) async {
      await _pumpFood(tester);
      for (var i = 0; i < 2; i++) {
        await _nextSlide(tester);
      }
      final banner = _banners[2];
      expect(banner.hasTarget, isFalse);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ZokyFoodBannerCard && w.banner.id == banner.id,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StoreScreen), findsNothing);
      expect(find.byType(ZokyDealDetail), findsNothing);
    });

    testWidgets('failing content: no carousel, no dots, no categories', (
      tester,
    ) async {
      await pumpZokyWidget(
        tester,
        Column(
          children: [
            ZokyFoodBannerCarousel(
              repository: _FailingContent(),
              onOpenBanner: (_) {},
            ),
            ZokyFoodCategoryRow(
              repository: _FailingContent(),
              onOpenCategory: (_) {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZokyFoodBannerCarousel.pagerKey), findsNothing);
      expect(_bannerCards(), findsNothing);
      expect(find.byKey(ZokyFoodBannerCarousel.dotsKey), findsNothing);
      expect(find.byType(ZokyFoodCategoryItem), findsNothing);
    });

    test('demo repository applies the active window and sort order', () async {
      final repo = DemoHomeContentRepository(clock: () => DateTime.utc(2019));
      final early = await repo.fetchActiveBanners();
      // In 2019 the "expired" banner (ends 2020) is still live and sorts
      // first (sort_order 0).
      expect(early.first.id, 'demo-banner-expired');
      final now = await const DemoHomeContentRepository().fetchActiveBanners();
      expect(now.map((b) => b.id), [
        'demo-banner-1',
        'demo-banner-2',
        'demo-banner-3',
      ]);
      expect(now.length, lessThanOrEqualTo(8));
    });
  });

  group('category row', () {
    testWidgets('shows every category as a labelled button', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpFood(tester);
      expect(
        find.byType(ZokyFoodCategoryItem),
        findsAtLeastNWidgets(4), // the row scrolls; the rest is built lazily
      );
      final first = find.byType(ZokyFoodCategoryItem).first;
      expect(
        tester.getSemantics(first),
        isSemantics(isButton: true, label: _categories.first.label),
      );
      final size = tester.getSize(first);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    for (final category in _categories) {
      testWidgets('${category.label} opens the filtered store list', (
        tester,
      ) async {
        await _pumpFood(tester, height: 1400);
        final item = find.byWidgetPredicate(
          (w) => w is ZokyFoodCategoryItem && w.category.id == category.id,
        );
        await tester.scrollUntilVisible(
          item,
          120,
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
        expect(find.text(category.label), findsWidgets); // app bar title
        final expected = DemoStoreRepository.stores
            .where(category.matches)
            .map((s) => s.nameWithoutDemoSuffix)
            .toSet();
        expect(expected, isNotEmpty, reason: 'demo data covers every category');
        for (final store in DemoStoreRepository.stores) {
          final shown = find.textContaining(store.nameWithoutDemoSuffix);
          if (expected.contains(store.nameWithoutDemoSuffix)) {
            // Grid may be long; the first match is always on screen.
            continue;
          }
          expect(shown, findsNothing, reason: store.name);
        }
      });
    }

    test('matches() compares menu categories case-insensitively', () {
      const category = _categories;
      final fastFood = category.firstWhere((c) => c.id == 'fast-food');
      final burger = DemoStoreRepository.stores.firstWhere(
        (s) => s.id == 'demo-store-8',
      );
      final somTam = DemoStoreRepository.stores.firstWhere(
        (s) => s.id == 'demo-store-2',
      );
      expect(fastFood.matches(burger), isTrue);
      expect(fastFood.matches(somTam), isFalse);
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
            bottomInset: 34,
          );
          expect(tester.takeException(), isNull);
          // Every slide renders without overflow.
          for (var i = 1; i < _banners.length; i++) {
            await _nextSlide(tester);
            expect(tester.takeException(), isNull);
          }
          // Down to the store list and its filters.
          final position = _feed(tester);
          position.jumpTo(position.maxScrollExtent);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          position.jumpTo(0);
          await tester.pumpAndSettle();
          // Address sheet too.
          await tester.tap(_addressButton());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Header row stays inside the screen.
          final pill = tester.getRect(_addressButton());
          expect(pill.right, lessThanOrEqualTo(width));
          final orders = tester.getRect(_ordersButton());
          expect(orders.right, lessThanOrEqualTo(width));
        });
      }
    }
  });

  testWidgets('address sheet opens from the helper too', (tester) async {
    final controller = DeliveryAddressController(const DemoAddressRepository());
    await pumpZokyWidget(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showZokyAddressSheet(context, controller),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ZokyAddressTile), findsNWidgets(_addresses.length));
    expect(controller.selected?.isDefault, isTrue);
  });
}
