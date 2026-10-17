// ZOKY-125 regression: store grid card photos are 1:1 (Founder decision
// 2026-10-17, every food photo is square) and the grid still lays out
// without overflow in 1, 2 and 3 columns.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/widgets/zoky_skeleton.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';

import 'support/pump_zoky.dart';

void main() {
  for (final (width, scale) in [
    (320.0, 1.0),
    (320.0, 1.3),
    (390.0, 2.0), // 1 column
    (430.0, 1.0),
    (932.0, 1.0), // 3 columns
  ]) {
    testWidgets('grid ${width}pt text $scale: every card photo is 1:1, '
        'no overflow', (tester) async {
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      try {
        await pumpZokyWidget(
          tester,
          StoreSearchScreen(
            repository: DemoStoreRepository(),
            autofocus: false,
          ),
          width: width,
          height: 9000,
          textScale: scale,
        );
        await tester.pumpAndSettle();
      } finally {
        FlutterError.onError = old;
      }
      expect(errors, isEmpty, reason: errors.join('\n---\n'));
      final cards = find.byType(ZokyStoreCard);
      expect(cards, findsWidgets);
      for (final e in cards.evaluate()) {
        final photo = find
            .descendant(
              of: find.byWidget(e.widget),
              matching: find.byType(AspectRatio),
            )
            .first;
        final size = tester.getSize(photo);
        expect(size.width, moreOrLessEquals(size.height, epsilon: 0.5));
      }
    });
  }

  testWidgets('store card skeleton matches the 1:1 photo', (tester) async {
    await pumpZokyWidget(
      tester,
      const Center(child: SizedBox(width: 160, child: ZokyStoreCardSkeleton())),
    );
    final size = tester.getSize(find.byType(AspectRatio));
    expect(size.width, moreOrLessEquals(size.height, epsilon: 0.5));
  });
}
