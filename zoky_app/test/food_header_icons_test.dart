// Food page header (Founder feedback 2026-10-18): painted icons never render
// empty (the iPad preview showed blank ▾ / coupon / filter glyphs from a
// stale tree-shaken icon font), and the small white text and compact chips
// keep 4.5:1 on the pink.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_glossy_surface.dart';
import 'package:zoky_app/core/widgets/zoky_line_icon.dart';
import 'package:zoky_app/features/food/food_home_screen.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_address_button.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_coupon_section.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_header.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_mode_toggle.dart';

import 'support/pump_zoky.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

/// [top] (translucent) composited over opaque [bottom].
Color _over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

/// Captures the whole view as RGBA.
Future<(ByteData, int)> _capture(WidgetTester tester) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final img = (await tester.runAsync(
    () => layer.toImage(Offset.zero & view.size),
  ))!;
  final data = (await tester.runAsync(
    () => img.toByteData(format: ui.ImageByteFormat.rawRgba),
  ))!;
  final width = img.width;
  img.dispose();
  return (data, width);
}

/// Pixels inside [rect] within 70 (RGB distance) of [color].
int _pixelsNear(ByteData data, int width, Rect rect, Color color) {
  var n = 0;
  final r = (color.r * 255).round();
  final g = (color.g * 255).round();
  final b = (color.b * 255).round();
  for (var y = rect.top.floor(); y < rect.bottom.ceil(); y++) {
    for (var x = rect.left.floor(); x < rect.right.ceil(); x++) {
      final i = (y * width + x) * 4;
      final dr = data.getUint8(i) - r;
      final dg = data.getUint8(i + 1) - g;
      final db = data.getUint8(i + 2) - b;
      if (dr * dr + dg * dg + db * db < 70 * 70) n++;
    }
  }
  return n;
}

Future<void> _openFood(WidgetTester tester, {double topInset = 59}) async {
  setPhoneViewport(tester, width: 430, height: 1400);
  final inset = FakeViewPadding(top: topInset);
  tester.view.padding = inset;
  tester.view.viewPadding = inset;
  await tester.pumpWidget(demoZokyApp());
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
  await tester.tap(find.text(ZokyStrings.heroSearchButton));
  await tester.pumpAndSettle();
  expect(find.byType(FoodHomeScreen), findsOneWidget);
}

void main() {
  testWidgets('every painted glyph draws visible pixels (not empty)', (
    tester,
  ) async {
    const key = ValueKey('glyphs');
    await pumpZokyWidget(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: key,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final g in ZokyLineGlyph.values)
                  ZokyLineIcon(g, size: 24, color: const Color(0xFF000000)),
              ],
            ),
          ),
        ),
      ),
    );
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(key),
    );
    final img = (await tester.runAsync(() => boundary.toImage()))!;
    final data = (await tester.runAsync(
      () => img.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    for (final (i, g) in ZokyLineGlyph.values.indexed) {
      final ink = _pixelsNear(
        data,
        img.width,
        Rect.fromLTWH(i * 24.0, 0, 24, 24),
        const Color(0xFF000000),
      );
      // Visible line art, but not a filled square.
      expect(ink, greaterThan(20), reason: '${g.name} is empty');
      expect(ink, lessThan(24 * 24 * 0.6), reason: '${g.name} is a blob');
    }
    img.dispose();
  });

  testWidgets('food page icons that were blank on the iPad are painted and '
      'show pixels in their boxes', (tester) async {
    await _openFood(tester);
    // No icon-font glyph is used for them any more.
    for (final g in [
      ZokyLineGlyph.caretDown,
      ZokyLineGlyph.ticket,
      ZokyLineGlyph.sliders,
      ZokyLineGlyph.scooter,
      ZokyLineGlyph.bag,
      ZokyLineGlyph.cart,
    ]) {
      expect(find.byKey(ZokyLineIcon.keyFor(g)), findsWidgets, reason: g.name);
    }
    final (data, width) = await _capture(tester);
    void expectInk(Finder icon, Color color, String what) {
      final rect = tester.getRect(icon);
      expect(
        _pixelsNear(data, width, rect, color),
        greaterThan(15),
        reason: '$what renders empty',
      );
    }

    Finder header(ZokyLineGlyph g) => find.descendant(
      of: find.byType(ZokyFoodHeader),
      matching: find.byKey(ZokyLineIcon.keyFor(g)),
    );
    expectInk(header(ZokyLineGlyph.caretDown), Colors.white, '▾');
    expectInk(header(ZokyLineGlyph.ticket), Colors.white, 'header coupon');
    // Selected chip: brandDeep on white; unselected: white on pink.
    expectInk(header(ZokyLineGlyph.scooter), ZokyColors.brandDeep, 'scooter');
    expectInk(header(ZokyLineGlyph.bag), Colors.white, 'bag');
    expectInk(
      find
          .descendant(
            of: find.byKey(FoodHomeScreen.filterButtonKey),
            matching: find.byType(ZokyLineIcon),
          )
          .first,
      ZokyColors.brandDeep,
      'filter',
    );
    // Coupon card icon (ticket or scooter, left of the text).
    final cardIcon = find
        .descendant(
          of: find.byType(ZokyFoodCouponCard).first,
          matching: find.byType(ZokyLineIcon),
        )
        .first;
    expectInk(cardIcon, ZokyColors.brandDeep, 'coupon card icon');
    expectInk(
      find
          .descendant(
            of: find.byKey(FoodHomeScreen.cartKey),
            matching: find.byType(ZokyLineIcon),
          )
          .first,
      Colors.white,
      'cart',
    );
  });

  group('contrast (WCAG 4.5:1 for small text)', () {
    test('white on brandDeep, also under the faint top sheen', () {
      expect(
        _contrast(Colors.white, ZokyColors.brandDeep),
        greaterThanOrEqualTo(4.5),
      );
      final sheen = Colors.white.withValues(alpha: ZokyFoodHeader.glossOpacity);
      expect(
        _contrast(Colors.white, _over(sheen, ZokyColors.brandDeep)),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('mode chips: selected brandDeep on white; unselected white on '
        'the translucent pill', () {
      expect(
        _contrast(ZokyColors.brandDeep, Colors.white),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(
          Colors.white,
          _over(ZokyFoodModeToggle.unselectedFill, ZokyColors.brandDeep),
        ),
        greaterThanOrEqualTo(4.5),
      );
    });

    for (final (topInset, scale) in [(59.0, 1.0), (59.0, 1.3), (0.0, 1.0)]) {
      testWidgets('address text sits on the brandDeep part of the gradient '
          '(top $topInset, x$scale)', (tester) async {
        setPhoneViewport(tester, width: 390, height: 1400, textScale: scale);
        final inset = FakeViewPadding(top: topInset);
        tester.view.padding = inset;
        tester.view.viewPadding = inset;
        await tester.pumpWidget(demoZokyApp());
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();
        await tester.tap(find.text(ZokyStrings.heroSearchButton));
        await tester.pumpAndSettle();
        final surface = find.byKey(ZokyFoodHeader.surfaceKey);
        final gradient =
            tester.widget<ZokyGlossySurface>(surface).gradient
                as LinearGradient;
        expect(gradient.colors.last, ZokyColors.brandDeep);
        final rect = tester.getRect(surface);
        final deepFrom = rect.top + gradient.stops!.last * rect.height;
        final label = tester.getRect(
          find.descendant(
            of: find.byType(ZokyFoodAddressButton),
            matching: find.text(ZokyStrings.deliverAt),
          ),
        );
        expect(label.top, greaterThanOrEqualTo(deepFrom - 0.01));
      });
    }
  });
}
