// ZOKY-127 regression: the grid card never ellipsizes its photo badges (ad
// disclosure "โฆษณา", promo, closed) and shows the ETA in the meta row under
// the name, fully readable at every phone width and text scale (real
// Anuphan font). Badges stay inside the photo and never overlap.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/adaptive/zoky_icons.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_store_card.dart';
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

/// Every badge on the photo: whole text, inside the photo, no overlap.
/// The ETA is in the card (below the photo), not on it, and not cut.
List<String> _checkCard(WidgetTester tester, Finder card) {
  final issues = <String>[];
  final store = tester.widget<ZokyStoreCard>(card).store;
  final photo = find
      .descendant(of: card, matching: find.byType(AspectRatio))
      .first;
  final p = tester.getRect(photo);
  final rects = <String, Rect>{};
  for (final e
      in find
          .descendant(of: photo, matching: find.byType(RichText))
          .evaluate()) {
    final para = e.renderObject! as RenderParagraph;
    final text = para.text.toPlainText();
    // The cover placeholder glyph is photo content, not a badge.
    if (text == String.fromCharCode(ZokyIcons.food.codePoint)) continue;
    final box = e.renderObject! as RenderBox;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (para.didExceedMaxLines) issues.add('${store.id}: "$text" cut');
    if (r.left < p.left - 0.5 ||
        r.right > p.right + 0.5 ||
        r.top < p.top - 0.5 ||
        r.bottom > p.bottom + 0.5) {
      issues.add('${store.id}: "$text" $r outside photo $p');
    }
    rects[text] = r;
  }
  final keys = rects.keys.toList();
  for (var a = 0; a < keys.length; a++) {
    for (var b = a + 1; b < keys.length; b++) {
      final ra = rects[keys[a]]!, rb = rects[keys[b]]!;
      if (ra.overlaps(rb) && ra.intersect(rb).width > 0.5) {
        issues.add('${store.id}: "${keys[a]}" $ra overlaps "${keys[b]}" $rb');
      }
    }
  }
  for (final (shown, label) in [
    (store.isAd, ZokyStrings.adLabel),
    (!store.isOpen, ZokyStrings.closedLabel),
    (store.hasPromo, store.promoLabel),
  ]) {
    if (shown && !rects.containsKey(label)) {
      issues.add('${store.id}: "$label" missing on photo');
    }
  }
  // Meta/name/tag text stays inside the card (line-start rules are clipped
  // away, never the text itself).
  final c = tester.getRect(card);
  for (final e
      in find
          .descendant(of: card, matching: find.byType(RichText))
          .evaluate()) {
    final box = e.renderObject! as RenderBox;
    final r = box.localToGlobal(Offset.zero) & box.size;
    if (r.left < c.left - 0.5 || r.right > c.right + 0.5) {
      final text = (e.renderObject! as RenderParagraph).text.toPlainText();
      issues.add('${store.id}: "$text" $r outside card $c');
    }
  }
  final eta = ZokyRecommendedStoreCard.etaLabel(store);
  if (eta != null) {
    if (rects.containsKey(eta)) issues.add('${store.id}: ETA on photo');
    final etaText = find.descendant(of: card, matching: find.text(eta));
    if (etaText.evaluate().length != 1) {
      issues.add('${store.id}: ETA "$eta" not shown once');
    } else {
      final para = tester.renderObject<RenderParagraph>(etaText);
      if (para.didExceedMaxLines) issues.add('${store.id}: ETA cut');
      if (tester.getRect(etaText).top < p.bottom) {
        issues.add('${store.id}: ETA not below the photo');
      }
    }
  }
  return issues;
}

void main() {
  setUpAll(_loadAnuphan);

  for (final width in [320.0, 360.0, 375.0, 390.0, 414.0, 430.0]) {
    for (final scale in [1.0, 1.15, 1.3, 1.45, 2.0]) {
      testWidgets('grid ${width.toInt()}pt text $scale: badges whole, ETA in '
          'meta row', (tester) async {
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
        expect(tester.takeException(), isNull);
        final cards = find.byType(ZokyStoreCard);
        expect(cards.evaluate().length, DemoStoreRepository.stores.length);
        final issues = <String>[
          for (final e in cards.evaluate())
            ..._checkCard(tester, find.byWidget(e.widget)),
        ];
        expect(issues, isEmpty, reason: issues.join('\n'));
      });
    }
  }

  // Worst case: every badge at once, long promo, on the narrowest grid
  // column (320pt phone: ~138pt card).
  const busy = ZokyStoreSummary(
    id: 'busy',
    name: 'ร้านตัวอย่างข้าวมันไก่และก๋วยเตี๋ยวต้มยำสูตรโบราณ',
    isOpen: false,
    isDemo: true,
    isAd: true,
    deliveryFee: 15,
    etaMinMinutes: 120,
    etaMaxMinutes: 180,
    promoLabel: 'ลด 20% เมื่อสั่งครบ ฿300',
    ratingAverage: 4.85,
    ratingCount: 123456,
    distanceKm: 12.34,
  );
  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('busy card 138pt text $scale: no cut, no overlap', (
      tester,
    ) async {
      await pumpZokyWidget(
        tester,
        SingleChildScrollView(
          child: Center(
            child: SizedBox(
              width: 138,
              child: ZokyStoreCard(store: busy, onTap: () {}),
            ),
          ),
        ),
        width: 320,
        textScale: scale,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final issues = _checkCard(tester, find.byType(ZokyStoreCard));
      expect(issues, isEmpty, reason: issues.join('\n'));
    });
  }
}
