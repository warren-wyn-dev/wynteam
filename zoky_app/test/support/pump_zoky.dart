import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/zoky_app.dart';
import 'package:zoky_app/core/design/zoky_theme.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';

/// Sets a logical phone viewport (devicePixelRatio 1), system text scale and
/// an optional bottom safe-area inset (e.g. 34 for the iPhone home
/// indicator) for the current test; all are reset automatically.
void setPhoneViewport(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  double bottomInset = 0,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  if (bottomInset > 0) {
    final inset = FakeViewPadding(bottom: bottomInset);
    tester.view.padding = inset;
    tester.view.viewPadding = inset;
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pumps [child] inside a MaterialApp with the ZOKY theme and Thai locale.
Future<void> pumpZokyWidget(
  WidgetTester tester,
  Widget child, {
  double width = 390,
  double height = 844,
  double textScale = 1.0,
}) async {
  setPhoneViewport(tester, width: width, height: height, textScale: textScale);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildZokyTheme(),
      locale: const Locale('th'),
      supportedLocales: const [Locale('th')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

/// Pumps the whole app in demo mode (no backend, no network) and lets the
/// demo repository's first load finish.
Future<void> pumpZokyApp(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
  double textScale = 1.0,
  double bottomInset = 0,
}) async {
  setPhoneViewport(
    tester,
    width: width,
    height: height,
    textScale: textScale,
    bottomInset: bottomInset,
  );
  await tester.pumpWidget(
    ZokyApp(
      config: AppConfig.demo,
      storeRepository: DemoStoreRepository(),
      promotionRepository: const DemoPromotionRepository(),
    ),
  );
  // First frame shows skeletons; the zero-latency demo load completes on
  // the next pumps, after which nothing animates and settle returns.
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}
