import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_header.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_store_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_stores_section.dart';

import 'support/pump_zoky.dart';

const _labels = [
  ZokyStrings.navHome,
  ZokyStrings.navOrders,
  ZokyStrings.navMessages,
  ZokyStrings.navAccount,
];

Finder _inNav(Finder matching) =>
    find.descendant(of: find.byType(ZokyBottomNav), matching: matching);

Finder _item(String label) => find.ancestor(
  of: _inNav(find.text(label)),
  matching: find.byType(InkResponse),
);

/// The label's own AnimatedDefaultTextStyle (Material adds more above it).
Finder _labelStyle(String label) => find
    .ancestor(
      of: _inNav(find.text(label)),
      matching: find.byType(AnimatedDefaultTextStyle),
    )
    .first;

Zoky3DIcon _icon(WidgetTester tester, String label) => tester.widget<Zoky3DIcon>(
  find.descendant(of: _item(label), matching: find.byType(Zoky3DIcon)).last,
);

Finder _homeCards() => find.descendant(
  of: find.byType(ZokyRecommendedStoresSection),
  matching: find.byType(ZokyRecommendedStoreCard),
);

Future<void> _scrollHomeToEnd(WidgetTester tester) async {
  await tester.drag(
    find.byType(CustomScrollView).first,
    const Offset(0, -3000),
  );
  await tester.pumpAndSettle();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // Real Thai glyph widths (the default test font draws every glyph as a
  // 1em square), so the overflow / clipping checks below are meaningful.
  setUpAll(() async {
    final loader = FontLoader('Anuphan')
      ..addFont(rootBundle.load(
        'assets/fonts/anuphan/Anuphan-VariableFont_wght.ttf',
      ));
    await loader.load();
  });

  testWidgets('exactly four items, in order, with the exact Thai labels', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    expect(_inNav(find.byType(InkResponse)), findsNWidgets(4));
    final texts = tester
        .widgetList<Text>(_inNav(find.byType(Text)))
        .map((t) => t.data)
        .toList();
    expect(texts, ['หน้าหลัก', 'ออเดอร์', 'ข้อความ', 'บัญชี']);
    expect(texts, _labels);
    final glyphs = [for (final l in _labels) _icon(tester, l).glyph];
    expect(glyphs, [
      Zoky3DGlyph.home,
      Zoky3DGlyph.receipt,
      Zoky3DGlyph.chat,
      Zoky3DGlyph.person,
    ]);
    // Items are evenly spaced: equal widths.
    final widths = {for (final l in _labels) tester.getSize(_item(l)).width};
    expect(widths.length, 1);
  });

  testWidgets('selected item is glossy 3D + bold pink, the rest gray line', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    void expectSelected(String selected) {
      for (final label in _labels) {
        final icon = _icon(tester, label);
        final style = tester
            .widget<AnimatedDefaultTextStyle>(_labelStyle(label))
            .style;
        if (label == selected) {
          expect(icon.style, Zoky3DIconStyle.glossy, reason: label);
          expect(icon.palette, Zoky3DPalette.pink);
          expect(style.color, ZokyColors.actionPrimary);
          expect(style.fontWeight, FontWeight.w700);
        } else {
          expect(icon.style, Zoky3DIconStyle.line, reason: label);
          expect(icon.lineColor, ZokyColors.neutral600);
          expect(style.color, ZokyColors.textSecondary);
          expect(style.fontWeight, FontWeight.w500);
        }
        expect(icon.size, ZokyBottomNav.iconSize);
      }
    }

    expectSelected(ZokyStrings.navHome);
    for (final label in [..._labels.skip(1), ZokyStrings.navHome]) {
      await tester.tap(_inNav(find.text(label)));
      await tester.pumpAndSettle();
      expectSelected(label);
    }
  });

  testWidgets('selection animates ~200ms, instantly with reduced motion', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    expect(
      tester.widget<AnimatedSwitcher>(
        find.descendant(
          of: _item(ZokyStrings.navHome),
          matching: find.byType(AnimatedSwitcher),
        ),
      ).duration,
      const Duration(milliseconds: 200),
    );

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(
      tester.widget<AnimatedSwitcher>(
        find.descendant(
          of: _item(ZokyStrings.navHome),
          matching: find.byType(AnimatedSwitcher),
        ),
      ).duration,
      Duration.zero,
    );
  });

  testWidgets('each item is a button exposing its selected state', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpZokyApp(tester);
    for (final selected in [ZokyStrings.navMessages, ZokyStrings.navHome]) {
      await tester.tap(_inNav(find.text(selected)));
      await tester.pumpAndSettle();
      for (final label in _labels) {
        expect(
          tester.getSemantics(_inNav(find.bySemanticsLabel(label))),
          isSemantics(
            label: label,
            isButton: true,
            hasTapAction: true,
            hasSelectedState: true,
            isSelected: label == selected,
          ),
        );
      }
    }
    handle.dispose();
  });

  testWidgets('touch targets are at least 44x44', (tester) async {
    await pumpZokyApp(tester, width: 320, height: 568);
    for (final label in _labels) {
      final size = tester.getSize(_item(label));
      expect(size.width, greaterThanOrEqualTo(44), reason: label);
      expect(size.height, greaterThanOrEqualTo(44), reason: label);
    }
  });

  testWidgets('switching tabs plays a selection haptic, re-tap does not', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(_inNav(find.text(ZokyStrings.navOrders)));
    await tester.pumpAndSettle();
    expect(haptics, ['HapticFeedbackType.selectionClick']);
    await tester.tap(_inNav(find.text(ZokyStrings.navOrders)));
    await tester.pumpAndSettle();
    expect(haptics, hasLength(1));
  });

  testWidgets('re-tapping the selected หน้าหลัก scrolls Home to the top', (
    tester,
  ) async {
    await pumpZokyApp(tester, width: 430, height: 932, bottomInset: 34);
    final headerTop = tester.getTopLeft(find.byType(ZokyHomeHeader)).dy;
    await _scrollHomeToEnd(tester);
    expect(
      tester.getTopLeft(find.byType(ZokyHomeHeader)).dy,
      lessThan(headerTop),
    );

    // Coming back from another tab keeps the scroll position...
    await tester.tap(_inNav(find.text(ZokyStrings.navAccount)));
    await tester.pumpAndSettle();
    await tester.tap(_inNav(find.text(ZokyStrings.navHome)));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byType(ZokyHomeHeader)).dy,
      lessThan(headerTop),
    );

    // ...tapping หน้าหลัก again goes back to the top.
    await tester.tap(_inNav(find.text(ZokyStrings.navHome)));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(ZokyHomeHeader)).dy, headerTop);
  });

  for (final (w, h, inset) in [
    (430.0, 932.0, 34.0),
    (390.0, 844.0, 34.0),
    (375.0, 667.0, 0.0),
    (320.0, 568.0, 0.0),
  ]) {
    testWidgets('bar sits on the bottom safe area and covers no Home row at '
        '${w}x$h (inset $inset)', (tester) async {
      await pumpZokyApp(tester, width: w, height: h, bottomInset: inset);
      final nav = tester.getRect(find.byType(ZokyBottomNav));
      final context = tester.element(find.byType(ZokyBottomNav));
      // Full width, flush with the bottom edge, items above the inset.
      expect(nav.left, 0);
      expect(nav.width, w);
      expect(nav.bottom, h);
      expect(nav.height, ZokyBottomNav.contentHeight + inset);
      expect(ZokyBottomNav.barHeight(context), nav.height);
      for (final label in _labels) {
        final item = tester.getRect(_item(label));
        expect(item.bottom, lessThanOrEqualTo(h - inset), reason: label);
        expect(item.top, greaterThanOrEqualTo(nav.top), reason: label);
      }

      await _scrollHomeToEnd(tester);
      // The last Home row (Phase 4 cards) ends fully above the bar.
      for (final card in _homeCards().evaluate()) {
        final r = tester.getRect(find.byWidget(card.widget));
        if (r.left >= w) continue; // off-screen to the right in the row
        expect(r.bottom, lessThanOrEqualTo(nav.top), reason: '$r vs $nav');
        expect(r.top, greaterThan(0));
      }
      // Every Text on Home that is on screen is above the bar.
      final home = find.byType(CustomScrollView).first;
      for (final e in find
          .descendant(of: home, matching: find.byType(Text))
          .evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget).first);
        if (r.top >= h || r.bottom <= 0 || r.left >= w) continue;
        expect(r.bottom, lessThanOrEqualTo(nav.top + 0.5), reason: '$r');
      }
    });
  }

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow or clipped label at $width, text $scale', (
        tester,
      ) async {
        await pumpZokyApp(
          tester,
          width: width,
          textScale: scale,
          bottomInset: 34,
        );
        expect(tester.takeException(), isNull);
        for (final selected in _labels) {
          await tester.tap(_inNav(find.text(selected)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final label in _labels) {
            final item = tester.getRect(_item(label));
            final text = tester.getRect(_inNav(find.text(label)));
            expect(text.left, greaterThanOrEqualTo(item.left), reason: label);
            expect(text.right, lessThanOrEqualTo(item.right), reason: label);
            expect(text.top, greaterThanOrEqualTo(item.top), reason: label);
            expect(text.bottom, lessThanOrEqualTo(item.bottom), reason: label);
            // Labels are never ellipsized at these widths.
            final painter = TextPainter(
              text: TextSpan(
                text: label,
                style: tester
                    .widget<AnimatedDefaultTextStyle>(_labelStyle(label))
                    .style,
              ),
              textScaler: TextScaler.linear(
                scale.clamp(1.0, ZokyBottomNav.maxLabelScale),
              ),
              textDirection: TextDirection.ltr,
            )..layout();
            expect(painter.width, lessThanOrEqualTo(text.width + 0.5));
            painter.dispose();
          }
        }
      });
    }
  }

  test('nav colors meet WCAG on the bar (worst case: its bottom stop)', () {
    const bg = ZokyBottomNav.surfaceBottom;
    // Unselected labels (text) >= 4.5, line icons (graphics) >= 3.
    expect(_contrast(ZokyColors.textSecondary, bg), greaterThanOrEqualTo(4.5));
    expect(_contrast(ZokyColors.neutral600, bg), greaterThanOrEqualTo(3));
    // Selected label.
    expect(_contrast(ZokyColors.actionPrimary, bg), greaterThanOrEqualTo(4.5));
    // Selected 3D icon: its body gradient ends >= 3:1 (the bold pink
    // label carries the state in text as well).
    expect(
      _contrast(Zoky3DPalette.pink.bottom, bg),
      greaterThanOrEqualTo(3),
    );
  });
}
