import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_bottom_nav.dart';
import '../../core/widgets/zoky_state_view.dart';
import '../catalog/data/store_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../deals/data/promotion_repository.dart';
import '../deals/deal_sheet.dart';
import '../deals/deals_screen.dart';
import '../deals/domain/deal_models.dart';
import '../food/food_home_screen.dart';
import '../search/store_search_screen.dart';
import '../store/store_screen.dart';
import 'widgets/zoky_food_hero_card.dart';
import 'widgets/zoky_home_header.dart';
import 'widgets/zoky_overscroll_backdrop.dart';
import 'widgets/zoky_recommended_stores_section.dart';
import 'widgets/zoky_today_deals_section.dart';

/// หน้าหลัก (Home v1, Founder-approved Phases 1-5): the pink glossy header
/// with the logo and heart, the "อยากกินอะไรวันนี้?" hero card, "ดีลเด็ด
/// วันนี้" and "ร้านอาหารแนะนำ". The bottom nav (shell) floats over it and
/// never covers the last row.
///
/// Tapping the hero card (or its "ค้นหาของอร่อย" button) opens the food
/// landing page [FoodHomeScreen] (Founder, 2026-10-18).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.promotionRepository,
  });

  final StoreRepository repository;
  final PromotionRepository promotionRepository;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

/// Public so the shell can call [scrollToTop] when the selected หน้าหลัก
/// tab is tapped again (iOS convention).
class HomeScreenState extends State<HomeScreen> {
  /// Any widget inside the scroll view, to reach its [Scrollable] without
  /// replacing the inherited (iOS status-bar tap) scroll controller.
  final GlobalKey _scrollAnchor = GlobalKey();

  /// Scrolls the home feed back to the top (instantly with reduced motion).
  void scrollToTop() {
    final anchor = _scrollAnchor.currentContext;
    if (anchor == null) return;
    final position = Scrollable.maybeOf(anchor)?.position;
    if (position == null || position.pixels == position.minScrollExtent) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(position.minScrollExtent);
    } else {
      position.animateTo(
        position.minScrollExtent,
        duration: const Duration(milliseconds: 360),
        curve: ZokyMotion.standard,
      );
    }
  }

  void _openStore(ZokyStoreSummary store) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StoreScreen(store: store, repository: widget.repository),
      ),
    );
  }

  /// Hero card / "ค้นหาของอร่อย": the food landing page.
  void _openFood() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodHomeScreen(
          repository: widget.repository,
          onOpenFavorites: _openFavorites,
        ),
      ),
    );
  }

  /// Web parity: the header heart opens the "ร้านโปรด" sheet. The app has
  /// no favorites storage yet, so for the Phase 1 review the sheet only
  /// says "เร็ว ๆ นี้" (it must not pretend to list saved stores).
  ///
  /// Adaptive sheet like the deal sheet (iOS/Android style, safe area,
  /// height up to the screen); the content scrolls when it does not fit,
  /// e.g. in landscape or at 200% text (ZOKY-122). Also used by the food
  /// page's heart.
  void _openFavorites() {
    showZokySheet<void>(
      context: context,
      builder: (_) => const SingleChildScrollView(
        child: ZokyStateView.empty(
          icon: ZokyIcons.favorite,
          title: ZokyStrings.favoriteStores,
          messages: [ZokyStrings.comingSoon],
        ),
      ),
    );
  }

  /// Phase 4 "ดูทั้งหมด": the existing store listing (directory), without
  /// popping the keyboard.
  void _openAllStores() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreSearchScreen(
          repository: widget.repository,
          title: ZokyStrings.allStoresTitle,
          autofocus: false,
        ),
      ),
    );
  }

  void _openDeal(ZokyDeal deal) => showZokyDealSheet(context, deal);

  void _openAllDeals() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DealsScreen(repository: widget.promotionRepository),
      ),
    );
  }

  /// How far the hero card rises into the header's white sheet, leaving a
  /// small white gap under the pink like the mockup.
  static const double _heroOverlap =
      ZokyHomeHeader.sheetRadius - ZokySpacing.s6;

  /// Height of the pink overscroll backdrop at scroll offset 0; always
  /// smaller than the header, which hides it at rest.
  static double _backdropHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + ZokySpacing.s24;

  @override
  Widget build(BuildContext context) {
    final bottomInset = ZokyBottomNav.reservedHeight(context);
    return ColoredBox(
      color: ZokyColors.surface,
      child: ZokyOverscrollBackdrop(
        height: _backdropHeight(context),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              // One box so the card's lifted top edge stays inside this
              // sliver's hit-test area (the card is painted last, so it
              // wins taps over the sheet it overlaps).
              child: Column(
                key: _scrollAnchor,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZokyHomeHeader(onFavorites: _openFavorites),
                  Transform.translate(
                    offset: const Offset(0, -_heroOverlap),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ZokySpacing.gutter,
                      ),
                      child: ZokyFoodHeroCard(onSearch: _openFood),
                    ),
                  ),
                ],
              ),
            ),
            // Phase 3. The hero's translate already leaves [_heroOverlap]
            // of layout space under the card and the 44pt "ดูทั้งหมด"
            // target pads the heading, so no extra gap is added here.
            SliverToBoxAdapter(
              child: ZokyTodayDealsSection(
                repository: widget.promotionRepository,
                onOpenDeal: _openDeal,
                onSeeAll: _openAllDeals,
              ),
            ),
            // Phase 4, directly under Phase 3's row (same rhythm).
            SliverToBoxAdapter(
              child: ZokyRecommendedStoresSection(
                repository: widget.repository,
                onOpenStore: _openStore,
                onSeeAll: _openAllStores,
              ),
            ),
            // Room for the bottom nav: scrolled to the end, the
            // last row sits fully above it (Founder rule: the nav never
            // covers content).
            SliverFillRemaining(
              hasScrollBody: false,
              child: ColoredBox(
                color: ZokyColors.surface,
                child: SizedBox(height: bottomInset),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
