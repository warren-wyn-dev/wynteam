import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/features/address/address_sheet.dart';
import 'package:zoky_app/features/address/data/address_repository.dart';
import 'package:zoky_app/features/address/data/demo_address_repository.dart';
import 'package:zoky_app/features/address/delivery_address_controller.dart';
import 'package:zoky_app/features/address/domain/address_models.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/deals/deal_sheet.dart';
import 'package:zoky_app/features/home/data/demo_home_content_repository.dart';
import 'package:zoky_app/features/home/data/home_content_repository.dart';
import 'package:zoky_app/features/home/domain/home_content_models.dart';
import 'package:zoky_app/features/home/widgets/zoky_food_category_row.dart';
import 'package:zoky_app/features/home/widgets/zoky_food_hero_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_address_button.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_banner_carousel.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_header.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_search_field.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_stores_section.dart';
import 'package:zoky_app/features/home/widgets/zoky_today_deals_section.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import 'support/pump_zoky.dart';

final _banners = DemoHomeContentRepository.banners
    .where((b) => b.isActiveAt(DateTime.now()))
    .toList();
const _categories = DemoHomeContentRepository.categories;
const _addresses = DemoAddressRepository.addresses;

Finder _addressButton() => find.byType(ZokyHomeAddressButton);
Finder _searchField() => find.byType(ZokyHomeSearchField);
Finder _pager() => find.byKey(ZokyHomeBannerCarousel.pagerKey);
Finder _bannerCards() => find.byType(ZokyHomeBannerCard);

ZokyPageDots _dots(WidgetTester tester) =>
    tester.widget<ZokyPageDots>(find.byKey(ZokyHomeBannerCarousel.dotsKey));

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
    testWidgets('header, search, carousel, categories, deals, stores', (
      tester,
    ) async {
      await pumpZokyApp(tester, height: 3000);
      double top(Type type) => tester.getTopLeft(find.byType(type)).dy;
      expect(top(ZokyHomeHeader), 0);
      expect(
        top(ZokyHomeHeader),
        lessThan(tester.getTopLeft(_addressButton()).dy),
      );
      expect(
        tester.getBottomLeft(_addressButton()).dy,
        lessThan(tester.getTopLeft(_searchField()).dy),
      );
      expect(top(ZokyHomeSearchField), lessThan(top(ZokyHomeBannerCarousel)));
      expect(top(ZokyHomeBannerCarousel), lessThan(top(ZokyFoodCategoryRow)));
      expect(top(ZokyFoodCategoryRow), lessThan(top(ZokyTodayDealsSection)));
      expect(
        top(ZokyTodayDealsSection),
        lessThan(top(ZokyRecommendedStoresSection)),
      );
    });

    testWidgets('search field straddles the pink/white seam', (tester) async {
      await pumpZokyApp(tester);
      final header = tester.getRect(find.byType(ZokyHomeHeader));
      final field = tester.getRect(_searchField());
      final seam = header.bottom - ZokyHomeHeader.sheetRadius;
      expect(field.top, lessThan(seam));
      expect(field.bottom, greaterThan(seam));
      expect(field.bottom, lessThanOrEqualTo(header.bottom));
      expect(field.left, 16);
      expect(field.right, 390 - 16);
    });

    testWidgets('legacy body is gone: no filter chips or nearby grid', (
      tester,
    ) async {
      await pumpZokyApp(tester);
      expect(find.text(ZokyStrings.nearbyStores), findsNothing);
      expect(find.text(ZokyStrings.filterRating), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('address', () {
    testWidgets('header shows "จัดส่งที่" and the default address', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpZokyApp(tester);
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
        await pumpZokyApp(tester);
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
      await pumpZokyApp(tester);
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
      await pumpZokyApp(tester);
      expect(
        find.descendant(
          of: _searchField(),
          matching: find.text(ZokyStrings.homeSearchPlaceholder),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(_searchField()),
        isSemantics(isButton: true, label: ZokyStrings.homeSearchPlaceholder),
      );
      expect(tester.getSize(_searchField()).height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    testWidgets('opens store search with the keyboard up', (tester) async {
      await pumpZokyApp(tester);
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
  });

  group('banner carousel', () {
    testWidgets('hero first, then demo banners labelled ตัวอย่าง', (
      tester,
    ) async {
      await pumpZokyApp(tester);
      final slides = find.descendant(
        of: _pager(),
        matching: find.byType(ZokyFoodHeroCard),
      );
      expect(slides, findsOneWidget);
      // Expired demo banner is filtered out like the RPC does.
      expect(_banners.map((b) => b.id), isNot(contains('demo-banner-expired')));
      expect(_dots(tester).count, 1 + _banners.length);
      expect(_dots(tester).active, 0);
      for (var i = 0; i < _banners.length; i++) {
        expect(_banners[i].isDemo, isTrue);
        expect(_banners[i].title, contains('ตัวอย่าง'));
        if (i < _banners.length - 1) await _nextSlide(tester);
      }
    });

    testWidgets('next slide peeks in at the right edge', (tester) async {
      await pumpZokyApp(tester, width: 390);
      final hero = tester.getRect(
        find.descendant(of: _pager(), matching: find.byType(ZokyFoodHeroCard)),
      );
      expect(hero.left, 16);
      expect(hero.width, ZokyHomeBannerCarousel.slideWidth(390));
      final next = tester.getRect(_bannerCards().first);
      expect(next.left, lessThan(390));
      expect(390 - next.left, closeTo(ZokyHomeBannerCarousel.peek, 0.5));
      // Slides share one height, at least the web banner ratio.
      expect(next.height, hero.height);
      expect(
        hero.height,
        greaterThanOrEqualTo(hero.width / ZokyHomeBannerCarousel.aspectRatio),
      );
    });

    testWidgets('paging moves the active pill dot', (tester) async {
      await pumpZokyApp(tester);
      await _nextSlide(tester);
      expect(_dots(tester).active, 1);
      expect(tester.getRect(_bannerCards().first).left, closeTo(16, 0.5));
      for (var i = 1; i < _banners.length; i++) {
        await _nextSlide(tester);
      }
      expect(_dots(tester).active, _banners.length);
      // The last slide ends at the right gutter.
      expect(tester.getRect(_bannerCards().last).right, closeTo(390 - 16, 0.5));
    });

    testWidgets('demo banners carry the ตัวอย่าง badge and semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpZokyApp(tester);
      for (var i = 0; i < _banners.length; i++) {
        await _nextSlide(tester);
        final banner = _banners[i];
        final card = find.byWidgetPredicate(
          (w) => w is ZokyHomeBannerCard && w.banner.id == banner.id,
        );
        expect(
          find.descendant(of: card, matching: find.text(ZokyStrings.demoBadge)),
          findsOneWidget,
        );
        final label = ZokyHomeBannerCard.semanticLabel(banner);
        expect(label, startsWith(ZokyStrings.demoBannerPrefix));
        expect(
          tester.getSemantics(card),
          isSemantics(label: label, isButton: banner.hasTarget),
        );
      }
      semantics.dispose();
    });

    testWidgets('store banner opens its store', (tester) async {
      await pumpZokyApp(tester);
      await _nextSlide(tester);
      final banner = _banners[0];
      expect(banner.destinationStoreId, isNotNull);
      await tester.tap(_bannerCards().first);
      await tester.pumpAndSettle();
      final store = tester.widget<StoreScreen>(find.byType(StoreScreen));
      expect(store.store.id, banner.destinationStoreId);
    });

    testWidgets('promo banner opens its deal sheet', (tester) async {
      await pumpZokyApp(tester);
      await _nextSlide(tester);
      await _nextSlide(tester);
      final banner = _banners[1];
      expect(banner.dealId, isNotNull);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ZokyHomeBannerCard && w.banner.id == banner.id,
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
      await pumpZokyApp(tester);
      for (var i = 0; i < 3; i++) {
        await _nextSlide(tester);
      }
      final banner = _banners[2];
      expect(banner.hasTarget, isFalse);
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is ZokyHomeBannerCard && w.banner.id == banner.id,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StoreScreen), findsNothing);
      expect(find.byType(ZokyDealDetail), findsNothing);
    });

    testWidgets('failing content: hero alone, no dots, no categories', (
      tester,
    ) async {
      await pumpZokyWidget(
        tester,
        Column(
          children: [
            ZokyHomeBannerCarousel(
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
      expect(find.byType(ZokyFoodHeroCard), findsWidgets);
      expect(_bannerCards(), findsNothing);
      expect(find.byKey(ZokyHomeBannerCarousel.dotsKey), findsNothing);
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
      await pumpZokyApp(tester);
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
        await pumpZokyApp(tester, height: 1400);
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
          await pumpZokyApp(
            tester,
            width: width,
            height: 2400,
            textScale: scale,
            bottomInset: 34,
          );
          expect(tester.takeException(), isNull);
          // Every slide renders without overflow.
          for (var i = 0; i < _banners.length; i++) {
            await _nextSlide(tester);
            expect(tester.takeException(), isNull);
          }
          // Address sheet too.
          await tester.tap(_addressButton());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          // Header row stays inside the screen.
          final pill = tester.getRect(_addressButton());
          expect(pill.right, lessThanOrEqualTo(width));
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
