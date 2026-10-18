// Food page header (Founder feedback 2026-10-18): painted icons never render
// empty (the iPad preview showed blank ▾ / coupon / filter glyphs from a
// stale tree-shaken icon font), the Glossy 3D accents are painted, and the
// small text and compact chips keep 4.5:1 on the pale blush header.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_line_icon.dart';
import 'package:zoky_app/features/food/food_home_screen.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_address_button.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_coupon_section.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_header.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_mode_toggle.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_search_field.dart';
import 'package:zoky_app/features/food/widgets/zoky_food_store_row.dart';

import 'support/pump_zoky.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
}

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

  testWidgets('every 3D glyph draws visible pixels (not empty)', (
    tester,
  ) async {
    const key = ValueKey('glyphs3d');
    const size = 32.0;
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
                for (final g in Zoky3DGlyph.values) Zoky3DIcon(g, size: size),
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
    for (final (i, g) in Zoky3DGlyph.values.indexed) {
      final ink = _pixelsNear(
        data,
        img.width,
        Rect.fromLTWH(i * size, 0, size, size),
        Zoky3DPalette.pink.bottom,
      );
      expect(ink, greaterThan(20), reason: '${g.name} is empty');
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
    expectInk(header(ZokyLineGlyph.caretDown), ZokyColors.brandDeep, '▾');
    // Glossy 3D accents: heart and coupon ticket in the header, rating
    // star and "ดูเมนู" arrow in the rows.
    Finder header3d(Zoky3DGlyph g) => find.descendant(
      of: find.byType(ZokyFoodHeader),
      matching: find.byWidgetPredicate((w) => w is Zoky3DIcon && w.glyph == g),
    );
    Finder row3d(Zoky3DGlyph g) => find
        .descendant(
          of: find.byType(ZokyFoodStoreRow),
          matching: find.byWidgetPredicate(
            (w) => w is Zoky3DIcon && w.glyph == g,
          ),
        )
        .first;
    expectInk(header3d(Zoky3DGlyph.heart), Zoky3DPalette.pink.bottom, 'heart');
    expectInk(
      header3d(Zoky3DGlyph.ticket),
      Zoky3DPalette.pink.bottom,
      'header coupon',
    );
    expectInk(row3d(Zoky3DGlyph.star), Zoky3DPalette.gold.bottom, 'star');
    expectInk(
      row3d(Zoky3DGlyph.arrowRight),
      Zoky3DPalette.pink.bottom,
      'ดูเมนู arrow',
    );
    // Selected chip: white on brandDeep; unselected: gray on white.
    expectInk(header(ZokyLineGlyph.scooter), Colors.white, 'scooter');
    expectInk(header(ZokyLineGlyph.bag), ZokyColors.textSecondary, 'bag');
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

  group('contrast on the pale blush header (WCAG 4.5:1 small text)', () {
    // headerPale is the darkest point of the gradient behind any text.
    const bg = ZokyColors.headerPale;

    test('row text and icons', () {
      // "จัดส่งที่" label.
      expect(
        _contrast(ZokyFoodAddressButton.labelStyle.color!, bg),
        greaterThanOrEqualTo(4.5),
      );
      // Address name / "รับเองที่ร้าน" and the back arrow.
      expect(
        _contrast(ZokyFoodAddressButton.titleStyle.color!, bg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(ZokyFoodHeader.backColor, bg),
        greaterThanOrEqualTo(4.5),
      );
      // ▾ (non-text, 3:1).
      expect(_contrast(ZokyColors.brandDeep, bg), greaterThanOrEqualTo(3));
    });

    test('mode chips: selected white on brandDeep; unselected ink text and '
        'gray icon on the white pill', () {
      expect(
        _contrast(Colors.white, ZokyFoodModeToggle.selectedFill),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(ZokyColors.textPrimary, ZokyFoodModeToggle.unselectedFill),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(ZokyColors.textSecondary, ZokyFoodModeToggle.unselectedFill),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('status bar content is dark', () {
      expect(
        ZokyFoodHeader.systemOverlayStyle.statusBarIconBrightness,
        Brightness.dark,
      );
      expect(
        ZokyFoodHeader.systemOverlayStyle.statusBarBrightness,
        Brightness.light,
      );
    });

    for (final (topInset, scale) in [(59.0, 1.0), (59.0, 1.3), (0.0, 1.0)]) {
      testWidgets('gradient only gets lighter, is flat blush behind the row '
          'and white by the search field (top $topInset, x$scale)', (
        tester,
      ) async {
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
            (tester.widget<DecoratedBox>(surface).decoration as BoxDecoration)
                    .gradient!
                as LinearGradient;
        expect(gradient.colors.first, ZokyColors.headerPale);
        expect(gradient.colors.last, Colors.white);
        for (var i = 1; i < gradient.colors.length; i++) {
          expect(
            gradient.colors[i].computeLuminance(),
            greaterThanOrEqualTo(gradient.colors[i - 1].computeLuminance()),
          );
        }
        final rect = tester.getRect(surface);
        final title = tester.getRect(find.byType(ZokyFoodAddressButton));
        final flatTo = rect.top + gradient.stops![1] * rect.height;
        expect(flatTo, greaterThanOrEqualTo(title.bottom - 2));
        final whiteAt = rect.top + gradient.stops!.last * rect.height;
        final search = tester.getRect(find.byType(ZokyFoodSearchField));
        expect(whiteAt, closeTo(search.center.dy, 0.5));
      });
    }
  });
}
