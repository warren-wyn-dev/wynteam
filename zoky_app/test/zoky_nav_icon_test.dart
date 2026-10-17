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
            Zoky3DGlyph.receipt,
            selected: false,
            style: ZokyNavIconStyle.apple,
          ),
          ZokyNavIcon(
            Zoky3DGlyph.receipt,
            selected: true,
            style: ZokyNavIconStyle.apple,
          ),
        ],
      ),
    );
    final icons = tester.widgetList<Icon>(find.byType(Icon)).toList();
    expect(icons[0].icon, CupertinoIcons.doc_text);
    expect(icons[0].color, ZokyColors.neutral600);
    expect(icons[1].icon, CupertinoIcons.doc_text_fill);
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
            Zoky3DGlyph.person,
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
    expect(icons.every((i) => i.icon == CupertinoIcons.person_fill), isTrue);
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

  for (final (glyph, key) in [
    (Zoky3DGlyph.home, ZokyNavIcon.houseKey),
    (Zoky3DGlyph.chat, ZokyNavIcon.bubbleKey),
  ]) {
    testWidgets('$glyph is custom-painted in the Apple styles (no font '
        'glyph, no classic icon)', (tester) async {
      await pumpZokyWidget(
        tester,
        Wrap(
          children: [
            for (final style in [
              ZokyNavIconStyle.apple,
              ZokyNavIconStyle.appleSoft3d,
            ])
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
      expect(find.byKey(key), findsNWidgets(8));
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Zoky3DIcon), findsNothing);
      // Soft 3D selected: gradient body + shade + highlight masks (x2 sizes).
      expect(find.byType(ShaderMask), findsNWidgets(6));
      final sizes = tester.widgetList<ZokyNavIcon>(find.byType(ZokyNavIcon));
      for (final (i, icon) in sizes.indexed) {
        expect(
          tester.getSize(find.byWidget(icon)),
          Size.square(i.isEven ? 26 : 64),
        );
      }
    });
  }

  testWidgets('an explicit pair replaces the custom glyph', (tester) async {
    await pumpZokyWidget(
      tester,
      const Row(
        children: [
          ZokyNavIcon(
            Zoky3DGlyph.chat,
            selected: false,
            appleIcons: ZokyAppleNavIcons.messages,
          ),
          ZokyNavIcon(
            Zoky3DGlyph.home,
            selected: false,
            appleIcons: ZokyAppleNavIcons.home,
          ),
        ],
      ),
    );
    expect(find.byKey(ZokyNavIcon.bubbleKey), findsNothing);
    expect(find.byKey(ZokyNavIcon.houseKey), findsNothing);
    final used = tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon);
    expect(used, [CupertinoIcons.chat_bubble, CupertinoIcons.house]);
  });

  testWidgets('tiled (M2 / all-tiles): every nav glyph, both states, both '
      'Apple styles, 26 and 64', (tester) async {
    await pumpZokyWidget(
      tester,
      Wrap(
        children: [
          for (final style in [
            ZokyNavIconStyle.apple,
            ZokyNavIconStyle.appleSoft3d,
          ])
            for (final glyph in _navGlyphs)
              for (final selected in [false, true])
                for (final size in [26.0, 64.0])
                  ZokyNavIcon(
                    glyph,
                    selected: selected,
                    style: style,
                    size: size,
                    tiled: true,
                  ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(ZokyNavIcon.tileKey), findsNWidgets(32));
    // Custom house and bubble are drawn inside the tile, not as fonts.
    final used = tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon);
    expect(used, isNot(contains(CupertinoIcons.chat_bubble)));
    expect(used, isNot(contains(CupertinoIcons.house)));
    expect(used, containsAll([CupertinoIcons.doc_text, CupertinoIcons.person]));
    // Selected tiles hold a white glyph.
    final white = tester
        .widgetList<Icon>(find.byType(Icon))
        .where((i) => i.color == ZokyColors.neutral0);
    expect(white.map((i) => i.icon).toSet(), {
      CupertinoIcons.doc_text_fill,
      CupertinoIcons.person_fill,
    });
  });

  testWidgets('tiled has no effect in the classic style', (tester) async {
    await pumpZokyWidget(
      tester,
      const ZokyNavIcon(
        Zoky3DGlyph.chat,
        selected: true,
        style: ZokyNavIconStyle.classic3d,
        tiled: true,
      ),
    );
    expect(find.byKey(ZokyNavIcon.tileKey), findsNothing);
    expect(find.byType(Zoky3DIcon), findsOneWidget);
  });

  testWidgets('bottom nav ships the rounded set by default; alternates, '
      'tiles and classic stay available', (tester) async {
    Widget nav(ZokyNavIconStyle? style) => ZokyBottomNav(
      currentIndex: 0,
      onSelected: (_) {},
      iconStyle: style ?? ZokyNavIconStyle.rounded,
      items: const [
        ZokyNavItem(label: ZokyStrings.navHome, glyph: Zoky3DGlyph.home),
        ZokyNavItem(
          label: ZokyStrings.navOrders,
          glyph: Zoky3DGlyph.receipt,
          appleIcons: ZokyAppleNavIcons.ordersBag,
        ),
        ZokyNavItem(
          label: ZokyStrings.navMessages,
          glyph: Zoky3DGlyph.chat,
          tiled: true,
        ),
        ZokyNavItem(label: ZokyStrings.navAccount, glyph: Zoky3DGlyph.person),
      ],
    );
    final defaults = ZokyBottomNav(
      items: const [],
      currentIndex: 0,
      onSelected: (_) {},
    );
    expect(defaults.iconStyle, ZokyNavIconStyle.rounded);
    expect(defaults.selectedGlyph, ZokyNavSelectedGlyph.filled3d);
    const icon = ZokyNavIcon(Zoky3DGlyph.home, selected: false);
    expect(icon.style, ZokyNavIconStyle.rounded);
    expect(icon.selectedGlyph, ZokyNavSelectedGlyph.filled3d);
    await pumpZokyWidget(
      tester,
      Align(alignment: Alignment.bottomCenter, child: nav(null)),
    );
    expect(find.byType(Zoky3DIcon), findsNothing);
    expect(find.byKey(ZokyNavIcon.roundedKey(Zoky3DGlyph.home)), findsOne);
    expect(find.byKey(ZokyNavIcon.roundedKey(Zoky3DGlyph.person)), findsOne);
    // A per-item pair or tile falls back to the D2 rendering.
    expect(
      find.byKey(ZokyNavIcon.roundedKey(Zoky3DGlyph.receipt)),
      findsNothing,
    );
    expect(find.byKey(ZokyNavIcon.tileKey), findsOneWidget);
    final used = tester.widgetList<Icon>(find.byType(Icon)).map((i) => i.icon);
    expect(used, contains(CupertinoIcons.bag));

    await pumpZokyWidget(
      tester,
      Align(
        alignment: Alignment.bottomCenter,
        child: nav(ZokyNavIconStyle.classic3d),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Zoky3DIcon), findsNWidgets(4));
    expect(find.byKey(ZokyNavIcon.tileKey), findsNothing);
  });

  group('rounded set (Founder reference 2026-10-17)', () {
    test('every nav glyph has a rounded version; others do not', () {
      for (final g in _navGlyphs) {
        expect(ZokyNavIcon.hasRounded(g), isTrue, reason: '$g');
      }
      expect(ZokyNavIcon.hasRounded(Zoky3DGlyph.heart), isFalse);
    });

    for (final treatment in ZokyNavSelectedGlyph.values) {
      testWidgets('$treatment: every glyph, both states, 26 and 64, '
          'custom-painted (no font glyph, no classic icon)', (tester) async {
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
                      size: size,
                      selectedGlyph: treatment,
                    ),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        for (final g in _navGlyphs) {
          expect(find.byKey(ZokyNavIcon.roundedKey(g)), findsNWidgets(4));
        }
        expect(find.byType(Icon), findsNothing);
        expect(find.byType(Zoky3DIcon), findsNothing);
        // Filled 3D: gradient body + shade + highlight masks per selected
        // icon (4 glyphs x 2 sizes); the pink outline is flat.
        expect(
          find.byType(ShaderMask),
          findsNWidgets(treatment == ZokyNavSelectedGlyph.filled3d ? 24 : 0),
        );
        final icons = tester.widgetList<ZokyNavIcon>(find.byType(ZokyNavIcon));
        for (final (i, icon) in icons.indexed) {
          expect(
            tester.getSize(find.byWidget(icon)),
            Size.square(i.isEven ? 26 : 64),
          );
        }
      });
    }

    testWidgets('non-nav glyphs fall back to the classic 3D icon', (
      tester,
    ) async {
      await pumpZokyWidget(
        tester,
        const ZokyNavIcon(Zoky3DGlyph.heart, selected: true),
      );
      expect(find.byType(Zoky3DIcon), findsOneWidget);
    });

    testWidgets('a rounded glyph is one CustomPaint at the icon size', (
      tester,
    ) async {
      await pumpZokyWidget(
        tester,
        const RepaintBoundary(
          child: ZokyNavIcon(Zoky3DGlyph.home, selected: false, size: 64),
        ),
      );
      final key = find.byKey(ZokyNavIcon.roundedKey(Zoky3DGlyph.home));
      expect(key, findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.descendant(of: key, matching: find.byType(CustomPaint)),
      );
      expect(paint.painter, isNotNull);
      expect(paint.size, const Size.square(64));
    });
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
            glyph: Zoky3DGlyph.home,
          ),
          const ZokyNavItem(
            label: ZokyStrings.navOrders,
            glyph: Zoky3DGlyph.receipt,
          ),
          ZokyNavItem(
            label: ZokyStrings.navMessages,
            glyph: Zoky3DGlyph.chat,
            badgeCount: count,
            badgeSemanticLabel: '$count ข้อความใหม่',
          ),
          const ZokyNavItem(
            label: ZokyStrings.navAccount,
            glyph: Zoky3DGlyph.person,
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
