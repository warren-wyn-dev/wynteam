// ZOKY-122 regression: the "ร้านโปรด" placeholder sheet is the adaptive
// showZokySheet and fits or scrolls at every size/text scale, on both
// platform styles.
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/app/app_config.dart';
import 'package:zoky_app/app/zoky_app.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final (w, h, scale) in [
      (320.0, 568.0, 2.0),
      (667.0, 375.0, 2.0),
      (932.0, 430.0, 1.6),
    ]) {
      testWidgets('${platform.name} ${w}x$h text $scale: favorites sheet '
          'is adaptive, no overflow, message reachable', (tester) async {
        final errors = <String>[];
        final old = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d.exceptionAsString());
        try {
          tester.view.physicalSize = Size(w, h);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
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
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel(ZokyStrings.favoriteStores));
          await tester.pumpAndSettle();
          final route = ModalRoute.of(
            tester.element(find.text(ZokyStrings.comingSoon)),
          );
          expect(
            route is CupertinoModalPopupRoute,
            platform == TargetPlatform.iOS,
          );
          await tester.ensureVisible(find.text(ZokyStrings.comingSoon));
          await tester.pumpAndSettle();
          final r = tester.getRect(find.text(ZokyStrings.comingSoon));
          expect(r.bottom, lessThanOrEqualTo(h));
          expect(r.top, greaterThanOrEqualTo(0));
        } finally {
          FlutterError.onError = old;
          debugDefaultTargetPlatformOverride = null;
        }
        expect(errors, isEmpty, reason: errors.join('\n---\n'));
      });
    }
  }
}
