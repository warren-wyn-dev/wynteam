import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_nav_icon.dart';

import 'support/pump_zoky.dart';

void main() {
  testWidgets('every glyph, both states, 26 and 64: custom-painted (no font '
      'glyph, no 3D icon); selected = pink 3D filled', (tester) async {
    await pumpZokyWidget(
      tester,
      Wrap(
        children: [
          for (final glyph in ZokyNavGlyph.values)
            for (final selected in [false, true])
              for (final size in [26.0, 64.0])
                ZokyNavIcon(glyph, selected: selected, size: size),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    for (final g in ZokyNavGlyph.values) {
      expect(find.byKey(ZokyNavIcon.glyphKey(g)), findsNWidgets(4));
    }
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Zoky3DIcon), findsNothing);
    // Filled 3D: gradient body + shade + highlight masks per selected icon
    // (4 glyphs x 2 sizes).
    expect(find.byType(ShaderMask), findsNWidgets(24));
    final icons = tester.widgetList<ZokyNavIcon>(find.byType(ZokyNavIcon));
    for (final (i, icon) in icons.indexed) {
      expect(
        tester.getSize(find.byWidget(icon)),
        Size.square(i.isEven ? 26 : 64),
      );
    }
  });

  test('selected 3D gradient keeps >= 3:1 on the blush highlight', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
    }

    for (final c in ZokyNavIcon.soft3dGradient) {
      expect(contrast(c, ZokyBottomNav.selectedFill), greaterThanOrEqualTo(3));
    }
  });

  testWidgets('a glyph is one CustomPaint at the icon size, decorative', (
    tester,
  ) async {
    await pumpZokyWidget(
      tester,
      const RepaintBoundary(
        child: ZokyNavIcon(ZokyNavGlyph.home, selected: false, size: 64),
      ),
    );
    final key = find.byKey(ZokyNavIcon.glyphKey(ZokyNavGlyph.home));
    expect(key, findsOneWidget);
    final paint = tester.widget<CustomPaint>(
      find.descendant(of: key, matching: find.byType(CustomPaint)),
    );
    expect(paint.painter, isNotNull);
    expect(paint.size, const Size.square(64));
    expect(
      find.ancestor(of: key, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    const icon = ZokyNavIcon(ZokyNavGlyph.home, selected: false);
    expect(icon.size, 26);
    expect(icon.lineColor, ZokyColors.neutral600);
  });

  group('count badge', () {
    Widget nav(int count) => Align(
      alignment: Alignment.bottomCenter,
      child: ZokyBottomNav(
        currentIndex: 2,
        onSelected: (_) {},
        items: [
          const ZokyNavItem(
            label: ZokyStrings.navHome,
            glyph: ZokyNavGlyph.home,
          ),
          const ZokyNavItem(
            label: ZokyStrings.navOrders,
            glyph: ZokyNavGlyph.orders,
          ),
          ZokyNavItem(
            label: ZokyStrings.navMessages,
            glyph: ZokyNavGlyph.messages,
            badgeCount: count,
            badgeSemanticLabel: '$count ข้อความใหม่',
          ),
          const ZokyNavItem(
            label: ZokyStrings.navAccount,
            glyph: ZokyNavGlyph.account,
          ),
        ],
      ),
    );

    for (final (count, text) in [
      (3, '3'),
      (99, '99'),
      (100, '99+'),
      (356, '99+'),
    ]) {
      testWidgets('$count reads "$text": red, white ring, white bold digits', (
        tester,
      ) async {
        await pumpZokyWidget(tester, nav(count));
        expect(tester.takeException(), isNull);
        final label = tester.widget<Text>(find.text(text));
        expect(label.style?.color, ZokyColors.neutral0);
        expect(label.style?.fontWeight, FontWeight.w700);
        final badge = find.ancestor(
          of: find.text(text),
          matching: find.byType(Container),
        );
        final d =
            tester.widget<Container>(badge.first).decoration! as BoxDecoration;
        expect(d.color, ZokyBottomNav.dotColor);
        expect(d.color, isNot(ZokyColors.brandDeep));
        expect(d.border, Border.all(color: ZokyColors.neutral0, width: 2));
        // Anchored at the icon's top-right; wide counts grow rightwards.
        final icon = tester.getRect(find.byType(ZokyNavIcon).at(2));
        final r = tester.getRect(badge.first);
        expect(r.left, moreOrLessEquals(icon.right - 8));
        expect(r.top, moreOrLessEquals(icon.top - 5));
      });
    }

    test('white digits on the badge red meet 4.5:1', () {
      final l = ZokyBottomNav.dotColor.computeLuminance();
      expect(1.05 / (l + 0.05), greaterThan(4.5));
    });
  });
}
