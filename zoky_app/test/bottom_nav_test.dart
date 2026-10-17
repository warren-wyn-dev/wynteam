import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show HitTestResult;
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

Zoky3DIcon _icon(WidgetTester tester, String label) =>
    tester.widget<Zoky3DIcon>(
      find.descendant(of: _item(label), matching: find.byType(Zoky3DIcon)).last,
    );

Rect _capsule(WidgetTester tester) =>
    tester.getRect(find.byKey(ZokyBottomNav.capsuleKey));

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
      ..addFont(
        rootBundle.load('assets/fonts/anuphan/Anuphan-VariableFont_wght.ttf'),
      );
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
      tester
          .widget<AnimatedSwitcher>(
            find.descendant(
              of: _item(ZokyStrings.navHome),
              matching: find.byType(AnimatedSwitcher),
            ),
          )
          .duration,
      const Duration(milliseconds: 200),
    );

    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(
      tester
          .widget<AnimatedSwitcher>(
            find.descendant(
              of: _item(ZokyStrings.navHome),
              matching: find.byType(AnimatedSwitcher),
            ),
          )
          .duration,
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
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
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
    testWidgets('capsule floats inset from the sides and above the bottom '
        'and covers no Home row at ${w}x$h (inset $inset)', (tester) async {
      await pumpZokyApp(tester, width: w, height: h, bottomInset: inset);
      final nav = _capsule(tester);
      final context = tester.element(find.byType(ZokyBottomNav));
      // 16pt from each side, lifted by the inset (min 12 without one).
      final offset = inset > 0 ? inset : ZokyBottomNav.minBottomOffset;
      expect(nav.left, ZokyBottomNav.sideMargin);
      expect(nav.right, w - ZokyBottomNav.sideMargin);
      expect(nav.bottom, h - offset);
      expect(nav.height, ZokyBottomNav.height);
      expect(ZokyBottomNav.bottomOffset(context), offset);
      expect(
        ZokyBottomNav.reservedHeight(context),
        ZokyBottomNav.height + offset + 8,
      );
      for (final label in _labels) {
        final item = tester.getRect(_item(label));
        expect(item.bottom, lessThanOrEqualTo(nav.bottom), reason: label);
        expect(item.top, greaterThanOrEqualTo(nav.top), reason: label);
        expect(item.left, greaterThanOrEqualTo(nav.left), reason: label);
        expect(item.right, lessThanOrEqualTo(nav.right), reason: label);
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
      for (final e
          in find
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

  test('nav colors meet WCAG on the capsule and the selected highlight', () {
    const bg = ZokyBottomNav.surface;
    const selected = ZokyBottomNav.selectedFill;
    // Unselected labels (text) >= 4.5, line icons (graphics) >= 3 on white.
    expect(_contrast(ZokyColors.textSecondary, bg), greaterThanOrEqualTo(4.5));
    expect(_contrast(ZokyColors.neutral600, bg), greaterThanOrEqualTo(3));
    // Selected label on the blush highlight.
    expect(
      _contrast(ZokyColors.actionPrimary, selected),
      greaterThanOrEqualTo(4.5),
    );
    // Selected 3D icon: its body gradient ends >= 3:1 on the highlight (the
    // bold pink label carries the state in text as well).
    expect(
      _contrast(Zoky3DPalette.pink.bottom, selected),
      greaterThanOrEqualTo(3),
    );
    // Notification dot (graphic) vs the white capsule and its white ring.
    expect(_contrast(ZokyBottomNav.dotColor, bg), greaterThanOrEqualTo(3));
  });

  Finder highlight() => find.descendant(
    of: find.byType(AnimatedAlign),
    matching: find.byType(DecoratedBox),
  );

  testWidgets('blush highlight sits under the selected item and slides', (
    tester,
  ) async {
    await pumpZokyApp(tester, width: 430, height: 932, bottomInset: 34);
    final nav = _capsule(tester);
    for (final label in [..._labels.skip(1), ZokyStrings.navHome]) {
      await tester.tap(_inNav(find.text(label)));
      await tester.pumpAndSettle();
      final h = tester.getRect(highlight());
      final item = tester.getRect(_item(label));
      // Fills the item slot, 6pt inside the capsule top and bottom.
      expect(h.left, moreOrLessEquals(item.left, epsilon: 0.01), reason: label);
      expect(h.right, moreOrLessEquals(item.right, epsilon: 0.01));
      expect(h.top, nav.top + ZokyBottomNav.innerPadding);
      expect(h.bottom, nav.bottom - ZokyBottomNav.innerPadding);
      final decoration =
          tester.widget<DecoratedBox>(highlight()).decoration
              as ShapeDecoration;
      expect(decoration.color, ZokyBottomNav.selectedFill);
      expect(decoration.shape, isA<StadiumBorder>());
    }
    // Mid-slide the highlight sits between the two slots.
    final from = tester.getRect(_item(ZokyStrings.navHome));
    final to = tester.getRect(_item(ZokyStrings.navAccount));
    await tester.tap(_inNav(find.text(ZokyStrings.navAccount)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final mid = tester.getRect(highlight()).left;
    expect(mid, greaterThan(from.left));
    expect(mid, lessThan(to.left));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
      ZokyBottomNav.highlightDuration,
    );

    // Reduced motion: no slide.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();
    expect(
      tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
      Duration.zero,
    );
  });

  testWidgets('content outside the capsule stays tappable', (tester) async {
    await pumpZokyApp(tester, width: 430, height: 932, bottomInset: 34);
    final nav = _capsule(tester);
    // The nav widget spans the full width; its side margins must not
    // swallow taps meant for the content behind.
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      Offset(4, nav.center.dy),
      tester.view.viewId,
    );
    final navElement = tester.element(find.byType(ZokyBottomNav));
    final navBox = navElement.renderObject;
    expect(result.path.any((e) => identical(e.target, navBox)), isFalse);
    // Control: a tap on the capsule does hit the nav.
    final inside = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      inside,
      nav.center,
      tester.view.viewId,
    );
    expect(inside.path.any((e) => identical(e.target, navBox)), isTrue);
  });

  Widget dotHarness({int current = 0}) => Align(
    alignment: Alignment.bottomCenter,
    child: ZokyBottomNav(
      currentIndex: current,
      onSelected: (_) {},
      items: const [
        ZokyNavItem(label: ZokyStrings.navHome, glyph: Zoky3DGlyph.home),
        ZokyNavItem(label: ZokyStrings.navOrders, glyph: Zoky3DGlyph.receipt),
        ZokyNavItem(
          label: ZokyStrings.navMessages,
          glyph: Zoky3DGlyph.chat,
          showDot: true,
          badgeSemanticLabel: ZokyStrings.navMessagesUnread,
        ),
        ZokyNavItem(label: ZokyStrings.navAccount, glyph: Zoky3DGlyph.person),
      ],
    ),
  );

  Finder dot() => find.byWidgetPredicate((w) {
    if (w is! Container) return false;
    final d = w.decoration;
    return d is BoxDecoration &&
        d.shape == BoxShape.circle &&
        d.color == ZokyBottomNav.dotColor;
  });

  testWidgets('notification dot: red, ringed, at the icon top-right, read '
      'out in semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpZokyWidget(tester, dotHarness());
    expect(dot(), findsOneWidget);
    final d = tester.widget<Container>(dot()).decoration! as BoxDecoration;
    expect(d.color, ZokyColors.error);
    expect(d.color, isNot(ZokyColors.brand));
    expect(d.border, Border.all(color: ZokyColors.neutral0, width: 2));
    final icon = tester.getRect(
      find.descendant(
        of: _item(ZokyStrings.navMessages),
        matching: find.byType(Zoky3DIcon),
      ),
    );
    final r = tester.getRect(dot());
    expect(r.size, const Size(12, 12));
    expect(r.center.dx, greaterThan(icon.center.dx));
    expect(r.center.dy, lessThan(icon.center.dy));
    // Centered on the corner, mostly outside the glyph.
    expect(r.center.dx, moreOrLessEquals(icon.right, epsilon: 1));
    expect(r.center.dy, moreOrLessEquals(icon.top, epsilon: 1));
    // Only on ข้อความ, and only there is it announced.
    expect(
      find.descendant(of: _item(ZokyStrings.navMessages), matching: dot()),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(_item(ZokyStrings.navMessages)),
      isSemantics(
        label: '${ZokyStrings.navMessages}, ${ZokyStrings.navMessagesUnread}',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isSelected: false,
      ),
    );
    expect(
      tester.getSemantics(_item(ZokyStrings.navHome)),
      isSemantics(
        label: ZokyStrings.navHome,
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    // Still shown when its tab is selected.
    await pumpZokyWidget(tester, dotHarness(current: 2));
    expect(dot(), findsOneWidget);
    expect(tester.takeException(), isNull);
    handle.dispose();
  });

  testWidgets('the shipped app shows no notification dot (no unread data)', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    expect(dot(), findsNothing);
  });
}
