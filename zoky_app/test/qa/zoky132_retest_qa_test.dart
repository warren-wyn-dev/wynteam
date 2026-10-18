// QA re-test of ZOKY-132 (independent of the Debug Engineer's
// semantics_tap_action_test.dart). For every enabled button on Home, Food
// (delivery + pickup) and the Food/Home sheets:
//   1. the node exposes SemanticsAction.tap (disabled nodes do not);
//   2. firing the semantics tap leads to exactly the same app state as a
//      finger tap at the node's centre, both right after the action and
//      after one system back (catches a wrong callback, a missing action
//      and double fire: a double push/toggle diverges from the finger tap).
// Synthetic demo data only, no backend.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/features/address/address_sheet.dart';
import 'package:zoky_app/features/address/data/demo_address_repository.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/food/food_home_screen.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_coupon_section.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_search_field.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_store_row.dart';
import 'package:zoky_app/features/fulfillment/fulfillment_mode_controller.dart';

import '../support/pump_zoky.dart';

const double _w = 390;
const double _h = 2400;

SemanticsNode _root(WidgetTester tester) {
  var root = tester.getSemantics(find.byType(MaterialApp).first);
  while (root.parent != null) {
    root = root.parent!;
  }
  return root;
}

List<SemanticsNode> _all(WidgetTester tester) {
  final out = <SemanticsNode>[];
  void walk(SemanticsNode n) {
    out.add(n);
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(_root(tester));
  return out;
}

String _name(SemanticsData d) => d.label.isEmpty ? d.tooltip : d.label;

/// Global (logical) rect: apply every transform up to, not including, root.
Rect _globalRect(SemanticsNode n) {
  var rect = n.rect;
  var cur = n;
  while (cur.parent != null) {
    if (cur.transform != null) {
      rect = MatrixUtils.transformRect(cur.transform!, rect);
    }
    cur = cur.parent!;
  }
  return rect;
}

/// Visible state: every node's label, value and state flags in tree order.
String _snapshot(WidgetTester tester) => _all(tester)
    .map((n) {
      final d = n.getSemanticsData();
      final f = d.flagsCollection;
      return '${_name(d)}|${d.value}|sel=${f.isSelected}|tog=${f.isToggled}'
          '|btn=${f.isButton}|hid=${f.isHidden}';
    })
    .join('\n');

/// Enabled button nodes as (name, occurrence index) in tree order.
List<(String, int)> _buttons(WidgetTester tester) {
  final seen = <String, int>{};
  final out = <(String, int)>[];
  for (final n in _all(tester)) {
    final d = n.getSemanticsData();
    if (!d.flagsCollection.isButton) continue;
    if (d.flagsCollection.isEnabled == Tristate.isFalse) continue;
    final name = _name(d);
    final i = seen[name] ?? 0;
    seen[name] = i + 1;
    out.add((name, i));
  }
  return out;
}

SemanticsNode _node(WidgetTester tester, (String, int) key) {
  final matches = _all(tester).where((n) {
    final d = n.getSemanticsData();
    return d.flagsCollection.isButton && _name(d) == key.$1;
  }).toList();
  return matches[key.$2];
}

Future<void> _fingerTapLabel(WidgetTester tester, Pattern label) async {
  final n = _all(tester).firstWhere((n) {
    final l = n.getSemanticsData().label;
    return label is RegExp ? label.hasMatch(l) : l == label;
  });
  await tester.tapAt(_globalRect(n).center);
  await tester.pumpAndSettle();
}

Future<void> _freshApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await pumpZokyApp(tester, width: _w, height: _h);
}

Future<void> _toFood(WidgetTester tester) async {
  await _fingerTapLabel(tester, ZokyStrings.heroSearchButton);
  expect(find.byType(FoodHomeScreen), findsOneWidget);
}

final Map<String, Future<void> Function(WidgetTester)> _screens = {
  'Home': (t) async {},
  'Food delivery': _toFood,
  'Food pickup': (t) async {
    await _toFood(t);
    await _fingerTapLabel(t, ZokyStrings.modePickup);
  },
  'Address sheet': (t) async {
    await _toFood(t);
    await _fingerTapLabel(t, RegExp('^${ZokyStrings.deliverAt}'));
  },
  'Filter sheet (delivery)': (t) async {
    await _toFood(t);
    await _fingerTapLabel(t, ZokyStrings.filters);
  },
  'Filter sheet (pickup)': (t) async {
    await _toFood(t);
    await _fingerTapLabel(t, ZokyStrings.modePickup);
    await _fingerTapLabel(t, ZokyStrings.filters);
  },
  'Coupons sheet (Food)': (t) async {
    await _toFood(t);
    await _fingerTapLabel(t, ZokyStrings.coupons);
  },
  'Favorites (Food)': (t) async {
    await _toFood(t);
    await _fingerTapLabel(t, ZokyStrings.favoriteStores);
  },
  'Favorites (Home)': (t) async {
    await _fingerTapLabel(t, ZokyStrings.favoriteStores);
  },
};

void main() {
  group('QA ZOKY-132 no double fire: finger 1x, semantics 1x', () {
    Future<void> once(
      WidgetTester tester,
      Widget Function(VoidCallback cb) build,
      Pattern label,
    ) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpZokyWidget(
        tester,
        SingleChildScrollView(child: build(() => taps++)),
      );
      await tester.pumpAndSettle();
      await _fingerTapLabel(tester, label);
      expect(taps, 1, reason: 'finger tap');
      final n = _all(tester).firstWhere((n) {
        final l = n.getSemanticsData().label;
        return label is RegExp ? label.hasMatch(l) : l == label;
      });
      n.owner!.performAction(n.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(taps, 2, reason: 'semantics tap');
      semantics.dispose();
    }

    const address = DemoAddressRepository.addresses;
    testWidgets('ZokyAddressTile', (t) async {
      await once(
        t,
        (cb) =>
            ZokyAddressTile(address: address.first, selected: false, onTap: cb),
        RegExp('^${RegExp.escape(address.first.label)}'),
      );
    });
    testWidgets('ZokyCollectButton collected (toggle back)', (t) async {
      await once(
        t,
        (cb) => ZokyCollectButton(collected: true, onPressed: cb),
        ZokyStrings.codeCollected,
      );
    });
    testWidgets('ZokyFoodSearchField', (t) async {
      await once(
        t,
        (cb) => ZokyFoodSearchField(onPressed: cb),
        ZokyStrings.foodSearchPlaceholder,
      );
    });
    testWidgets('ZokyFoodStoreRow (pickup)', (t) async {
      final store = DemoStoreRepository.stores.first;
      final label = ZokyFoodStoreRow(
        store: store,
        mode: FulfillmentMode.pickup,
        onTap: () {},
      ).semanticLabel();
      await once(
        t,
        (cb) => ZokyFoodStoreRow(
          store: store,
          mode: FulfillmentMode.pickup,
          onTap: cb,
        ),
        label,
      );
    });
  });

  for (final entry in _screens.entries) {
    testWidgets('QA ZOKY-132 ${entry.key}: semantics tap == finger tap', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _freshApp(tester);
      await entry.value(tester);

      // 1. Audit: enabled buttons have tap, disabled ones do not.
      final missing = <String>[];
      final disabledWithTap = <String>[];
      for (final n in _all(tester)) {
        final d = n.getSemanticsData();
        if (!d.flagsCollection.isButton) continue;
        final disabled = d.flagsCollection.isEnabled == Tristate.isFalse;
        final tap = d.hasAction(SemanticsAction.tap);
        if (!disabled && !tap) missing.add(_name(d));
        if (disabled && tap) disabledWithTap.add(_name(d));
      }
      expect(missing, isEmpty, reason: 'enabled buttons without tap');
      expect(disabledWithTap, isEmpty, reason: 'disabled buttons with tap');

      // 2. Equivalence per button.
      final buttons = _buttons(tester);
      final skipped = <String>[];
      final mismatches = <String>[];
      var noop = 0;
      final noopNames = <String>[];
      for (final key in buttons) {
        await _freshApp(tester);
        await entry.value(tester);
        final before = _snapshot(tester);
        final node = _node(tester, key);
        final rect = _globalRect(node);
        // Material's sheet drag handle ("ปิด", framework widget) is
        // dismiss-by-semantics only; a finger dismisses by dragging or by
        // tapping the scrim, so compare it with a scrim tap.
        final dragHandle = key.$1 == 'ปิด';
        final center = dragHandle ? Offset(rect.center.dx, 8) : rect.center;
        if (center.dx < 0 ||
            center.dx > _w ||
            center.dy < 0 ||
            center.dy > _h ||
            node.getSemanticsData().flagsCollection.isHidden) {
          skipped.add(key.$1);
          continue;
        }
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pumpAndSettle();
        final semAfter = _snapshot(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final semBack = _snapshot(tester);

        await _freshApp(tester);
        await entry.value(tester);
        await tester.tapAt(center);
        await tester.pumpAndSettle();
        final fingerAfter = _snapshot(tester);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        final fingerBack = _snapshot(tester);

        if (fingerAfter == before) {
          noop++;
          noopNames.add(key.$1);
        }
        if (semAfter != fingerAfter || semBack != fingerBack) {
          // ignore: avoid_print
          print(
            'DBG ${key.$1} rect=$rect tapAt=$center '
            'semChanged=${semAfter != before} '
            'fingerChanged=${fingerAfter != before} '
            'backEq=${semBack == fingerBack}',
          );
          mismatches.add('${key.$1}#${key.$2}');
        }
      }
      // ignore: avoid_print
      print(
        'QA-ZOKY-132 ${entry.key}: buttons=${buttons.length} '
        'compared=${buttons.length - skipped.length} '
        'finger-noop=$noop $noopNames skipped(offscreen)=$skipped '
        'mismatches=$mismatches',
      );
      expect(buttons, isNotEmpty);
      expect(mismatches, isEmpty);
      semantics.dispose();
    });
  }

  // ZOKY-134 (open, deferred to the store page design): the same pattern
  // remains on the store search grid and the store page. Un-skip to repro.
  group('ZOKY-134 repro: store search + store page buttons have no tap', () {
    List<String> missingTap(WidgetTester tester) => [
      for (final n in _all(tester))
        if (n.getSemanticsData().flagsCollection.isButton &&
            n.getSemanticsData().flagsCollection.isEnabled !=
                Tristate.isFalse &&
            !n.getSemanticsData().hasAction(SemanticsAction.tap))
          _name(n.getSemanticsData()),
    ];

    testWidgets('store search grid (Food search field)', skip: true, (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _freshApp(tester);
      await _toFood(tester);
      await _fingerTapLabel(tester, ZokyStrings.foodSearchPlaceholder);
      final missing = missingTap(tester);
      // ignore: avoid_print
      print('QA-ZOKY-134 search ${missing.length}: $missing');
      expect(missing, isEmpty);
      semantics.dispose();
    });

    testWidgets(
      'store page (Food store row), add item + cart bar',
      skip: true,
      (tester) async {
        final semantics = tester.ensureSemantics();
        await _freshApp(tester);
        await _toFood(tester);
        final row = _all(tester).firstWhere(
          (n) => n.getSemanticsData().label.startsWith('ร้านตัวอย่าง'),
        );
        await tester.tapAt(_globalRect(row).center);
        await tester.pumpAndSettle();
        final add = _all(tester)
            .firstWhere((n) => n.getSemanticsData().label.startsWith('เพิ่ม '));
        await tester.tapAt(_globalRect(add).center);
        await tester.pumpAndSettle();
        final missing = missingTap(tester);
        // ignore: avoid_print
        print('QA-ZOKY-134 store ${missing.length}: $missing');
        expect(missing, isEmpty);
        semantics.dispose();
      },
    );
  });
}
