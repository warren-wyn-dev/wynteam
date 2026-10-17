// QA & Security RE-TEST round for the Home slice, 2026-10-17 (after the
// ZOKY-120/121/122/123/125 fixes).
//
// Independent of the Debug Engineer's regression tests: wider device matrix,
// many scroll offsets, gesture-driven scrolling, geometry + pixel checks
// under the status bar, status-bar style, the favorites sheet on both
// platform themes, the store grid with the real Anuphan font (demo badge,
// 1:1 photo, overlay truncation) and the rating rule on every surface.
// Known open bugs are reproduced by tests marked `skip:` that reference the
// bug file; un-skip once fixed.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/zoky_app.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/design/zoky_tokens.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';
import 'package:zoky_app/features/deals/widgets/zoky_deal_card.dart';
import 'package:zoky_app/features/home/home_screen.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_header.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_store_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_stores_section.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import '../support/pump_zoky.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  required double width,
  required double height,
  double top = 0,
  double bottom = 0,
  double textScale = 1,
  TargetPlatform? platform,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  final pad = FakeViewPadding(top: top, bottom: bottom);
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  debugDefaultTargetPlatformOverride = platform;
  await tester.pumpWidget(
    ZokyApp(
      config: AppConfig.demo,
      storeRepository: DemoStoreRepository(),
      promotionRepository: const DemoPromotionRepository(),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

ScrollPosition _homePosition(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Rect _rectOf(WidgetTester tester, Element e) {
  final box = e.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Global rect of the Home header (pink is allowed only inside it).
/// (skipOffstage: false: the header is still laid out once scrolled away.)
Rect _headerRect(WidgetTester tester) =>
    tester.getRect(find.byType(ZokyHomeHeader, skipOffstage: false));

/// Global rect of HomeScreen's pink overscroll backdrop (the headerTop
/// ColoredBox that is not part of the header itself).
Rect _backdropRect(WidgetTester tester) {
  final candidates = find
      .descendant(
        of: find.byType(HomeScreen),
        matching: find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == ZokyColors.headerTop,
        ),
      )
      .evaluate()
      .where((e) => e.findAncestorWidgetOfExactType<ZokyHomeHeader>() == null)
      .toList();
  expect(candidates, hasLength(1), reason: 'exactly one backdrop');
  return _rectOf(tester, candidates.single);
}

/// The backdrop's solid headerTop (#F93384), with a small tolerance for
/// antialiasing. Lighter pinks (deal/store art peeking in from the
/// horizontal rows at the right edge) are content, not the backdrop.
bool _pinkish(int r, int g, int b) =>
    (r - 0xF9).abs() <= 10 && (g - 0x33).abs() <= 16 && (b - 0x84).abs() <= 16;

/// RGBA of the top strip [0, height) of the screen.
Future<(ByteData, int)> _topStrip(WidgetTester tester, double height) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final img = (await tester.runAsync(
    () => layer.toImage(Offset.zero & Size(view.size.width, height)),
  ))!;
  final data = (await tester.runAsync(() => img.toByteData()))!;
  final w = img.width;
  img.dispose();
  return (data, w);
}

/// Checks one scroll state: the backdrop lies inside the header, and no
/// pink pixel in the side gutters under the status bar lies outside the
/// header's bottom edge. Returns a description of the first violation or
/// null.
Future<String?> _checkNoExposedPink(
  WidgetTester tester, {
  required double width,
  required double top,
  required String where,
}) async {
  final header = _headerRect(tester);
  final backdrop = _backdropRect(tester);
  // Above the header (iOS bounce gap) pink is intended; below the header's
  // bottom edge it would sit behind content.
  if (backdrop.height > 0.01 && backdrop.bottom > header.bottom + 0.5) {
    return '$where: backdrop $backdrop not covered by header $header';
  }
  final stripH = top + _rest + 20;
  final (data, w) = await _topStrip(tester, stripH);
  final xs = [1, 6, 11, w - 12, w - 7, w - 2];
  for (var y = 0; y < stripH.toInt(); y++) {
    if (y < header.bottom) continue;
    for (final x in xs) {
      final i = (y * w + x) * 4;
      final r = data.getUint8(i), g = data.getUint8(i + 1);
      final b = data.getUint8(i + 2);
      if (_pinkish(r, g, b)) {
        return '$where: pink (${r.toRadixString(16)},${g.toRadixString(16)},'
            '${b.toRadixString(16)}) at ($x,$y) outside header $header';
      }
    }
  }
  return null;
}

List<double> _offsets(double top, double max) {
  final raw = <double>[
    0, 0.5, 1, 2, 3, 5, 8, 10, 13, 16, 20, 24, 30, //
    top + 12, top + 24, top + 47, top + 47.5, top + 48, top + 48.5, top + 49,
    top + 60,
    40, 50, 60, 70, 80, 90, 100, 120, 140, 160, 180, 200, 240, 280, 320,
    400, 500, max / 2, max - 1, max,
  ];
  return {
    for (final o in raw)
      if (o <= max) o,
  }.toList()..sort();
}

Future<void> _loadAnuphan() async {
  final loader = FontLoader('Anuphan')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('assets/fonts/anuphan/Anuphan-VariableFont_wght.ttf')
              .readAsBytesSync(),
        ),
      ),
    );
  await loader.load();
}

Future<List<String>> _captureErrors(Future<void> Function() body) async {
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) => errors.add(d.exceptionAsString());
  try {
    await body();
  } finally {
    FlutterError.onError = old;
  }
  return errors;
}

/// Backdrop height above the top inset at rest (HomeScreen uses s24).
const double _rest = ZokySpacing.s24;

const _portraitSizes = [
  (320.0, 568.0),
  (360.0, 640.0),
  (375.0, 667.0),
  (390.0, 844.0),
  (414.0, 896.0),
  (430.0, 932.0),
];
const _landscapeSizes = [
  (568.0, 320.0),
  (667.0, 375.0),
  (844.0, 390.0),
  (932.0, 430.0),
];
const _insets = [
  (0.0, 0.0),
  (20.0, 0.0),
  (59.0, 0.0),
  (0.0, 34.0),
  (20.0, 34.0),
  (59.0, 34.0),
];
const _scales = [1.0, 1.3, 1.6, 2.0];

/// testWidgets that always clears the platform override before the
/// framework's end-of-test invariant check.
void _testWidgets(String name, WidgetTesterCallback body, {bool? skip}) =>
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }, skip: skip);

void main() {
  // ---------------------------------------------------------------------
  // ZOKY-120 re-test: device matrix x many offsets.
  // ---------------------------------------------------------------------
  group('ZOKY-120 re-test: no pink under the status bar at any offset', () {
    final configs = <(double, double, double, double, double)>[
      for (final (w, h) in _portraitSizes)
        for (final (t, b) in _insets)
          for (final s in _scales) (w, h, t, b, s),
      for (final (w, h) in _landscapeSizes)
        for (final s in _scales) (w, h, 0.0, 0.0, s),
      // Landscape with a (non-standard) top inset and home indicator.
      (932.0, 430.0, 20.0, 21.0, 1.0),
    ];
    for (final (w, h, t, b, s) in configs) {
      _testWidgets('${w.toInt()}x${h.toInt()} top $t bottom $b text $s', (
        tester,
      ) async {
        await _pumpApp(
          tester,
          width: w,
          height: h,
          top: t,
          bottom: b,
          textScale: s,
        );
        final pos = _homePosition(tester);
        // At rest the backdrop has its original size and is hidden.
        expect(_backdropRect(tester).height, closeTo(t + _rest, 0.01));
        final failures = <String>[];
        for (final o in _offsets(t, pos.maxScrollExtent)) {
          pos.jumpTo(o);
          await tester.pump();
          final f = await _checkNoExposedPink(
            tester,
            width: w,
            top: t,
            where: 'offset $o (max ${pos.maxScrollExtent})',
          );
          if (f != null) failures.add(f);
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  });

  group('ZOKY-120 re-test: gesture scrolling, fling, bounce', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final (w, h, t, s) in [
        (390.0, 844.0, 47.0, 1.0),
        (320.0, 568.0, 20.0, 2.0),
        (430.0, 932.0, 59.0, 1.3),
      ]) {
        _testWidgets('${platform.name} ${w}x$h top $t text $s: drag in small '
            'steps down and back up', (tester) async {
          await _pumpApp(
            tester,
            width: w,
            height: h,
            top: t,
            textScale: s,
            platform: platform,
          );
          final pos = _homePosition(tester);
          final gesture = await tester.startGesture(Offset(w / 2, h / 2));
          final failures = <String>[];
          // Up (content scrolls down), then back down.
          for (var i = 0; i < 40; i++) {
            await gesture.moveBy(const Offset(0, -7));
            await tester.pump();
            final f = await _checkNoExposedPink(
              tester,
              width: w,
              top: t,
              where: 'drag up step $i px ${pos.pixels}',
            );
            if (f != null) failures.add(f);
          }
          for (var i = 0; i < 40; i++) {
            await gesture.moveBy(const Offset(0, 7));
            await tester.pump();
            final f = await _checkNoExposedPink(
              tester,
              width: w,
              top: t,
              where: 'drag down step $i px ${pos.pixels}',
            );
            if (f != null) failures.add(f);
          }
          await gesture.up();
          await tester.pumpAndSettle();
          expect(failures, isEmpty, reason: failures.join('\n'));
          expect(pos.pixels, closeTo(0, 0.5));
          expect(_backdropRect(tester).height, closeTo(t + _rest, 0.5));
        });

        _testWidgets('${platform.name} ${w}x$h top $t text $s: fling down, '
            'sample during the ballistic animation', (tester) async {
          await _pumpApp(
            tester,
            width: w,
            height: h,
            top: t,
            textScale: s,
            platform: platform,
          );
          final pos = _homePosition(tester);
          await tester.fling(
            find.byType(CustomScrollView).first,
            const Offset(0, -300),
            3000,
          );
          final failures = <String>[];
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            final f = await _checkNoExposedPink(
              tester,
              width: w,
              top: t,
              where: 'fling frame $i px ${pos.pixels}',
            );
            if (f != null) failures.add(f);
          }
          await tester.pumpAndSettle();
          expect(failures, isEmpty, reason: failures.join('\n'));
        });
      }
    }

    for (final (w, h, t) in [
      (320.0, 568.0, 20.0),
      (375.0, 667.0, 20.0),
      (390.0, 844.0, 47.0),
      (430.0, 932.0, 59.0),
      (932.0, 430.0, 0.0),
    ]) {
      for (final s in [1.0, 2.0]) {
        _testWidgets('iOS ${w}x$h top $t text $s: top overscroll bounce shows '
            'pink across the gap', (tester) async {
          await _pumpApp(
            tester,
            width: w,
            height: h,
            top: t,
            textScale: s,
            platform: TargetPlatform.iOS,
          );
          final pos = _homePosition(tester);
          final gesture = await tester.startGesture(Offset(w / 2, h / 2));
          await gesture.moveBy(const Offset(0, 20));
          await gesture.moveBy(const Offset(0, 180));
          await tester.pump();
          final gap = -pos.pixels;
          expect(gap, greaterThan(20));
          final header = _headerRect(tester);
          expect(header.top, closeTo(gap, 0.5));
          final (data, iw) = await _topStrip(tester, gap.floorToDouble());
          for (var y = 0; y < gap.floor(); y += 3) {
            for (final x in [1, iw ~/ 4, iw ~/ 2, 3 * iw ~/ 4, iw - 2]) {
              final i = (y * iw + x) * 4;
              expect(
                [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)],
                [0xF9, 0x33, 0x84],
                reason: 'gap pixel ($x,$y), gap $gap',
              );
            }
          }
          // Released: bounces back to rest, backdrop back to its size.
          await gesture.up();
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 16));
            final f = await _checkNoExposedPink(
              tester,
              width: w,
              top: t,
              where: 'bounce back frame $i px ${pos.pixels}',
            );
            expect(f, isNull, reason: f);
          }
          await tester.pumpAndSettle();
          expect(pos.pixels, 0);
          expect(_backdropRect(tester).height, closeTo(t + _rest, 0.01));
        });
      }
    }

    _testWidgets('iOS: bounce at the top after a fling from mid-feed is pink', (
      tester,
    ) async {
      await _pumpApp(
        tester,
        width: 390,
        height: 844,
        top: 47,
        textScale: 2,
        platform: TargetPlatform.iOS,
      );
      final pos = _homePosition(tester);
      pos.jumpTo(pos.maxScrollExtent / 2);
      await tester.pump();
      await tester.fling(
        find.byType(CustomScrollView).first,
        const Offset(0, 300),
        6000,
      );
      var sawOverscroll = false;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 8));
        if (pos.pixels < -4) {
          sawOverscroll = true;
          final gap = -pos.pixels;
          final (data, iw) = await _topStrip(tester, gap.floorToDouble());
          final y = (gap / 2).floor();
          final i0 = (y * iw + 1) * 4;
          expect(
            [data.getUint8(i0), data.getUint8(i0 + 1), data.getUint8(i0 + 2)],
            [0xF9, 0x33, 0x84],
          );
        }
      }
      await tester.pumpAndSettle();
      expect(sawOverscroll, isTrue, reason: 'fling should reach the bounce');
      expect(_backdropRect(tester).height, closeTo(47 + _rest, 0.01));
    });

    _testWidgets('scroll, switch tab and come back, then rotate: no pink', (
      tester,
    ) async {
      await _pumpApp(tester, width: 390, height: 844, top: 47, textScale: 1.3);
      final pos = _homePosition(tester);
      pos.jumpTo(150);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZokyStrings.navOrders).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(ZokyStrings.navHome).last);
      await tester.pumpAndSettle();
      expect(pos.pixels, 150);
      expect(
        await _checkNoExposedPink(tester, width: 390, top: 47, where: 'back'),
        isNull,
      );
      // Rotate to landscape: offset clamps, then back to portrait.
      tester.view.physicalSize = const Size(844, 390);
      tester.view.padding = FakeViewPadding.zero;
      tester.view.viewPadding = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(
        await _checkNoExposedPink(tester, width: 844, top: 0, where: 'land'),
        isNull,
      );
      tester.view.physicalSize = const Size(390, 844);
      const pad = FakeViewPadding(top: 47, bottom: 34);
      tester.view.padding = pad;
      tester.view.viewPadding = pad;
      await tester.pumpAndSettle();
      expect(
        await _checkNoExposedPink(tester, width: 390, top: 47, where: 'port'),
        isNull,
      );
    });

    _testWidgets('re-tap Home scrolls to top and restores the rest state', (
      tester,
    ) async {
      await _pumpApp(tester, width: 375, height: 667, top: 20, textScale: 1.3);
      final pos = _homePosition(tester);
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(_backdropRect(tester).height, 0);
      await tester.tap(find.text(ZokyStrings.navHome).last);
      await tester.pumpAndSettle();
      expect(pos.pixels, 0);
      expect(_backdropRect(tester).height, closeTo(20 + _rest, 0.01));
    });

    for (final (w, h, t, s) in [
      (390.0, 844.0, 47.0, 1.0),
      (320.0, 568.0, 20.0, 2.0),
      (430.0, 932.0, 59.0, 1.6),
    ]) {
      _testWidgets('status bar style ${w}x$h top $t text $s: light icons only '
          'while the pink header is under the status bar', (tester) async {
        await _pumpApp(tester, width: w, height: h, top: t, textScale: s);
        final pos = _homePosition(tester);
        final probe = Offset(w / 2, t / 2);
        final failures = <String>[];
        for (final o in _offsets(t, pos.maxScrollExtent)) {
          pos.jumpTo(o);
          await tester.pump();
          final style = tester.binding.renderViews.first.debugLayer!
              .find<SystemUiOverlayStyle>(probe);
          final underHeader = _headerRect(tester).contains(probe);
          final light = style?.statusBarIconBrightness == Brightness.light;
          if (light != underHeader) {
            failures.add(
              'offset $o: header under status bar=$underHeader but icons '
              '${style?.statusBarIconBrightness}',
            );
          }
        }
        expect(failures, isEmpty, reason: failures.join('\n'));
      });
    }
  });

  // ---------------------------------------------------------------------
  // ZOKY-122 re-test: favorites sheet, both platform themes.
  // ---------------------------------------------------------------------
  group('ZOKY-122 re-test: favorites sheet', () {
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final (w, h) in [..._portraitSizes, ..._landscapeSizes]) {
        final landscape = w > h;
        for (final s in [1.0, 1.3, 1.6, 2.0]) {
          final (t, b) = landscape ? (0.0, 21.0) : (59.0, 34.0);
          _testWidgets('${platform.name} ${w.toInt()}x${h.toInt()} text $s', (
            tester,
          ) async {
            final errors = await _captureErrors(() async {
              await _pumpApp(
                tester,
                width: w,
                height: h,
                top: t,
                bottom: b,
                textScale: s,
                platform: platform,
              );
              await tester.tap(
                find.bySemanticsLabel(ZokyStrings.favoriteStores),
              );
              await tester.pumpAndSettle();
              final title = find.text(ZokyStrings.favoriteStores);
              final message = find.text(ZokyStrings.comingSoon);
              expect(title, findsOneWidget);
              expect(message, findsOneWidget);
              // Title readable, not under the status bar / notch.
              final titleRect = tester.getRect(title);
              expect(
                titleRect.top,
                greaterThanOrEqualTo(t),
                reason: 'title under the status bar: $titleRect',
              );
              // Message reachable (scroll if needed) and fully on screen.
              await tester.ensureVisible(message);
              await tester.pumpAndSettle();
              final m = tester.getRect(message);
              expect(m.top, greaterThanOrEqualTo(t));
              expect(m.bottom, lessThanOrEqualTo(h - b + 0.5));
              // Route style follows the platform.
              final route = ModalRoute.of(tester.element(message))!;
              expect(
                route is ModalBottomSheetRoute,
                platform == TargetPlatform.android,
              );
              // Dismiss: tap the barrier above the sheet when there is one,
              // otherwise system back.
              final sheetTop = tester
                  .getRect(
                    find
                        .ancestor(of: title, matching: find.byType(Material))
                        .first,
                  )
                  .top;
              if (sheetTop > t + 10) {
                await tester.tapAt(Offset(w / 2, (sheetTop + t) / 2));
              } else {
                await tester.binding.handlePopRoute();
              }
              await tester.pumpAndSettle();
              expect(find.text(ZokyStrings.comingSoon), findsNothing);
            });
            expect(errors, isEmpty, reason: errors.join('\n---\n'));
          });
        }
      }
    }
  });

  // ---------------------------------------------------------------------
  // ZOKY-123 / ZOKY-125 re-test: store grid with the real font.
  // ---------------------------------------------------------------------
  group('ZOKY-123/125 re-test: store grid (real Anuphan font)', () {
    setUpAll(_loadAnuphan);

    /// Inspects every visible-or-scrollable card; returns issue lines.
    /// [truncated] collects ellipsized overlay labels per card.
    Future<List<String>> inspectGrid(
      WidgetTester tester,
      Map<String, Set<String>> truncated,
    ) async {
      final issues = <String>[];
      final vertical = find
          .ancestor(
            of: find.byType(ZokyStoreCard).first,
            matching: find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            ),
          )
          .first;
      for (final demo in DemoStoreRepository.stores) {
        final card = find.byWidgetPredicate(
          (w) => w is ZokyStoreCard && w.store.id == demo.id,
        );
        tester.state<ScrollableState>(vertical).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(
          card,
          200,
          scrollable: vertical,
          maxScrolls: 200,
        );
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        final store = tester.widget<ZokyStoreCard>(card).store;
        final photo = find
            .descendant(of: card, matching: find.byType(AspectRatio))
            .first;
        final p = tester.getRect(photo);
        if ((p.width - p.height).abs() > 0.5) {
          issues.add('${store.id}: photo ${p.size} not 1:1');
        }
        final badges = find.descendant(
          of: card,
          matching: find.byType(ZokyDemoBadge),
        );
        if (store.isDemo) {
          if (badges.evaluate().length != 1) {
            issues.add('${store.id}: ${badges.evaluate().length} badges');
            continue;
          }
          final br = tester.getRect(badges);
          if (br.left < p.left - 0.5 ||
              br.right > p.right + 0.5 ||
              br.top < p.top - 0.5 ||
              br.bottom > p.bottom + 0.5) {
            issues.add('${store.id}: badge $br outside photo $p');
          }
          final para = tester.renderObject<RenderParagraph>(
            find.descendant(of: badges, matching: find.byType(RichText)),
          );
          if (para.didExceedMaxLines || para.debugHasOverflowShader) {
            issues.add('${store.id}: badge text clipped');
          }
          // Legibility: rendered badge height vs its natural size.
          final natural = para.size.height;
          final rendered = tester
              .getRect(
                find.descendant(of: badges, matching: find.byType(RichText)),
              )
              .height;
          if (rendered < natural * 0.85) {
            issues.add(
              '${store.id}: badge scaled to '
              '${(rendered / natural * 100).toStringAsFixed(0)}%',
            );
          }
        } else if (badges.evaluate().isNotEmpty) {
          issues.add('${store.id}: badge on non-demo store');
        }
        // Visible name never carries the suffix that could be cut.
        final nameTexts = find
            .descendant(of: card, matching: find.byType(Text))
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .where((d) => d.contains('ร้านตัวอย่าง'));
        if (nameTexts.isNotEmpty) {
          issues.add('${store.id}: visible suffix ${nameTexts.toList()}');
        }
        // Overlays inside the photo: no overlap, record truncation.
        final overlayRects = <String, Rect>{};
        for (final e
            in find
                .descendant(of: photo, matching: find.byType(RichText))
                .evaluate()) {
          final para = e.renderObject! as RenderParagraph;
          final text = para.text.toPlainText();
          final r = _rectOf(tester, e);
          if (r.left < p.left - 0.5 ||
              r.right > p.right + 0.5 ||
              r.bottom > p.bottom + 0.5) {
            issues.add('${store.id}: overlay "$text" $r outside photo $p');
          }
          if (para.didExceedMaxLines) {
            truncated.putIfAbsent(store.id, () => {}).add(text);
          }
          overlayRects[text] = r;
        }
        final keys = overlayRects.keys.toList();
        for (var a = 0; a < keys.length; a++) {
          for (var b = a + 1; b < keys.length; b++) {
            final ra = overlayRects[keys[a]]!, rb = overlayRects[keys[b]]!;
            if (ra.overlaps(rb) && ra.intersect(rb).width > 0.5) {
              issues.add('${store.id}: "${keys[a]}" overlaps "${keys[b]}"');
            }
          }
        }
      }
      return issues;
    }

    for (final entry in ['search', 'seeAll', 'legacy']) {
      for (final w in [320.0, 360.0, 375.0, 390.0, 414.0, 430.0, 932.0]) {
        for (final s in [1.0, 1.15, 1.3, 1.45, 1.6, 2.0]) {
          _testWidgets('$entry ${w.toInt()} text $s', (tester) async {
            final h = w > 600 ? 430.0 : 844.0;
            final truncated = <String, Set<String>>{};
            final errors = await _captureErrors(() async {
              if (entry == 'legacy') {
                await pumpZokyWidget(
                  tester,
                  HomeScreen(
                    repository: DemoStoreRepository(),
                    promotionRepository: const DemoPromotionRepository(),
                    showLegacyBody: true,
                  ),
                  width: w,
                  height: h,
                  textScale: s,
                );
                await tester.pumpAndSettle();
              } else {
                await _pumpApp(tester, width: w, height: h, textScale: s);
                if (entry == 'search') {
                  final hero = find.text(ZokyStrings.heroSearchButton);
                  await tester.ensureVisible(hero);
                  await tester.pumpAndSettle();
                  await tester.tap(hero);
                } else {
                  final seeAll = find.descendant(
                    of: find.byType(ZokyRecommendedStoresSection),
                    matching: find.text(ZokyStrings.seeAll),
                  );
                  await tester.scrollUntilVisible(
                    seeAll,
                    150,
                    scrollable: find
                        .descendant(
                          of: find.byType(CustomScrollView).first,
                          matching: find.byType(Scrollable),
                        )
                        .first,
                  );
                  await tester.ensureVisible(seeAll);
                  await tester.pumpAndSettle();
                  await tester.tap(seeAll);
                }
                await tester.pumpAndSettle();
                expect(find.byType(StoreSearchScreen), findsOneWidget);
              }
              final issues = await inspectGrid(tester, truncated);
              expect(issues, isEmpty, reason: issues.join('\n'));
            });
            expect(errors, isEmpty, reason: errors.join('\n---\n'));
            for (final MapEntry(:key, :value) in truncated.entries) {
              final line = '$entry ${w.toInt()} x $s  $key: $value';
              debugPrint('QA-TRUNCATED $line');
            }
          });
        }
      }
    }

    // ZOKY-127 repros: photo overlay labels on the grid are ellipsized
    // because every overlay is capped at half the photo width.
    Future<Map<String, Set<String>>> overlayTruncations(
      WidgetTester tester,
      double width,
      double scale,
    ) async {
      await _pumpApp(tester, width: width, height: 844, textScale: scale);
      await tester.tap(find.text(ZokyStrings.heroSearchButton));
      await tester.pumpAndSettle();
      final vertical = find
          .ancestor(
            of: find.byType(ZokyStoreCard).first,
            matching: find.byType(Scrollable),
          )
          .first;
      final result = <String, Set<String>>{};
      for (final demo in DemoStoreRepository.stores) {
        final card = find.byWidgetPredicate(
          (w) => w is ZokyStoreCard && w.store.id == demo.id,
        );
        tester.state<ScrollableState>(vertical).position.jumpTo(0);
        await tester.pump();
        await tester.scrollUntilVisible(card, 200, scrollable: vertical);
        final photo = find
            .descendant(of: card, matching: find.byType(AspectRatio))
            .first;
        for (final e
            in find
                .descendant(of: photo, matching: find.byType(RichText))
                .evaluate()) {
          final para = e.renderObject! as RenderParagraph;
          if (para.didExceedMaxLines) {
            result.putIfAbsent(demo.id, () => {}).add(para.text.toPlainText());
          }
        }
      }
      return result;
    }

    _testWidgets(
      'ZOKY-127: "โฆษณา" ad disclosure is not truncated at 320pt x text 1.3',
      (tester) async {
        final t = await overlayTruncations(tester, 320, 1.3);
        final ad = {
          for (final e in t.entries)
            if (e.value.contains(ZokyStrings.adLabel)) e.key: e.value,
        };
        expect(ad, isEmpty, reason: '$ad');
      },
    );

    for (final (w, sc) in [(375.0, 1.0), (360.0, 1.3), (320.0, 1.3)]) {
      _testWidgets(
        'ZOKY-127: no photo overlay (promo, closed, ETA, ad) is truncated '
        'at ${w.toInt()}pt x text $sc',
        (tester) async {
          final t = await overlayTruncations(tester, w, sc);
          expect(t, isEmpty, reason: '$t');
        },
      );
    }
  });

  // ---------------------------------------------------------------------
  // ZOKY-121 re-test: rating rule on every surface.
  // ---------------------------------------------------------------------
  group('ZOKY-121 re-test: rating rule', () {
    ZokyStoreSummary store(double avg, int count) => ZokyStoreSummary(
      id: 'qa-$avg-$count',
      name: 'ร้านทดสอบคิวเอ',
      isOpen: true,
      deliveryFee: 0,
      ratingAverage: avg,
      ratingCount: count,
    );

    // (avg, count, expected visible score, expect "ร้านใหม่" on grid/store)
    final cases = <(double, int, String?, bool)>[
      (4.5, 12, '4.5', false),
      (4.56, 3, '4.6', false),
      (0, 0, null, true),
      (4.5, 0, null, false),
      (0, 7, null, true),
      (-1, 5, null, true),
      (double.nan, 5, null, false),
      (4.5, -3, null, false),
    ];

    for (final (avg, count, score, isNewLabel) in cases) {
      _testWidgets('grid card avg $avg count $count', (tester) async {
        final s = store(avg, count);
        await pumpZokyWidget(
          tester,
          SizedBox(
            width: 180,
            child: ZokyStoreCard(store: s, onTap: () {}),
          ),
        );
        final card = find.byType(ZokyStoreCard);
        final semantics = tester.getSemantics(card).label;
        expect(semantics, contains('ร้านทดสอบคิวเอ'));
        if (score != null) {
          expect(
            find.descendant(of: card, matching: find.text(score)),
            findsOneWidget,
          );
          expect(find.text('($count)'), findsOneWidget);
          expect(semantics, contains('คะแนน $score'));
        } else {
          expect(semantics, isNot(contains('คะแนน')));
          expect(find.textContaining(RegExp(r'^\d\.\d$')), findsNothing);
          expect(find.textContaining('NaN'), findsNothing);
          // No star suggesting a score.
          expect(
            find.descendant(
              of: card,
              matching: find.byWidgetPredicate(
                (w) => w is Icon && w.color == ZokyColors.rating,
              ),
            ),
            findsNothing,
          );
        }
        expect(
          find.text(ZokyStrings.newStore),
          isNewLabel ? findsOneWidget : findsNothing,
        );
      });

      _testWidgets('StoreScreen avg $avg count $count', (tester) async {
        await pumpZokyWidget(
          tester,
          StoreScreen(
            store: store(avg, count),
            repository: DemoStoreRepository(),
          ),
        );
        await tester.pumpAndSettle();
        if (score != null) {
          expect(find.text('★ $score'), findsOneWidget);
        } else {
          expect(find.textContaining('★'), findsNothing);
          expect(find.textContaining('NaN'), findsNothing);
        }
        expect(
          find.text(ZokyStrings.newStore),
          isNewLabel ? findsOneWidget : findsNothing,
        );
      });

      _testWidgets('Home recommended card avg $avg count $count', (
        tester,
      ) async {
        await pumpZokyWidget(
          tester,
          Center(
            child: ZokyRecommendedStoreCard(
              store: store(avg, count),
              width: 170,
              onTap: () {},
            ),
          ),
        );
        final handle = tester.ensureSemantics();
        final semantics = tester
            .getSemantics(
              find.bySemanticsLabel(
                ZokyRecommendedStoreCard.semanticLabel(store(avg, count)),
              ),
            )
            .label;
        handle.dispose();
        expect(semantics, contains('ร้านทดสอบคิวเอ'));
        if (score != null) {
          expect(find.text(score), findsOneWidget);
          expect(semantics, contains('คะแนน $score'));
        } else {
          expect(semantics, isNot(contains('คะแนน')));
          expect(find.textContaining(RegExp(r'^\d\.\d$')), findsNothing);
        }
      });
    }

    _testWidgets('demo flow: the same rated store shows the same score on '
        'Home, grid and store page', (tester) async {
      await _pumpApp(tester, width: 390, height: 844);
      final s = DemoStoreRepository.stores.first;
      final expected = s.rating!.toStringAsFixed(1);
      expect(
        find.descendant(
          of: find.byType(ZokyRecommendedStoreCard).first,
          matching: find.textContaining(expected),
        ),
        findsWidgets,
      );
      await tester.tap(find.text(ZokyStrings.heroSearchButton));
      await tester.pumpAndSettle();
      final gridCard = find.byWidgetPredicate(
        (w) => w is ZokyStoreCard && w.store.id == s.id,
      );
      expect(
        find.descendant(of: gridCard, matching: find.text(expected)),
        findsOneWidget,
      );
      await tester.tap(gridCard);
      await tester.pumpAndSettle();
      expect(find.text('★ $expected'), findsOneWidget);
    });
  });
}
