// ZOKY-132 regression: every node that says "button" on Home, Food and the
// Food sheets exposes SemanticsAction.tap (assistive tech activates through
// actions: Switch Access, Voice Access, TalkBack click, Flutter web), and
// triggering that action runs the same callback as a finger tap. Disabled
// buttons must not expose a tap action. Synthetic demo data only.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_glossy_heart_button.dart';
import 'package:zoky_app/features/address/data/demo_address_repository.dart';
import 'package:zoky_app/features/address/delivery_address_controller.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';
import 'package:zoky_app/features/deals/widgets/zoky_deal_card.dart';
import 'package:zoky_app/features/food/food_home_screen.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_address_button.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_cart_button.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_category_row.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_coupon_section.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_mode_toggle.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_search_field.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_store_row.dart';
import 'package:zoky_app/features/fulfillment/fulfillment_mode_controller.dart';
import 'package:zoky_app/features/home/data/demo_home_content_repository.dart';
import 'package:zoky_app/features/home/home_screen.dart';
import 'package:zoky_app/features/home/widgets/zoky_food_hero_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_section_header.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_store_card.dart';

import 'support/pump_zoky.dart';

/// Button nodes in the whole semantics tree, split by tap-action health.
({int buttons, List<String> missing, List<String> disabledWithTap}) _audit(
  WidgetTester tester,
) {
  var root = tester.getSemantics(find.byType(MaterialApp).first);
  while (root.parent != null) {
    root = root.parent!;
  }
  var buttons = 0;
  final missing = <String>[];
  final disabledWithTap = <String>[];
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    if (d.flagsCollection.isButton) {
      buttons++;
      final name = d.label.isEmpty ? d.tooltip : d.label;
      final disabled = d.flagsCollection.isEnabled == Tristate.isFalse;
      final tap = d.hasAction(SemanticsAction.tap);
      if (disabled && tap) disabledWithTap.add(name);
      if (!disabled && !tap) missing.add(name);
    }
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(root);
  return (buttons: buttons, missing: missing, disabledWithTap: disabledWithTap);
}

void _expectAllButtonsTappable(WidgetTester tester, {int atLeast = 1}) {
  final r = _audit(tester);
  expect(r.buttons, greaterThanOrEqualTo(atLeast));
  expect(r.missing, isEmpty, reason: 'buttons without a tap action');
  expect(r.disabledWithTap, isEmpty, reason: 'disabled buttons with tap');
}

/// Triggers the semantics tap action of the node labelled [label].
void _semanticsTap(WidgetTester tester, Finder finder) {
  final node = tester.getSemantics(finder);
  expect(
    node.getSemanticsData().hasAction(SemanticsAction.tap),
    isTrue,
    reason: '${node.label} has no tap action',
  );
  node.owner!.performAction(node.id, SemanticsAction.tap);
}

Future<void> _openFood(WidgetTester tester) async {
  final hero = find.text(ZokyStrings.heroSearchButton);
  await tester.ensureVisible(hero);
  await tester.pumpAndSettle();
  _semanticsTap(tester, find.bySemanticsLabel(ZokyStrings.heroSearchButton));
  await tester.pumpAndSettle();
  expect(find.byType(FoodHomeScreen), findsOneWidget);
}

void main() {
  group('ZOKY-132 screens: every button exposes a tap action', () {
    testWidgets('Home', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpZokyApp(tester, height: 2400);
      expect(find.byType(HomeScreen), findsOneWidget);
      // Hero, ร้านโปรด, 2x ดูทั้งหมด, 5 store cards, 4 deal cards, nav.
      _expectAllButtonsTappable(tester, atLeast: 13);
      semantics.dispose();
    });

    testWidgets('Food (delivery and pickup), opened through semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpZokyApp(tester, height: 2400);
      await _openFood(tester);
      _expectAllButtonsTappable(tester, atLeast: 28);

      _semanticsTap(tester, find.bySemanticsLabel(ZokyStrings.modePickup));
      await tester.pumpAndSettle();
      _expectAllButtonsTappable(tester, atLeast: 20);
      semantics.dispose();
    });

    testWidgets('Food sheets: address and filters, opened through semantics', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpZokyApp(tester, height: 2400);
      await _openFood(tester);

      _semanticsTap(
        tester,
        find.bySemanticsLabel(RegExp('^${ZokyStrings.deliverAt}')),
      );
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.chooseDeliveryAddress), findsWidgets);
      _expectAllButtonsTappable(tester);
      Navigator.of(tester.element(find.byType(FoodHomeScreen))).pop();
      await tester.pumpAndSettle();

      _semanticsTap(tester, find.bySemanticsLabel(ZokyStrings.filters));
      await tester.pumpAndSettle();
      _expectAllButtonsTappable(tester);
      semantics.dispose();
    });
  });

  group('ZOKY-132 widgets: semantics tap fires the callback once', () {
    Future<void> check(
      WidgetTester tester,
      Widget Function(VoidCallback onTap) build,
      Finder node,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpZokyWidget(
        tester,
        SingleChildScrollView(child: build(() => taps++)),
      );
      await tester.pumpAndSettle();
      _semanticsTap(tester, node);
      await tester.pump();
      expect(taps, 1);
      semantics.dispose();
    }

    const store = DemoStoreRepository.stores;
    final deal = DemoPromotionRepository.deals.first;
    final category = DemoHomeContentRepository.categories.first;

    testWidgets('ZokyFoodSearchField', (tester) async {
      await check(
        tester,
        (cb) => ZokyFoodSearchField(onPressed: cb),
        find.bySemanticsLabel(ZokyStrings.foodSearchPlaceholder),
      );
    });

    testWidgets('ZokyFoodStoreRow', (tester) async {
      final row = ZokyFoodStoreRow(
        store: store.first,
        mode: FulfillmentMode.delivery,
        onTap: () {},
      );
      await check(
        tester,
        (cb) => ZokyFoodStoreRow(
          store: store.first,
          mode: FulfillmentMode.delivery,
          onTap: cb,
        ),
        find.bySemanticsLabel(row.semanticLabel()),
      );
    });

    testWidgets('ZokyFoodAddressButton', (tester) async {
      final addresses = DeliveryAddressController(
        const DemoAddressRepository(),
      );
      final mode = FulfillmentModeController();
      await check(
        tester,
        (cb) => ZokyFoodAddressButton(
          controller: addresses,
          mode: mode,
          onPressed: cb,
        ),
        find.bySemanticsLabel(RegExp('^${ZokyStrings.deliverAt}')),
      );
    });

    testWidgets('ZokyCollectButton (enabled toggle)', (tester) async {
      await check(
        tester,
        (cb) => ZokyCollectButton(collected: false, onPressed: cb),
        find.bySemanticsLabel(ZokyStrings.collectCode),
      );
    });

    testWidgets('ZokyFoodCategoryItem', (tester) async {
      await check(
        tester,
        (cb) => ZokyFoodCategoryItem(
          category: category,
          circle: 64,
          width: 80,
          onTap: cb,
        ),
        find.bySemanticsLabel(category.label),
      );
    });

    testWidgets('ZokyFoodCartButton', (tester) async {
      await check(
        tester,
        (cb) => ZokyFoodCartButton(itemCount: 0, total: 0, onPressed: cb),
        find.bySemanticsLabel(ZokyStrings.cart),
      );
    });

    testWidgets('ZokyGlossyHeartButton', (tester) async {
      await check(
        tester,
        (cb) => ZokyGlossyHeartButton(label: 'ร้านโปรด', onPressed: cb),
        find.bySemanticsLabel('ร้านโปรด'),
      );
    });

    testWidgets('ZokyHomeSectionHeader "ดูทั้งหมด"', (tester) async {
      await check(
        tester,
        (cb) => ZokyHomeSectionHeader(
          title: 'หัวข้อ',
          seeAllLabel: 'ดูทั้งหมด หัวข้อ',
          onSeeAll: cb,
        ),
        find.bySemanticsLabel('ดูทั้งหมด หัวข้อ'),
      );
    });

    testWidgets('ZokyFoodHeroCard search', (tester) async {
      await check(
        tester,
        (cb) => ZokyFoodHeroCard(onSearch: cb),
        find.bySemanticsLabel(ZokyStrings.heroSearchButton),
      );
    });

    testWidgets('ZokyRecommendedStoreCard', (tester) async {
      await check(
        tester,
        (cb) =>
            ZokyRecommendedStoreCard(store: store.first, width: 160, onTap: cb),
        find.bySemanticsLabel(
          ZokyRecommendedStoreCard.semanticLabel(store.first),
        ),
      );
    });

    testWidgets('ZokyDealCard', (tester) async {
      await check(
        tester,
        (cb) => ZokyDealCard(deal: deal, width: 300, onTap: cb),
        find.bySemanticsLabel(ZokyDealCard.semanticLabel(deal)),
      );
    });

    testWidgets('ZokyFoodModeToggle switches mode', (tester) async {
      final semantics = tester.ensureSemantics();
      final mode = FulfillmentModeController();
      await pumpZokyWidget(tester, ZokyFoodModeToggle(controller: mode));
      _semanticsTap(tester, find.bySemanticsLabel(ZokyStrings.modePickup));
      await tester.pump();
      expect(mode.mode, FulfillmentMode.pickup);
      semantics.dispose();
    });
  });
}
