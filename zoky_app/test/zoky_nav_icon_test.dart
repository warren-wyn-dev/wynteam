import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_nav_icon.dart';

import 'support/pump_zoky.dart';

const _navGlyphs = [
  Zoky3DGlyph.home,
  Zoky3DGlyph.receipt,
  Zoky3DGlyph.chat,
  Zoky3DGlyph.person,
];

const _alternates = [
  ZokyAppleNavIcons.homeAlt,
  ZokyAppleNavIcons.ordersBag,
  ZokyAppleNavIcons.ordersList,
  ZokyAppleNavIcons.messagesPair,
  ZokyAppleNavIcons.messagesDots,
  ZokyAppleNavIcons.accountCircle,
];

void main() {
  for (final style in ZokyNavIconStyle.values) {
    testWidgets('$style renders every nav glyph, both states, 26 and 64', (
      tester,
    ) async {
      await pumpZokyWidget(
        tester,
        Wrap(
          children: [
            for (final glyph in _navGlyphs)
              for (final selected in [false, true])
                for (final size in [26.0, 64.0])
                  ZokyNavIcon(
                    glyph,
                    selected: selected,
                    style: style,
                    size: size,
                  ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      final icons = find.byType(ZokyNavIcon);
      expect(icons, findsNWidgets(16));
      expect(tester.getSize(icons.first), const Size.square(26));
      expect(tester.getSize(icons.at(1)), const Size.square(64));
    });
  }

  testWidgets('Apple style: gray outline, flat brand-deep fill when selected', (
    tester,
  ) async {
    await pumpZokyWidget(
      tester,
      const Row(
        children: [
          ZokyNavIcon(
            Zoky3DGlyph.chat,
            selected: false,
            style: ZokyNavIconStyle.apple,
          ),
          ZokyNavIcon(
            Zoky3DGlyph.chat,
            selected: true,
            style: ZokyNavIconStyle.apple,
          ),
        ],
      ),
    );
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons[0].icon, CupertinoIcons.chat_bubble);
    expect(icons[0].color, ZokyColors.neutral600);
    expect(icons[1].icon, CupertinoIcons.chat_bubble_fill);
    expect(icons[1].color, ZokyNavIcon.appleSelectedColor);
    expect(find.byType(Zoky3DIcon), findsNothing);
  });

  testWidgets('Apple soft 3D: selected fill is layered, outline is not', (
    tester,
  ) async {
    await pumpZokyWidget(
      tester,
      const Row(
        children: [
          ZokyNavIcon(
            Zoky3DGlyph.home,
            selected: true,
            style: ZokyNavIconStyle.appleSoft3d,
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    // Shadow + gradient body + shade + highlight, all the filled glyph.
    final icons = tester.widgetList<Icon>(find.byType(Icon));
    expect(icons.length, 4);
    expect(icons.every((i) => i.icon == CupertinoIcons.house_fill), isTrue);
    expect(find.byType(ShaderMask), findsNWidgets(3));
  });

  testWidgets('alternate CupertinoIcons pairs render in both Apple styles', (
    tester,
  ) async {
    await pumpZokyWidget(
      tester,
      Wrap(
        children: [
          for (final pair in _alternates)
            for (final style in [
              ZokyNavIconStyle.apple,
              ZokyNavIconStyle.appleSoft3d,
            ])
              for (final selected in [false, true])
                ZokyNavIcon(
                  Zoky3DGlyph.receipt,
                  selected: selected,
                  style: style,
                  appleIcons: pair,
                ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    final used = tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon);
    for (final pair in _alternates) {
      expect(used, contains(pair.outline));
      expect(used, contains(pair.fill));
    }
  });

  test('nav glyphs map to Apple pairs; other glyphs do not', () {
    expect(
      ZokyAppleNavIcons.forGlyph(Zoky3DGlyph.home),
      ZokyAppleNavIcons.home,
    );
    expect(
      ZokyAppleNavIcons.forGlyph(Zoky3DGlyph.receipt),
      ZokyAppleNavIcons.orders,
    );
    expect(
      ZokyAppleNavIcons.forGlyph(Zoky3DGlyph.chat),
      ZokyAppleNavIcons.messages,
    );
    expect(
      ZokyAppleNavIcons.forGlyph(Zoky3DGlyph.person),
      ZokyAppleNavIcons.account,
    );
    expect(ZokyAppleNavIcons.forGlyph(Zoky3DGlyph.heart), isNull);
  });

  testWidgets('non-nav glyphs fall back to the classic 3D icon', (
    tester,
  ) async {
    await pumpZokyWidget(
      tester,
      const ZokyNavIcon(
        Zoky3DGlyph.heart,
        selected: true,
        style: ZokyNavIconStyle.apple,
      ),
    );
    expect(find.byType(Zoky3DIcon), findsOneWidget);
  });

  test('Apple selected colors keep >= 3:1 on the blush highlight', () {
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
    }

    const blush = ZokyBottomNav.selectedFill;
    expect(contrast(ZokyNavIcon.appleSelectedColor, blush), greaterThan(4.5));
    for (final c in ZokyNavIcon.soft3dGradient) {
      expect(contrast(c, blush), greaterThanOrEqualTo(3));
    }
  });

  testWidgets('bottom nav keeps the classic 3D icons by default', (
    tester,
  ) async {
    Widget nav(ZokyNavIconStyle? style) => ZokyBottomNav(
      currentIndex: 0,
      onSelected: (_) {},
      iconStyle: style ?? ZokyNavIconStyle.classic3d,
      items: const [
        ZokyNavItem(label: ZokyStrings.navHome, glyph: Zoky3DGlyph.home),
        ZokyNavItem(
          label: ZokyStrings.navOrders,
          glyph: Zoky3DGlyph.receipt,
          appleIcons: ZokyAppleNavIcons.ordersBag,
        ),
      ],
    );
    expect(
      ZokyBottomNav(
        items: const [],
        currentIndex: 0,
        onSelected: (_) {},
      ).iconStyle,
      ZokyNavIconStyle.classic3d,
    );
    await pumpZokyWidget(
      tester,
      Align(alignment: Alignment.bottomCenter, child: nav(null)),
    );
    expect(find.byType(Zoky3DIcon), findsNWidgets(2));

    await pumpZokyWidget(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: nav(ZokyNavIconStyle.apple),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Zoky3DIcon), findsNothing);
    final used = tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon);
    expect(used, contains(CupertinoIcons.house_fill));
    // Per-item alternate replaces the default pair.
    expect(used, contains(CupertinoIcons.bag));
    expect(used, isNot(contains(CupertinoIcons.doc_text)));
  });
}
