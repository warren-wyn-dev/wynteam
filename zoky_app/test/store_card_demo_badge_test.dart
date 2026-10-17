// ZOKY-123 regression: every sample store on the grid carries the separate
// "ตัวอย่าง" badge, fully visible on the photo, whatever the name length,
// width or text scale (real Anuphan font).
import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/deals/widgets/zoky_deal_card.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';

import 'support/pump_zoky.dart';

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

void main() {
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('grid ${width}pt text $scale: every demo card shows the '
          'whole badge on its photo, no suffix in the name', (tester) async {
        await _loadAnuphan();
        await pumpZokyWidget(
          tester,
          StoreSearchScreen(
            repository: DemoStoreRepository(),
            autofocus: false,
          ),
          width: width,
          height: 6000,
          textScale: scale,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final cards = find.byType(ZokyStoreCard);
        expect(cards, findsWidgets);
        for (final e in cards.evaluate()) {
          final store = (e.widget as ZokyStoreCard).store;
          expect(store.isDemo, isTrue);
          final card = find.byWidget(e.widget);
          final badge = find.descendant(
            of: card,
            matching: find.byType(ZokyDemoBadge),
          );
          expect(badge, findsOneWidget, reason: store.name);
          final cardRect = tester.getRect(card);
          final badgeRect = tester.getRect(badge);
          expect(badgeRect.left, greaterThanOrEqualTo(cardRect.left));
          expect(badgeRect.right, lessThanOrEqualTo(cardRect.right));
          expect(badgeRect.top, greaterThanOrEqualTo(cardRect.top));
          // Badge text is never clipped/ellipsized.
          final text = find.descendant(
            of: badge,
            matching: find.text(ZokyStrings.demoBadge),
          );
          final p = tester.renderObject<RenderParagraph>(text);
          expect(p.didExceedMaxLines, isFalse);
          // No overlap with the other top overlays.
          for (final label in [ZokyStrings.closedLabel, ZokyStrings.adLabel]) {
            final other = find.descendant(of: card, matching: find.text(label));
            if (other.evaluate().isEmpty) continue;
            expect(
              tester.getRect(other).overlaps(badgeRect),
              isFalse,
              reason: '${store.name}: $label',
            );
          }
          expect(
            find.descendant(
              of: card,
              matching: find.textContaining(ZokyStoreSummary.demoNameSuffix),
            ),
            findsNothing,
          );
        }
      });
    }
  }

  testWidgets('non-demo store: no badge, full name', (tester) async {
    const store = ZokyStoreSummary(
      id: 'r',
      name: 'ร้านจริง',
      isOpen: true,
      deliveryFee: 0,
    );
    await pumpZokyWidget(tester, ZokyStoreCard(store: store, onTap: () {}));
    expect(find.byType(ZokyDemoBadge), findsNothing);
    expect(find.text('ร้านจริง'), findsOneWidget);
  });
}
