// QA & Security RE-TEST for ZOKY-127 (store grid photo badges truncated),
// 2026-10-17, after Debug fix 22b33f9.
//
// Independent of `test/store_card_overlay_labels_test.dart`. After the fix
// the badge Text no longer has maxLines, so `didExceedMaxLines` is always
// false and cannot prove "readable" on its own. These tests check instead:
// - every photo badge ("ตัวอย่าง", "โฆษณา", "ปิดอยู่", promo) renders on ONE
//   line (no word split like "โฆษ/ณา"), fully inside the photo, no overlap,
//   not clipped by the photo's rounded clip;
// - the meta row "★ | นาที | กม.": every item on one line, inside the card,
//   no visible separator at the start or end of a line (dangling) and the
//   left-edge clip never cuts text;
// - screen reader label: one node per card, same text as before the fix.
// Grid entries: search, "ดูทั้งหมด", legacy body; synthetic worst cases on
// card widths 120-220pt.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/adaptive/zoky_icons.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_store_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_stores_section.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';

import '../support/pump_zoky.dart';

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

Rect _rect(RenderBox box) =>
    MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

/// Number of lines the paragraph is laid out on.
int _lines(RenderParagraph p) {
  final tp = TextPainter(
    text: p.text,
    textDirection: p.textDirection,
    textScaler: p.textScaler,
  )..layout(maxWidth: p.size.width + 0.01);
  final n = tp.computeLineMetrics().length;
  tp.dispose();
  return n;
}

/// Expected screen reader label (copied from the pre-fix code at a9a3b67).
String _expectedLabel(ZokyStoreSummary s) {
  final parts = <String>['ร้าน${s.name}'];
  final rating = s.rating;
  if (rating != null) {
    parts.add('คะแนน ${rating.toStringAsFixed(1)}');
  } else if (s.isNew) {
    parts.add(ZokyStrings.newStore);
  }
  if (s.hasEta) {
    parts.add(
      'ส่งประมาณ ${s.etaMinMinutes} ถึง ${s.etaMaxMinutes} ${ZokyStrings.minutes}',
    );
  }
  if (!s.isOpen) parts.add('ร้านปิดอยู่');
  if (s.hasPromo) parts.add('โปรโมชัน ${s.promoLabel}');
  if (s.isAd) parts.add(ZokyStrings.adLabel);
  return parts.join(', ');
}

/// All checks for one card; returns issue lines. [metaOneLine]: every meta
/// item on one line (real app grids). Synthetic cards narrower or larger
/// than any real grid only require meta text to be whole (it may wrap).
List<String> _checkCard(
  WidgetTester tester,
  Element cardEl, {
  bool metaOneLine = true,
}) {
  final issues = <String>[];
  final store = (cardEl.widget as ZokyStoreCard).store;
  final id = store.id;
  final card = find.byElementPredicate((e) => identical(e, cardEl));
  final c = tester.getRect(card);
  final photoF = find
      .descendant(of: card, matching: find.byType(AspectRatio))
      .first;
  final p = tester.getRect(photoF);
  if ((p.width - p.height).abs() > 0.5) issues.add('$id: photo not 1:1');

  // --- Photo badges -------------------------------------------------------
  final badge = <String, Rect>{};
  for (final e
      in find
          .descendant(of: photoF, matching: find.byType(RichText))
          .evaluate()) {
    final para = e.renderObject! as RenderParagraph;
    final text = para.text.toPlainText();
    if (text == String.fromCharCode(ZokyIcons.food.codePoint)) continue;
    if (text.length == 1 && text.codeUnitAt(0) > 0xE000) continue; // icon
    final r = _rect(para);
    if (para.didExceedMaxLines || para.debugHasOverflowShader) {
      issues.add('$id: badge "$text" ellipsized/faded');
    }
    if (_lines(para) != 1) {
      issues.add('$id: badge "$text" split over ${_lines(para)} lines');
    }
    // Inside the photo with the 8pt inset (rounded corners clip outside).
    if (r.left < p.left - 0.5 ||
        r.right > p.right - 4 ||
        r.top < p.top + 4 ||
        r.bottom > p.bottom - 4) {
      issues.add('$id: badge "$text" $r not inside photo $p');
    }
    badge[text] = r;
  }
  final ks = badge.keys.toList();
  for (var a = 0; a < ks.length; a++) {
    for (var b = a + 1; b < ks.length; b++) {
      final i = badge[ks[a]]!.intersect(badge[ks[b]]!);
      if (i.width > 0.5 && i.height > 0.5) {
        issues.add('$id: "${ks[a]}" overlaps "${ks[b]}"');
      }
    }
  }
  for (final (shown, label) in [
    (store.isDemo, ZokyStrings.demoBadge),
    (store.isAd, ZokyStrings.adLabel),
    (!store.isOpen, ZokyStrings.closedLabel),
    (store.hasPromo, store.promoLabel),
  ]) {
    if (shown && !badge.containsKey(label)) {
      issues.add('$id: "$label" missing on photo (have ${badge.keys})');
    }
  }
  final eta = ZokyRecommendedStoreCard.etaLabel(store);
  if (eta != null && badge.containsKey(eta)) issues.add('$id: ETA on photo');

  // --- Meta row -----------------------------------------------------------
  final clipF = find.descendant(
    of: card,
    matching: find.byWidgetPredicate((w) => w is ClipRect && w.clipper != null),
  );
  final meta = <String>[
    if (store.rating != null) ...[
      store.rating!.toStringAsFixed(1),
      '(${store.ratingCount})',
    ] else if (store.isNew)
      ZokyStrings.newStore,
    ?eta,
    if (store.distanceKm != null) '${store.distanceKm!.toStringAsFixed(1)} กม.',
  ];
  if (meta.isEmpty) {
    if (clipF.evaluate().isNotEmpty) issues.add('$id: empty meta row shown');
    return issues;
  }
  if (clipF.evaluate().length != 1) {
    issues.add('$id: ${clipF.evaluate().length} meta rows');
    return issues;
  }
  final clip = tester.getRect(clipF);
  final texts = <Rect>[];
  for (final m in meta) {
    final f = find.descendant(of: clipF, matching: find.text(m));
    if (f.evaluate().length != 1) {
      issues.add('$id: meta "$m" shown ${f.evaluate().length}x');
      continue;
    }
    final para = tester.renderObject<RenderParagraph>(
      find.descendant(of: f, matching: find.byType(RichText)),
    );
    final r = _rect(para);
    if (para.didExceedMaxLines || para.debugHasOverflowShader) {
      issues.add('$id: meta "$m" ellipsized');
    }
    if (metaOneLine && _lines(para) != 1) {
      issues.add('$id: meta "$m" split over lines');
    }
    if (r.left < clip.left - 0.5) issues.add('$id: meta "$m" cut on left');
    if (r.right > c.right + 0.5) issues.add('$id: meta "$m" past card');
    if (r.top < p.bottom) issues.add('$id: meta "$m" not below photo');
    texts.add(r);
  }
  final star = find.descendant(
    of: clipF,
    matching: find.byIcon(ZokyIcons.star),
  );
  if (store.rating != null) {
    if (star.evaluate().length != 1) {
      issues.add('$id: star missing');
    } else {
      final r = tester.getRect(star);
      if (r.left < clip.left - 0.5) issues.add('$id: star cut on left');
      texts.add(r);
    }
  }
  // Separators: visible (right of the clip edge) ones need content on both
  // sides on the same line.
  final rules = find.descendant(
    of: clipF,
    matching: find.byWidgetPredicate(
      (w) => w is ColoredBox && w.color == ZokyColors.borderDefault,
    ),
  );
  for (final e in rules.evaluate()) {
    final r = _rect(e.renderObject! as RenderBox);
    if (r.right <= clip.left + 0.5) continue; // hidden at line start
    if (r.left < clip.left - 0.5) {
      issues.add('$id: separator half-visible at $r');
      continue;
    }
    bool sameLine(Rect t) => t.top < r.bottom && t.bottom > r.top;
    final left = texts.any((t) => sameLine(t) && t.right <= r.left + 0.5);
    final right = texts.any((t) => sameLine(t) && t.left >= r.right - 0.5);
    if (!left || !right) {
      issues.add('$id: dangling separator at $r (left: $left, right: $right)');
    }
  }

  // --- Screen reader ------------------------------------------------------
  final sem = tester.getSemantics(card);
  if (sem.label != _expectedLabel(store)) {
    issues.add('$id: semantics "${sem.label}" != "${_expectedLabel(store)}"');
  }
  return issues;
}

Future<List<String>> _checkGrid(WidgetTester tester) async {
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
    await tester.scrollUntilVisible(card, 200, scrollable: vertical);
    await tester.pumpAndSettle();
    issues.addAll(_checkCard(tester, card.evaluate().single));
  }
  return issues;
}

Future<void> _pumpApp(WidgetTester tester, double w, double h, double s) async {
  setPhoneViewport(tester, width: w, height: h, textScale: s);
  await tester.pumpWidget(demoZokyApp());
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await _loadAnuphan();
  });

  group('ZOKY-127 QA re-test: app grids (Anuphan)', () {
    for (final entry in ['search', 'seeAll']) {
      for (final w in [320.0, 360.0, 375.0, 390.0, 414.0, 430.0, 932.0]) {
        for (final s in [1.0, 1.15, 1.3, 1.45, 1.6, 2.0]) {
          testWidgets('$entry ${w.toInt()} text $s', (tester) async {
            final h = w > 600 ? 430.0 : 844.0;
            {
              await _pumpApp(tester, w, h, s);
              final Finder target;
              if (entry == 'search') {
                target = find.text(ZokyStrings.homeSearchPlaceholder);
              } else {
                target = find.descendant(
                  of: find.byType(ZokyRecommendedStoresSection),
                  matching: find.text(ZokyStrings.seeAll),
                );
                await tester.scrollUntilVisible(
                  target,
                  150,
                  scrollable: find
                      .descendant(
                        of: find.byType(CustomScrollView).first,
                        matching: find.byType(Scrollable),
                      )
                      .first,
                );
              }
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
              await tester.tap(target);
              await tester.pumpAndSettle();
              expect(find.byType(StoreSearchScreen), findsOneWidget);
            }
            expect(tester.takeException(), isNull);
            final issues = await _checkGrid(tester);
            expect(issues, isEmpty, reason: issues.join('\n'));
          });
        }
      }
    }
  });

  group('ZOKY-127 QA re-test: synthetic worst cases', () {
    ZokyStoreSummary s(
      String id, {
      bool open = true,
      bool demo = false,
      bool ad = false,
      String? promo,
      int? etaMin,
      int? etaMax,
      double rating = 0,
      int count = 0,
      double? km,
    }) => ZokyStoreSummary(
      id: id,
      name: 'ร้านทดสอบ $id',
      isOpen: open,
      isDemo: demo,
      isAd: ad,
      deliveryFee: 0,
      promoLabel: promo,
      etaMinMinutes: etaMin,
      etaMaxMinutes: etaMax,
      ratingAverage: rating,
      ratingCount: count,
      distanceKm: km,
    );
    final stores = [
      // Stacked: ตัวอย่าง + โฆษณา + ปิดอยู่ (+ promo).
      s(
        'stack3',
        open: false,
        demo: true,
        ad: true,
        etaMin: 20,
        etaMax: 30,
        rating: 4.8,
        count: 1250,
        km: 1.2,
      ),
      s(
        'stack4',
        open: false,
        demo: true,
        ad: true,
        promo: 'ลด ฿30',
        etaMin: 120,
        etaMax: 180,
        rating: 4.85,
        count: 123456,
        km: 12.34,
      ),
      s(
        'adClosed',
        open: false,
        ad: true,
        promo: 'ลด 20%',
        etaMin: 5,
        etaMax: 5,
        km: 0,
      ),
      s('closedOnly', open: false, rating: 3.2, count: 1),
      // Meta row variants.
      s('new', etaMin: 15, etaMax: 25, km: 0.8),
      s('noRatingNotNew', rating: 4.0, etaMin: 15, etaMax: 25),
      s('etaOnly', etaMin: 30, etaMax: 30),
      s('kmOnly', km: 99.9),
      s('nothing', rating: 4.0),
      s('halfEta', etaMin: 10, km: 1.0, rating: 5, count: 9),
      s(
        'longCount',
        rating: 4.9,
        count: 999999999,
        etaMin: 100,
        etaMax: 1000,
        km: 1234.5,
      ),
    ];
    for (final cw in [120.0, 138.0, 160.0, 180.0, 220.0]) {
      for (final sc in [1.0, 1.15, 1.3, 1.45, 2.0]) {
        testWidgets('card ${cw.toInt()}pt text $sc', (tester) async {
          await pumpZokyWidget(
            tester,
            SingleChildScrollView(
              child: Column(
                children: [
                  for (final st in stores)
                    Center(
                      child: SizedBox(
                        width: cw,
                        child: ZokyStoreCard(store: st, onTap: () {}),
                      ),
                    ),
                ],
              ),
            ),
            width: 320,
            height: 12000,
            textScale: sc,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final issues = <String>[
            for (final e in find.byType(ZokyStoreCard).evaluate())
              ..._checkCard(tester, e, metaOneLine: false),
          ];
          expect(issues, isEmpty, reason: issues.join('\n'));
        });
      }
    }
  });

  // Visual evidence for manual review (written to QA_SHOT_DIR if set).
  final shotDir = Platform.environment['QA_SHOT_DIR'];
  for (final (w, sc) in [(320.0, 1.3), (430.0, 1.0), (320.0, 1.0)]) {
    testWidgets('screenshot search grid ${w.toInt()} x $sc', (tester) async {
      await _pumpApp(tester, w, 1400, sc);
      await tester.tap(find.text(ZokyStrings.homeSearchPlaceholder));
      await tester.pumpAndSettle();
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      final img = (await tester.runAsync(
        () => layer.toImage(Offset.zero & view.size, pixelRatio: 2),
      ))!;
      final png = (await tester.runAsync(
        () => img.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      img.dispose();
      if (shotDir != null) {
        File('$shotDir/grid_${w.toInt()}_$sc.png')
            .writeAsBytesSync(png.buffer.asUint8List());
      }
    }, skip: shotDir == null);
  }
}
