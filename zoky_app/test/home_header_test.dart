import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_glossy_surface.dart';
import 'package:zoky_app/core/widgets/zoky_wordmark.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_address_button.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_header.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_search_field.dart';

import 'support/pump_zoky.dart';

Finder _wordmarkImage() => find.byWidgetPredicate((widget) {
  if (widget is! Image) return false;
  var provider = widget.image;
  if (provider is ResizeImage) provider = provider.imageProvider;
  return provider is AssetImage && provider.assetName == ZokyWordmark.assetPath;
});

Finder _heart() => find.bySemanticsLabel(ZokyStrings.favoriteStores);

void main() {
  testWidgets('header shows the original wordmark asset, labelled ZOKY', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester);
    expect(ZokyWordmark.assetPath, 'assets/images/zoky_wordmark.png');
    final image = find.descendant(
      of: find.byType(ZokyHomeHeader),
      matching: _wordmarkImage(),
    );
    expect(image, findsOneWidget);
    final widget = tester.widget<Image>(image);
    expect(widget.fit, BoxFit.contain);
    expect(widget.color, isNull, reason: 'the logo must never be tinted');
    expect(find.bySemanticsLabel('ZOKY'), findsOneWidget);
    // Rendered box keeps the 1066x590 aspect ratio.
    final size = tester.getSize(image);
    expect(size.width / size.height, closeTo(1066 / 590, 0.01));
    semantics.dispose();
  });

  testWidgets('bundled wordmark is the untouched 1066x590 source PNG', (
    tester,
  ) async {
    final data = await rootBundle.load(ZokyWordmark.assetPath);
    final decoded = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      return (await codec.getNextFrame()).image;
    });
    expect(decoded!.width, 1066);
    expect(decoded.height, 590);
  });

  testWidgets('heart button: Thai label, >=44pt target, opens placeholder', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester);
    expect(_heart(), findsOneWidget);
    expect(tester.getSemantics(_heart()), isSemantics(isButton: true));
    final target = tester.getSize(_heart());
    expect(target.width, greaterThanOrEqualTo(44));
    expect(target.height, greaterThanOrEqualTo(44));
    // The 3D heart is decorative: the button keeps the only label.
    final icon = find.descendant(
      of: find.byType(ZokyHomeHeader),
      matching: find.byType(Zoky3DIcon),
    );
    expect(icon, findsOneWidget);
    expect(tester.widget<Zoky3DIcon>(icon).glyph, Zoky3DGlyph.heart);
    expect(tester.widget<Zoky3DIcon>(icon).semanticLabel, isNull);
    expect(find.bySemanticsLabel(ZokyStrings.favoriteStores), findsOneWidget);

    await tester.tap(_heart());
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.comingSoon), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('header and hero share one glossy brand surface', (tester) async {
    await pumpZokyApp(tester);
    final surfaces = tester
        .widgetList<ZokyGlossySurface>(find.byType(ZokyGlossySurface))
        .toList();
    // Header + the carousel's hero slide (+ its invisible sizing copy).
    expect(surfaces.length, greaterThanOrEqualTo(2));
    for (final surface in surfaces) {
      expect(surface.gradient, same(ZokyGloss.brand));
    }
    expect(
      find.descendant(
        of: find.byType(ZokyHomeHeader),
        matching: find.byType(ZokyGlossySurface),
      ),
      findsOneWidget,
    );
  });

  testWidgets('status bar is light over the pink header, dark elsewhere', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.descendant(
        of: find.byType(ZokyHomeHeader),
        matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      ),
    );
    expect(region.value.statusBarIconBrightness, Brightness.light); // Android
    expect(region.value.statusBarBrightness, Brightness.dark); // iOS
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.light);
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.dark);

    await tester.tap(
      find.descendant(
        of: find.byType(ZokyBottomNav),
        matching: find.text(ZokyStrings.navOrders),
      ),
    );
    await tester.pumpAndSettle();
    expect(SystemChrome.latestStyle?.statusBarIconBrightness, Brightness.dark);
    expect(SystemChrome.latestStyle?.statusBarBrightness, Brightness.light);
  });

  testWidgets('header content stays below the status bar / notch', (
    tester,
  ) async {
    setPhoneViewport(tester);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.resetPadding);
    await pumpZokyApp(tester);
    expect(tester.getTopLeft(_wordmarkImage()).dy, greaterThanOrEqualTo(47));
    // Pink starts at the very top (under the status bar).
    expect(tester.getTopLeft(find.byType(ZokyHomeHeader)).dy, 0);
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('no overflow at width $width, text scale $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpZokyApp(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        final logo = tester.getRect(_wordmarkImage());
        final heart = tester.getRect(_heart());
        expect(logo.left, greaterThanOrEqualTo(12));
        expect(heart.right, lessThanOrEqualTo(width - 12));
        expect(logo.right, lessThan(heart.left));
        expect(logo.width, inInclusiveRange(124, 164));
        // Compact header (Home v2): logo row + address row stay within
        // ~160pt of pink above the floating search field.
        final field = tester.getRect(find.byType(ZokyHomeSearchField));
        expect(field.top, inInclusiveRange(120, 160));
        final address = tester.getRect(find.byType(ZokyHomeAddressButton));
        expect(address.top, greaterThanOrEqualTo(logo.bottom - 8));
        expect(address.bottom, lessThan(field.top));
        expect(address.right, lessThanOrEqualTo(width - 12));
        semantics.dispose();
      });
    }
  }
}
