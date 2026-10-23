// ZOKY-120 regression: the pink overscroll backdrop behind the Home feed
// must show during the top bounce but never behind scrolled content.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pump_zoky.dart';

const List<int> _pink = [0xF9, 0x33, 0x84]; // ZokyColors.headerTop

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  required double height,
  double top = 0,
  double textScale = 1,
  TargetPlatform? platform,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  final pad = FakeViewPadding(top: top);
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  debugDefaultTargetPlatformOverride = platform;
  await tester.pumpWidget(demoZokyApp());
  await tester.pumpAndSettle();
}

ScrollPosition _position(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    )
    .position;

Future<List<int>> _pixel(WidgetTester tester, int x, int y) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final img = (await tester.runAsync(
    () => layer.toImage(Offset.zero & view.size),
  ))!;
  final data = (await tester.runAsync(() => img.toByteData()))!;
  final i = (y * img.width + x) * 4;
  final rgb = [data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2)];
  img.dispose();
  return rgb;
}

void main() {
  testWidgets('iOS top overscroll still reveals pink, not white', (
    tester,
  ) async {
    await _pump(
      tester,
      width: 390,
      height: 844,
      top: 47,
      platform: TargetPlatform.iOS,
    );
    final gesture = await tester.startGesture(const Offset(195, 420));
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 160));
    await tester.pump();
    expect(_position(tester).pixels, lessThan(-20));
    // Just below the top edge, in the gap the header leaves behind.
    expect(await _pixel(tester, 4, 2), _pink);
    expect(await _pixel(tester, 386, 10), _pink);
    await gesture.up();
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  for (final (w, h, top, scale) in [
    (430.0, 932.0, 59.0, 2.0),
    (375.0, 667.0, 20.0, 1.3),
    (932.0, 430.0, 0.0, 1.0),
  ]) {
    testWidgets('${w}x$h top $top text $scale scrolled to the end: no pink '
        'under the status bar', (tester) async {
      await _pump(tester, width: w, height: h, top: top, textScale: scale);
      final pos = _position(tester);
      pos.jumpTo(pos.maxScrollExtent);
      await tester.pumpAndSettle();
      for (final y in [1, (top + 10).toInt(), (top + 23).toInt()]) {
        expect(await _pixel(tester, 4, y), isNot(_pink), reason: 'y=$y');
      }
    });
  }

  testWidgets('scrolled, then the top inset grows (rotation): still no pink', (
    tester,
  ) async {
    await _pump(tester, width: 932, height: 430, textScale: 1.3);
    final pos = _position(tester);
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(430, 932);
    const pad = FakeViewPadding(top: 59);
    tester.view.padding = pad;
    tester.view.viewPadding = pad;
    await tester.pumpAndSettle();
    expect(pos.pixels, greaterThan(100));
    expect(await _pixel(tester, 4, 30), isNot(_pink));
  });

  testWidgets('status bar icons: light over the header at rest, dark over '
      'white content once scrolled (no pink band to rely on)', (tester) async {
    await _pump(tester, width: 430, height: 932, top: 59, textScale: 2);
    SystemUiOverlayStyle? styleAtStatusBar() {
      final layer = tester.binding.renderViews.first.debugLayer!;
      return layer.find<SystemUiOverlayStyle>(const Offset(215, 30));
    }

    expect(styleAtStatusBar()?.statusBarBrightness, Brightness.dark);
    final pos = _position(tester);
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(styleAtStatusBar()?.statusBarBrightness, Brightness.light);
    expect(styleAtStatusBar()?.statusBarIconBrightness, Brightness.dark);
  });
}
