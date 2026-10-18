import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/design/zoky_colors.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_3d_icon.dart';
import 'package:zoky_app/core/widgets/zoky_glossy_surface.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/home/widgets/zoky_bento_illustration.dart';
import 'package:zoky_app/features/home/widgets/zoky_food_hero_card.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_banner_carousel.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_header.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import 'support/pump_zoky.dart';

/// The hero slide of the Home banner carousel (not its invisible sizing
/// copy).
Finder _hero() => find.descendant(
  of: find.byKey(ZokyHomeBannerCarousel.pagerKey),
  matching: find.byType(ZokyFoodHeroCard),
);

/// The hero slide is one screen-reader node (PageView merges a page):
/// pill, title and subtitle in one label, flagged as a heading.
Finder _heroNode(String part) =>
    find.bySemanticsLabel(RegExp(RegExp.escape(part)));

Finder _inHero(Finder finder) => find.descendant(of: _hero(), matching: finder);

/// Home v2 search entry (replaces the hero's search button).
Finder _search() => find.bySemanticsLabel(ZokyStrings.homeSearchPlaceholder);

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('hero shows pill, title and subtitle; no search button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester);
    final hero = _hero();
    expect(hero, findsOneWidget);
    for (final text in [
      ZokyStrings.heroFoodDelivery,
      ZokyStrings.heroTitleLines,
      ...ZokyFoodHeroCard.subtitlePhrases,
    ]) {
      expect(
        find.descendant(of: hero, matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(ZokyFoodHeroCard.subtitlePhrases.join(), ZokyStrings.heroSubtitle);
    expect(_heroNode(ZokyStrings.heroSubtitle), findsOneWidget);
    expect(find.text(ZokyStrings.heroSearchButton), findsNothing);
    expect(_inHero(find.byType(ZokyBentoIllustration)), findsOneWidget);
    // One brand surface: the card uses the header's glossy recipe.
    expect(
      find.descendant(of: hero, matching: find.byType(ZokyGlossySurface)),
      findsOneWidget,
    );
    expect(ZokyFoodHeroCard.background, same(ZokyGloss.brand));
    // Decorative 3D sparkle in the pill; the search button's arrow is gone.
    Finder glyph(Zoky3DGlyph g) =>
        _inHero(find.byWidgetPredicate((w) => w is Zoky3DIcon && w.glyph == g));
    expect(glyph(Zoky3DGlyph.sparkle), findsOneWidget);
    expect(glyph(Zoky3DGlyph.arrowRight), findsNothing);
    // Home v2: the hero is the first carousel slide, under the header and
    // the floating search field.
    final header = tester.getRect(find.byType(ZokyHomeHeader));
    final field = tester.getRect(_search());
    final card = tester.getRect(hero);
    expect(card.top, greaterThan(field.bottom));
    expect(card.top, greaterThanOrEqualTo(header.bottom));
    semantics.dispose();
  });

  testWidgets('title is a heading (once); art is decorative', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester);
    // The invisible sizing copy adds no second heading.
    expect(_heroNode(ZokyStrings.heroTitle), findsOneWidget);
    expect(
      tester.getSemantics(_heroNode(ZokyStrings.heroTitle)),
      isSemantics(isHeader: true),
    );
    expect(find.bySemanticsLabel(ZokyStrings.heroSearchButton), findsNothing);
    // The bento drawing adds no node of its own.
    expect(
      find.descendant(
        of: _inHero(find.byType(ZokyBentoIllustration)),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('bento|เบนโตะ')), findsNothing);
    semantics.dispose();
  });

  testWidgets('search field opens store search, which filters and leads '
      'into the existing store page', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyApp(tester);
    await tester.tap(_search());
    await tester.pumpAndSettle();
    expect(find.byType(StoreSearchScreen), findsOneWidget);
    // Lazy grid: scroll through it so every store card is built once.
    final seen = <String>{};
    for (var i = 0; i < 4; i++) {
      for (final e in find.byType(ZokyStoreCard).evaluate()) {
        seen.add((e.widget as ZokyStoreCard).store.id);
      }
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(seen, {for (final s in DemoStoreRepository.stores) s.id});
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ส้มตำ');
    await tester.pumpAndSettle();
    expect(find.byType(ZokyStoreCard), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ไม่มีร้านนี้แน่นอน');
    await tester.pumpAndSettle();
    expect(find.byType(ZokyStoreCard), findsNothing);
    expect(find.text(ZokyStrings.searchNoResultsTitle), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'ส้มตำ');
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ZokyStoreCard));
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen), findsOneWidget);

    // Back twice returns to หน้าหลัก with the hero.
    await tester.tap(find.byTooltip(ZokyStrings.back));
    await tester.pumpAndSettle();
    expect(find.byType(StoreSearchScreen), findsOneWidget);
    await tester.tap(find.byTooltip(ZokyStrings.back));
    await tester.pumpAndSettle();
    expect(find.byType(StoreSearchScreen), findsNothing);
    expect(_hero(), findsOneWidget);
    semantics.dispose();
  });

  test('text colors meet WCAG contrast on their backgrounds', () {
    const white = Color(0xFFFFFFFF);
    // White text only sits on the brand gradient as WCAG large text: the
    // lightest stop still gives >= 3:1.
    for (final stop in ZokyGloss.brand.colors) {
      expect(_contrast(white, stop), greaterThanOrEqualTo(3.5));
    }
    // Subtitle qualifies as large text: bold and >= 18.66px (14pt).
    final subtitle = ZokyFoodHeroCard.subtitleStyle;
    expect(subtitle.fontSize, greaterThanOrEqualTo(18.66));
    expect(subtitle.fontWeight!.value, greaterThanOrEqualTo(700));
    // Small text (pill) is brandDeep on the white glossy control:
    // >= 4.5:1 even on its pinkest bottom stop.
    for (final bg in ZokyGloss.white.colors) {
      expect(_contrast(ZokyColors.brandDeep, bg), greaterThanOrEqualTo(4.5));
    }
  });

  testWidgets('gloss band ends above the white title', (tester) async {
    await pumpZokyApp(tester);
    final card = tester.getRect(_hero());
    final title = tester.getRect(
      _inHero(find.text(ZokyStrings.heroTitleLines)),
    );
    expect(
      title.top - card.top,
      greaterThanOrEqualTo(ZokyFoodHeroCard.glossHeight),
    );
  });

  for (final width in [320.0, 375.0, 390.0, 430.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('hero fits at width $width, text scale $scale', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpZokyApp(tester, width: width, textScale: scale);
        expect(tester.takeException(), isNull);
        final card = tester.getRect(_hero());
        expect(card.left, 16);
        expect(card.width, ZokyHomeBannerCarousel.slideWidth(width));

        final art = tester.getRect(_inHero(find.byType(ZokyBentoIllustration)));
        expect(
          card.contains(art.topLeft) && card.contains(art.bottomRight),
          isTrue,
        );
        final title = tester.getRect(
          _inHero(find.text(ZokyStrings.heroTitleLines)),
        );
        expect(title.right, lessThan(art.left));
        expect(title.top, greaterThanOrEqualTo(card.top));
        final subtitle = tester.getRect(_inHero(find.byType(Wrap)));
        expect(subtitle.right, lessThan(art.left));
        expect(subtitle.bottom, lessThanOrEqualTo(card.bottom));

        // Bottom nav is untouched by the hero.
        expect(find.byType(ZokyBottomNav), findsOneWidget);
        semantics.dispose();
      });
    }
  }
}
