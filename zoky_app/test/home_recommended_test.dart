import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_glossy_heart_button.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/data/store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/deals/domain/deal_models.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_store_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_recommended_stores_section.dart';
import 'package:zoky_app/features/home/widgets/zoky_store_cover.dart';
import 'package:zoky_app/features/home/widgets/zoky_today_deals_section.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import 'support/pump_zoky.dart';

final _featured = [
  for (final id in DemoStoreRepository.featuredStoreIds)
    DemoStoreRepository.stores.firstWhere((s) => s.id == id),
];

Finder _cards() => find.descendant(
  of: find.byType(ZokyRecommendedStoresSection),
  matching: find.byType(ZokyRecommendedStoreCard),
);

Finder _card(ZokyStoreSummary store) => find.byWidgetPredicate(
  (w) => w is ZokyRecommendedStoreCard && w.store.id == store.id,
);

Finder _seeAll() => find.bySemanticsLabel(ZokyStrings.seeAllRecommended);

Finder _row() => find.byKey(ZokyRecommendedStoresSection.rowKey);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Scrolls Home to the end (the Phase 4 row sits above the nav there).
Future<void> _scrollHomeToEnd(WidgetTester tester) async {
  await tester.drag(
    find.byType(CustomScrollView).first,
    const Offset(0, -2000),
  );
  await tester.pumpAndSettle();
}

/// Brings [store]'s card fully into view in the row.
Future<void> _revealCard(WidgetTester tester, ZokyStoreSummary store) async {
  await tester.ensureVisible(_card(store));
  await tester.pumpAndSettle();
}

class _FailingRepository extends DemoStoreRepository {
  @override
  Future<List<ZokyStoreSummary>> fetchRecommended() =>
      Future.error(StateError('x'));
}

class _EmptyRepository extends DemoStoreRepository {
  @override
  Future<List<ZokyStoreSummary>> fetchRecommended() async => const [];
}

Future<void> _pumpSection(WidgetTester tester, StoreRepository repo) =>
    pumpZokyWidget(
      tester,
      ZokyRecommendedStoresSection(
        key: UniqueKey(),
        repository: repo,
        onOpenStore: (_) {},
        onSeeAll: () {},
      ),
    );

void main() {
  test('demo data: every featured store is a sample, with one store '
      'without reviews and one without a delivery estimate', () {
    expect(_featured, isNotEmpty);
    expect(_featured.every((s) => s.isDemo), isTrue);
    expect(
      _featured.every((s) => s.name.endsWith(ZokyStoreSummary.demoNameSuffix)),
      isTrue,
    );
    expect(_featured.where((s) => s.rating == null), isNotEmpty);
    expect(_featured.where((s) => !s.hasEta), isNotEmpty);
    expect(_featured.every((s) => s.coverArt != null), isTrue);
  });

  test('model: rating only with reviews, ETA only with both ends', () {
    const base = ZokyStoreSummary(
      id: 'x',
      name: 'ร้าน',
      isOpen: true,
      deliveryFee: 0,
    );
    expect(base.rating, isNull);
    expect(base.hasEta, isFalse);
    const avgNoCount = ZokyStoreSummary(
      id: 'x',
      name: 'ร้าน',
      isOpen: true,
      deliveryFee: 0,
      ratingAverage: 4.5,
    );
    expect(avgNoCount.rating, isNull);
    const rated = ZokyStoreSummary(
      id: 'x',
      name: 'ร้าน (ร้านตัวอย่าง)',
      isOpen: true,
      deliveryFee: 0,
      ratingAverage: 4.5,
      ratingCount: 3,
      etaMinMinutes: 20,
    );
    expect(rated.rating, 4.5);
    expect(rated.hasEta, isFalse);
    expect(rated.nameWithoutDemoSuffix, 'ร้าน');
    expect(ZokyRecommendedStoreCard.etaLabel(rated), isNull);
  });

  test('repository returns featured stores in priority order', () async {
    final stores = await DemoStoreRepository().fetchRecommended();
    expect(
      stores.map((s) => s.id).toList(),
      DemoStoreRepository.featuredStoreIds,
    );
  });

  testWidgets('section renders under Phase 3 with every featured store', (
    tester,
  ) async {
    await pumpZokyApp(tester, width: 430, height: 932);
    expect(find.byType(ZokyRecommendedStoresSection), findsOneWidget);
    expect(find.text(ZokyStrings.recommendedTitle), findsOneWidget);
    final deals = tester.getRect(find.byType(ZokyTodayDealsSection));
    final title = tester.getRect(find.text(ZokyStrings.recommendedTitle));
    expect(title.top, greaterThanOrEqualTo(deals.bottom));
    expect(_cards(), findsNWidgets(_featured.length));
    for (var i = 0; i < _featured.length; i++) {
      expect(
        tester.widget<ZokyRecommendedStoreCard>(_cards().at(i)).store.id,
        _featured[i].id,
      );
      // Code-drawn cover on each card.
      expect(
        find.descendant(
          of: _cards().at(i),
          matching: find.byType(ZokyStoreCover),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('every card carries the demo badge', (tester) async {
    await pumpZokyApp(tester);
    for (var i = 0; i < _featured.length; i++) {
      expect(
        find.descendant(
          of: _cards().at(i),
          matching: find.text(ZokyStrings.demoBadge),
        ),
        findsOneWidget,
      );
      // The name is shown without the suffix (the badge says it instead).
      expect(
        find.descendant(
          of: _cards().at(i),
          matching: find.text(_featured[i].nameWithoutDemoSuffix),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('rating and time are shown only when the store has them', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    for (final store in _featured) {
      final card = _card(store);
      final star = find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) => w is Zoky3DIcon && w.glyph == Zoky3DGlyph.star,
        ),
      );
      final rating = store.rating;
      if (rating == null) {
        expect(star, findsNothing);
        expect(
          find.descendant(of: card, matching: find.textContaining('.')),
          findsNothing,
        );
      } else {
        expect(star, findsOneWidget);
        expect(
          find.descendant(
            of: card,
            matching: find.text(rating.toStringAsFixed(1)),
          ),
          findsOneWidget,
        );
      }
      final eta = ZokyRecommendedStoreCard.etaLabel(store);
      expect(
        find.descendant(
          of: card,
          matching: find.textContaining(ZokyStrings.minutes),
        ),
        eta == null ? findsNothing : findsOneWidget,
      );
      if (eta != null) {
        expect(find.descendant(of: card, matching: find.text(eta)), findsOne);
      }
    }
  });

  testWidgets('card semantics; no heart on the cover photo', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester);
    expect(
      ZokyRecommendedStoreCard.semanticLabel(_featured.first),
      'ร้านตัวอย่าง ราเมงซอยเจ็ด คะแนน 4.8 ส่งใน 30 ถึง 45 นาที',
    );
    final noRating = _featured.firstWhere((s) => s.rating == null);
    expect(
      ZokyRecommendedStoreCard.semanticLabel(noRating),
      isNot(contains('คะแนน')),
    );
    final noEta = _featured.firstWhere((s) => !s.hasEta);
    expect(
      ZokyRecommendedStoreCard.semanticLabel(noEta),
      isNot(contains('ส่งใน')),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(ZokyStrings.recommendedTitle)),
      isSemantics(isHeader: true),
    );
    expect(tester.getSemantics(_seeAll()), isSemantics(isButton: true));
    for (final store in _featured) {
      final card = find.bySemanticsLabel(
        ZokyRecommendedStoreCard.semanticLabel(store),
      );
      expect(card, findsOneWidget);
      expect(tester.getSemantics(card), isSemantics(isButton: true));
    }
    // Founder 2026-10-17: favorites live on the header heart only.
    expect(
      find.descendant(
        of: find.byType(ZokyRecommendedStoresSection),
        matching: find.byType(ZokyGlossyHeartButton),
      ),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('tapping a card opens that store; back returns home', (
    tester,
  ) async {
    await pumpZokyApp(tester, width: 430, height: 932);
    await _scrollHomeToEnd(tester);
    final store = _featured[1];
    await _revealCard(tester, store);
    await tester.tap(
      find.descendant(
        of: _card(store),
        matching: find.text(store.nameWithoutDemoSuffix),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen), findsOneWidget);
    expect(tester.widget<StoreScreen>(find.byType(StoreScreen)).store, store);
    await tester.tap(find.byTooltip(ZokyStrings.back));
    await tester.pumpAndSettle();
    expect(find.byType(ZokyRecommendedStoresSection), findsOneWidget);
  });

  testWidgets('"ดูทั้งหมด" opens the store listing without the keyboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester, width: 430, height: 932);
    await _scrollHomeToEnd(tester);
    await tester.tap(_seeAll());
    await tester.pumpAndSettle();
    expect(find.byType(StoreSearchScreen), findsOneWidget);
    expect(find.text(ZokyStrings.allStoresTitle), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
    await tester.tap(find.byTooltip(ZokyStrings.back));
    await tester.pumpAndSettle();
    expect(find.byType(StoreSearchScreen), findsNothing);
    semantics.dispose();
  });

  testWidgets('row scrolls horizontally and the next card peeks in', (
    tester,
  ) async {
    await pumpZokyApp(tester, width: 430, height: 932);
    await _scrollHomeToEnd(tester);
    final first = tester.getRect(_cards().first);
    expect(first.left, 16);
    expect(first.width, ZokyRecommendedStoreCard.rowWidth(430));
    final third = tester.getRect(_cards().at(2));
    expect(third.left, lessThan(430));
    expect(third.right, greaterThan(430));
    final last = tester.getRect(_cards().last);
    expect(last.left, greaterThan(430));

    await tester.drag(_row(), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    final lastAfter = tester.getRect(_cards().last);
    expect(lastAfter.right, lessThanOrEqualTo(430 - 16 + 0.5));
    expect(lastAfter.top, last.top);
    // Cards share one height.
    final heights = {
      for (var i = 0; i < _featured.length; i++)
        tester.getSize(_cards().at(i)).height,
    };
    expect(heights.length, 1);
  });

  for (final (w, h, inset) in [
    (430.0, 932.0, 34.0),
    (390.0, 844.0, 34.0),
    (375.0, 667.0, 0.0),
    (320.0, 568.0, 0.0),
  ]) {
    testWidgets('scrolled to the end, the nav covers no card at ${w}x$h '
        '(bottom inset $inset)', (tester) async {
      await pumpZokyApp(tester, width: w, height: h, bottomInset: inset);
      await _scrollHomeToEnd(tester);
      final nav = tester.getRect(find.byKey(ZokyBottomNav.capsuleKey));
      final navTop =
          h - ZokyBottomNav.reservedHeight(tester.element(_row())) + 8;
      // Phase 5 floating capsule: 64pt, lifted by the inset (min 12).
      expect(nav.top, h - ZokyBottomNav.height - (inset > 0 ? inset : 12));
      expect(navTop, nav.top);
      for (var i = 0; i < 2; i++) {
        final card = tester.getRect(_cards().at(i));
        expect(card.bottom, lessThan(nav.top));
        expect(card.bottom, lessThanOrEqualTo(navTop));
        expect(card.top, greaterThan(0));
      }
    });
  }

  testWidgets('section hides itself when the load fails or is empty', (
    tester,
  ) async {
    for (final repo in [_FailingRepository(), _EmptyRepository()]) {
      await _pumpSection(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.recommendedTitle), findsNothing);
      expect(find.byType(ZokyRecommendedStoreCard), findsNothing);
    }
  });

  testWidgets('loading shows skeletons, not empty cards', (tester) async {
    await _pumpSection(
      tester,
      DemoStoreRepository(latency: const Duration(milliseconds: 300)),
    );
    await tester.pump();
    expect(find.byType(ZokyRecommendedStoreCard), findsNothing);
    expect(find.text(ZokyStrings.recommendedTitle), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(ZokyRecommendedStoreCard), findsNWidgets(5));
  });

  testWidgets('a real (non-demo) store gets no badge and its full name', (
    tester,
  ) async {
    const store = ZokyStoreSummary(
      id: 'real',
      name: 'ร้านจริง',
      isOpen: false,
      deliveryFee: 0,
      coverArt: ZokyDealArt.burger,
    );
    await pumpZokyWidget(
      tester,
      Center(
        child: ZokyRecommendedStoreCard(store: store, width: 170, onTap: () {}),
      ),
    );
    expect(find.text(ZokyStrings.demoBadge), findsNothing);
    expect(find.text('ร้านจริง'), findsOneWidget);
    expect(find.text(ZokyStrings.closedLabel), findsOneWidget);
    expect(
      ZokyRecommendedStoreCard.semanticLabel(store),
      'ร้านจริง ${ZokyStrings.closedLabel}',
    );
  });

  test('card text colors meet WCAG AA on white', () {
    expect(
      _contrast(ZokyColors.textPrimary, ZokyColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(ZokyColors.textSecondary, ZokyColors.surface),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(ZokyColors.brandDeep, ZokyColors.surface),
      greaterThanOrEqualTo(4.5),
    );
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('recommended row fits at width $width, text scale $scale', (
        tester,
      ) async {
        await pumpZokyApp(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        // Short, large-text layouts build Phase 4 only once scrolled to.
        await _scrollHomeToEnd(tester);
        expect(tester.takeException(), isNull);
        expect(
          tester.getRect(_cards().first).width,
          ZokyRecommendedStoreCard.rowWidth(width),
        );
        // Every card's texts stay inside it (cards grow taller).
        for (final store in _featured) {
          final card = tester.getRect(_card(store));
          for (final e
              in find
                  .descendant(of: _card(store), matching: find.byType(Text))
                  .evaluate()) {
            final r = tester.getRect(find.byWidget(e.widget));
            expect(r.bottom, lessThanOrEqualTo(card.bottom + 0.5));
            expect(r.right, lessThanOrEqualTo(card.right + 0.5));
            expect(r.left, greaterThanOrEqualTo(card.left - 0.5));
          }
        }
        final seeAll = tester.getRect(
          find.descendant(
            of: find.byType(ZokyRecommendedStoresSection),
            matching: find.text(ZokyStrings.seeAll),
          ),
        );
        expect(seeAll.right, lessThanOrEqualTo(width));
        final nav = tester.getRect(find.byKey(ZokyBottomNav.capsuleKey));
        expect(tester.getRect(_cards().first).bottom, lessThan(nav.top));
      });
    }
  }
}
