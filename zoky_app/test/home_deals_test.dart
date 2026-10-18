import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/features/deals/data/demo_promotion_repository.dart';
import 'package:zoky_app/features/deals/data/promotion_repository.dart';
import 'package:zoky_app/features/deals/deal_sheet.dart';
import 'package:zoky_app/features/deals/deals_screen.dart';
import 'package:zoky_app/features/deals/domain/deal_models.dart';
import 'package:zoky_app/features/deals/widgets/zoky_deal_card.dart';
import 'package:zoky_app/features/deals/widgets/zoky_deal_illustration.dart';
import 'package:zoky_app/features/home/widgets/zoky_food_hero_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_today_deals_section.dart';

import 'support/pump_zoky.dart';

const _deals = DemoPromotionRepository.deals;

Finder _homeCards() => find.descendant(
  of: find.byType(ZokyTodayDealsSection),
  matching: find.byType(ZokyDealCard),
);

Finder _seeAll() => find.bySemanticsLabel(ZokyStrings.seeAllDeals);

/// "ดูทั้งหมด" text of this section (Phase 4 has one too).
Finder _seeAllText() => find.descendant(
  of: find.byType(ZokyTodayDealsSection),
  matching: find.text(ZokyStrings.seeAll),
);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class _FailingRepository implements PromotionRepository {
  @override
  Future<List<ZokyDeal>> fetchTodayDeals() => Future.error(StateError('x'));
}

class _EmptyRepository implements PromotionRepository {
  @override
  Future<List<ZokyDeal>> fetchTodayDeals() async => const [];
}

void main() {
  testWidgets('section shows heading, demo note, see-all and every deal', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester, height: 1600);
    expect(find.byType(ZokyTodayDealsSection), findsOneWidget);
    expect(find.text(ZokyStrings.dealsTitle), findsOneWidget);
    expect(_seeAllText(), findsOneWidget);
    expect(find.text(ZokyStrings.dealsDemoNote), findsOneWidget);
    expect(_homeCards(), findsNWidgets(_deals.length));
    for (final deal in _deals) {
      expect(find.text(deal.headline), findsOneWidget);
      expect(find.text(deal.description), findsOneWidget);
    }
    // Section sits below the hero card.
    final hero = tester.getRect(find.byType(ZokyFoodHeroCard));
    final title = tester.getRect(find.text(ZokyStrings.dealsTitle));
    expect(title.top, greaterThan(hero.bottom));
    // Each card: one illustration and one small 3D arrow.
    for (var i = 0; i < _deals.length; i++) {
      final card = _homeCards().at(i);
      expect(
        find.descendant(of: card, matching: find.byType(ZokyDealIllustration)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (w) => w is Zoky3DIcon && w.glyph == Zoky3DGlyph.arrowRight,
          ),
        ),
        findsOneWidget,
      );
    }
    semantics.dispose();
  });

  testWidgets('every card is labelled as sample data', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester, height: 1600);
    expect(_deals.every((d) => d.isDemo), isTrue);
    for (var i = 0; i < _deals.length; i++) {
      expect(
        find.descendant(
          of: _homeCards().at(i),
          matching: find.text(ZokyStrings.demoBadge),
        ),
        findsOneWidget,
      );
    }
    semantics.dispose();
  });

  testWidgets('heading, card buttons and see-all have semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester, height: 1600);
    expect(
      tester.getSemantics(find.bySemanticsLabel(ZokyStrings.dealsTitle)),
      isSemantics(isHeader: true),
    );
    expect(tester.getSemantics(_seeAll()), isSemantics(isButton: true));
    expect(
      ZokyDealCard.semanticLabel(_deals.first),
      'ตัวอย่างดีล: ลด 50% ชานมไข่มุก',
    );
    for (final deal in _deals) {
      final label = find.bySemanticsLabel(ZokyDealCard.semanticLabel(deal));
      expect(label, findsOneWidget);
      expect(tester.getSemantics(label), isSemantics(isButton: true));
    }
    // Illustrations add no nodes of their own.
    expect(
      find.bySemanticsLabel(RegExp('bubble|chicken|burger')),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('row scrolls horizontally and the next card peeks in', (
    tester,
  ) async {
    await pumpZokyApp(tester, width: 390, height: 1600);
    final second = tester.getRect(_homeCards().at(1));
    expect(second.left, lessThan(390));
    expect(second.right, greaterThan(390));
    final first = tester.getRect(_homeCards().first);
    expect(first.left, 16);
    final last = tester.getRect(_homeCards().last);
    expect(last.left, greaterThan(390));

    await tester.drag(
      find.byKey(ZokyTodayDealsSection.rowKey),
      const Offset(-1000, 0),
    );
    await tester.pumpAndSettle();
    final lastAfter = tester.getRect(_homeCards().last);
    expect(lastAfter.right, lessThanOrEqualTo(390 - 16 + 0.5));
    expect(lastAfter.top, last.top);
    // Cards share one height and are comfortably above 44pt.
    final heights = {
      for (var i = 0; i < _deals.length; i++)
        tester.getSize(_homeCards().at(i)).height,
    };
    expect(heights.length, 1);
    expect(heights.single, greaterThanOrEqualTo(ZokyDealCard.minHeight));
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets('tapping a card opens the deal sheet (${platform.name})', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      try {
        await pumpZokyApp(tester, height: 1600);
        await tester.tap(_homeCards().first);
        await tester.pumpAndSettle();
        expect(find.byType(ZokyDealDetail), findsOneWidget);
        expect(find.text(ZokyStrings.demoDealDisclaimer), findsOneWidget);
        expect(find.text(_deals.first.storeName!), findsOneWidget);
        if (platform == TargetPlatform.iOS) {
          expect(find.byType(BottomSheet), findsNothing);
          final route = ModalRoute.of(
            tester.element(find.byType(ZokyDealDetail)),
          );
          expect(route, isA<CupertinoModalPopupRoute<void>>());
        } else {
          expect(find.byType(BottomSheet), findsOneWidget);
        }
        await tester.tap(find.text(ZokyStrings.close));
        await tester.pumpAndSettle();
        expect(find.byType(ZokyDealDetail), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets('sheet shows the minimum order of a deal that has one', (
    tester,
  ) async {
    final burger = _deals.firstWhere((d) => d.minSubtotal > 0);
    await pumpZokyWidget(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showZokyDealSheet(context, burger),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('เมื่อสั่งครบ ฿199'), findsOneWidget);
    expect(find.text(ZokyStrings.demoBadge), findsOneWidget);
  });

  testWidgets('"ดูทั้งหมด" opens the deals list; back returns home', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester, height: 1600);
    await tester.tap(_seeAll());
    await tester.pumpAndSettle();
    expect(find.byType(DealsScreen), findsOneWidget);
    expect(find.text(ZokyStrings.dealsDemoNote), findsOneWidget);
    final list = find.descendant(
      of: find.byType(DealsScreen),
      matching: find.byType(ZokyDealCard),
    );
    // Lazy list: scroll to the end so every card is built once.
    final seen = <String>{};
    for (var i = 0; i < 4; i++) {
      for (final e in list.evaluate()) {
        seen.add((e.widget as ZokyDealCard).deal.id);
      }
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(seen, {for (final d in _deals) d.id});
    await tester.tap(list.last);
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.demoDealDisclaimer), findsOneWidget);
    await tester.tap(find.text(ZokyStrings.close));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(ZokyStrings.back));
    await tester.pumpAndSettle();
    expect(find.byType(DealsScreen), findsNothing);
    expect(find.byType(ZokyTodayDealsSection), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('section hides itself when deals fail or are empty', (
    tester,
  ) async {
    for (final repo in [_FailingRepository(), _EmptyRepository()]) {
      await pumpZokyWidget(
        tester,
        ZokyTodayDealsSection(
          key: UniqueKey(),
          repository: repo,
          onOpenDeal: (_) {},
          onSeeAll: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(ZokyStrings.dealsTitle), findsNothing);
      expect(find.byType(ZokyDealCard), findsNothing);
    }
  });

  test('headline follows the web foodPromoLabel rules', () {
    ZokyDeal deal(ZokyDealType type, {num value = 0, num min = 0}) => ZokyDeal(
      id: 'x',
      name: '1 แถม 1',
      type: type,
      value: value,
      minSubtotal: min,
      description: 'd',
      art: ZokyDealArt.burger,
    );
    expect(deal(ZokyDealType.percentage, value: 50).headline, 'ลด 50%');
    expect(deal(ZokyDealType.percentage, value: 12.5).headline, 'ลด 12.5%');
    expect(deal(ZokyDealType.fixed, value: 30).headline, 'ลด ฿30');
    expect(deal(ZokyDealType.freeDelivery).headline, 'ส่งฟรี');
    expect(deal(ZokyDealType.other).headline, '1 แถม 1');
    expect(deal(ZokyDealType.other).minimumLabel, isNull);
    expect(
      deal(ZokyDealType.fixed, value: 30, min: 199).minimumLabel,
      'เมื่อสั่งครบ ฿199',
    );
    // A real (non-demo) deal is not announced as a sample.
    expect(ZokyDealCard.semanticLabel(deal(ZokyDealType.other)), '1 แถม 1 d');
  });

  test('headline color meets WCAG large-text contrast on both tints', () {
    final style = ZokyDealCard.headlineStyle;
    expect(style.fontSize, greaterThanOrEqualTo(18.66));
    expect(style.fontWeight!.value, greaterThanOrEqualTo(700));
    for (final tint in ZokyDealTint.values) {
      for (final bg in [tint.top, tint.bottom]) {
        expect(_contrast(style.color!, bg), greaterThanOrEqualTo(3.0));
        // Description is ink.
        expect(
          _contrast(ZokyColors.textPrimary, bg),
          greaterThanOrEqualTo(4.5),
        );
      }
    }
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('deals fit at width $width, text scale $scale', (
        tester,
      ) async {
        await pumpZokyApp(tester, width: width, height: 1600, textScale: scale);
        expect(tester.takeException(), isNull);
        final first = tester.getRect(_homeCards().first);
        expect(first.left, 16);
        expect(first.width, ZokyDealCard.rowWidth(width));
        // Every card's text stays inside the card (cards grow taller).
        for (var i = 0; i < _deals.length; i++) {
          final card = tester.getRect(_homeCards().at(i));
          for (final text in [_deals[i].headline, _deals[i].description]) {
            final r = tester.getRect(
              find.descendant(
                of: _homeCards().at(i),
                matching: find.text(text),
              ),
            );
            expect(r.bottom, lessThanOrEqualTo(card.bottom));
            expect(r.right, lessThanOrEqualTo(card.right));
          }
        }
        final seeAll = tester.getRect(_seeAllText());
        expect(seeAll.right, lessThanOrEqualTo(width));
        expect(
          tester
              .getSize(
                find.ancestor(
                  of: _seeAllText(),
                  matching: find.byType(InkWell),
                ),
              )
              .height,
          greaterThanOrEqualTo(44),
        );

        // Bottom nav is untouched.
        expect(find.byType(ZokyBottomNav), findsOneWidget);

        // The list page and the sheet fit too (scroll the section clear of
        // the floating nav first on short, large-text layouts).
        await tester.drag(
          find.byType(CustomScrollView).first,
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        await tester.tap(_seeAllText());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(
          find
              .descendant(
                of: find.byType(DealsScreen),
                matching: find.byType(ZokyDealCard),
              )
              .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('loading shows skeletons, not empty cards', (tester) async {
    await pumpZokyWidget(
      tester,
      ZokyTodayDealsSection(
        repository: const DemoPromotionRepository(
          latency: Duration(milliseconds: 300),
        ),
        onOpenDeal: (_) {},
        onSeeAll: () {},
      ),
    );
    await tester.pump();
    expect(find.byType(ZokyDealCard), findsNothing);
    expect(find.text(ZokyStrings.dealsTitle), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(ZokyDealCard), findsNWidgets(_deals.length));
  });
}
