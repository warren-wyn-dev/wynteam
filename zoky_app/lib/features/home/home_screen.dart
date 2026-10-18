import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_dependencies.dart';
import '../../core/adaptive/adaptive.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_bottom_nav.dart';
import '../../core/widgets/zoky_state_view.dart';
import '../address/address_sheet.dart';
import '../catalog/data/store_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../deals/data/promotion_repository.dart';
import '../deals/deal_sheet.dart';
import '../deals/deals_screen.dart';
import '../deals/domain/deal_models.dart';
import '../search/store_search_screen.dart';
import '../store/store_screen.dart';
import 'domain/home_content_models.dart';
import 'widgets/zoky_food_category_row.dart';
import 'widgets/zoky_home_address_button.dart';
import 'widgets/zoky_home_banner_carousel.dart';
import 'widgets/zoky_home_header.dart';
import 'widgets/zoky_home_search_field.dart';
import 'widgets/zoky_recommended_stores_section.dart';
import 'widgets/zoky_today_deals_section.dart';

/// หน้าหลัก, Home v2 (Founder decision 2026-10-18), top to bottom: the pink
/// glossy header with the "จัดส่งที่" address row, the search field over
/// the pink/white seam, the banner carousel (hero first), the food
/// category circles, "ดีลเด็ดวันนี้" and "ร้านอาหารแนะนำ". The bottom nav
/// (shell) floats over it and never covers the last row.
///
/// The shell passes the store and promotion repositories; Home content and
/// the delivery address come from [AppDependencies].
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loads once (no-op afterwards), so the header shows the default
    // address as soon as possible.
    AppDependencies.of(context).deliveryAddresses.load();
  }

  void _openStore(ZokyStoreSummary store) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StoreScreen(store: store, repository: widget.repository),
      ),
    );
  }

  /// Search field: store search with the keyboard up, which continues
  /// into [StoreScreen].
  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreSearchScreen(repository: widget.repository),
      ),
    );
  }

  /// Category circle: the store list narrowed to that category (browse
  /// first, so no keyboard).
  void _openCategory(ZokyFoodCategory category) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreSearchScreen(
          repository: widget.repository,
          title: category.label,
          autofocus: false,
          category: category,
        ),
      ),
    );
  }

  void _openAddresses() => showZokyAddressSheet(
    context,
    AppDependencies.of(context).deliveryAddresses,
  );

  /// Banner tap: its store (web: the banner's destination store, looked up
  /// in the directory) or, for demo banners, its deal. Nothing happens
  /// when the target is no longer listed.
  Future<void> _openBanner(ZokyHomeBanner banner) async {
    final storeId = banner.destinationStoreId;
    if (storeId != null) {
      final stores = await widget.repository.fetchDirectory();
      final store = stores.where((s) => s.id == storeId).firstOrNull;
      if (store != null && mounted) _openStore(store);
      return;
    }
    final dealId = banner.dealId;
    if (dealId != null) {
      final deals = await widget.promotionRepository.fetchTodayDeals();
      final deal = deals.where((d) => d.id == dealId).firstOrNull;
      if (deal != null && mounted) _openDeal(deal);
    }
  }

  /// Web parity: the header heart opens the "ร้านโปรด" sheet. The app has
  /// no favorites storage yet, so for the Phase 1 review the sheet only
  /// says "เร็ว ๆ นี้" (it must not pretend to list saved stores).
  ///
  /// Adaptive sheet like the deal sheet (iOS/Android style, safe area,
  /// height up to the screen); the content scrolls when it does not fit,
  /// e.g. in landscape or at 200% text (ZOKY-122).
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

  /// Gap between the address row and the search field (on the pink).
  static const double _searchGapAbove = ZokySpacing.s6;

  /// Gap between the search field and the header's bottom edge: the field
  /// is centered on the seam where the white sheet starts.
  static const double _searchGapBelow = ZokySpacing.s2;

  /// Height of the pink overscroll backdrop at scroll offset 0; always
  /// smaller than the header, which hides it at rest.
  static double _backdropHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + ZokySpacing.s24;

  /// Vertical offset of the home feed (negative while overscrolling).
  final ValueNotifier<double> _scrollPixels = ValueNotifier<double>(0);

  bool _onScroll(Notification notification) {
    final ScrollMetrics metrics;
    final int depth;
    if (notification is ScrollNotification) {
      metrics = notification.metrics;
      depth = notification.depth;
    } else if (notification is ScrollMetricsNotification) {
      // Offset changes from layout (rotation, restored offset) send no
      // ScrollNotification.
      metrics = notification.metrics;
      depth = notification.depth;
    } else {
      return false;
    }
    // Only the feed itself, not the horizontal deal/store rows inside it.
    if (depth == 0 && metrics.axis == Axis.vertical) {
      _scrollPixels.value = metrics.pixels;
    }
    return false;
  }

  @override
  void dispose() {
    _scrollPixels.dispose();
    super.dispose();
  }

  Widget _home() {
    final deps = AppDependencies.of(context);
    final bottomInset = ZokyBottomNav.reservedHeight(context);
    final searchHeight = ZokyHomeSearchField.heightFor(context);
    return ColoredBox(
      color: ZokyColors.surface,
      child: Stack(
        children: [
          // Pink behind the top edge so an iOS overscroll bounce reveals
          // the header color instead of a white gap (ZOKY-120). It shrinks
          // by the scroll offset, so it stays inside the area the header
          // still covers and is gone once the header scrolls away; the
          // content below the header never sits on pink. At rest (offset
          // 0) it is the original size, hidden under the header.
          ValueListenableBuilder<double>(
            valueListenable: _scrollPixels,
            builder: (context, pixels, _) => Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: math.max(0, _backdropHeight(context) - pixels),
              child: const ColoredBox(color: ZokyColors.headerTop),
            ),
          ),
          NotificationListener<Notification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  // The search field sits inside the header's box (painted
                  // last, over the pink/white seam), so it stays inside
                  // this sliver's hit-test area.
                  child: Stack(
                    key: _scrollAnchor,
                    // The field's soft shadow may fall past the header.
                    clipBehavior: Clip.none,
                    children: [
                      ZokyHomeHeader(
                        onFavorites: _openFavorites,
                        address: ZokyHomeAddressButton(
                          controller: deps.deliveryAddresses,
                          onPressed: _openAddresses,
                        ),
                        bottomSpace:
                            _searchGapAbove + searchHeight + _searchGapBelow,
                      ),
                      Positioned(
                        left: ZokySpacing.gutter,
                        right: ZokySpacing.gutter,
                        bottom: _searchGapBelow,
                        height: searchHeight,
                        child: ZokyHomeSearchField(onPressed: _openSearch),
                      ),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: ZokyHomeBannerCarousel(
                    repository: deps.homeContentRepository,
                    onOpenBanner: _openBanner,
                  ),
                ),
                SliverToBoxAdapter(
                  child: ZokyFoodCategoryRow(
                    repository: deps.homeContentRepository,
                    onOpenCategory: _openCategory,
                  ),
                ),
                // Phase 3; the 44pt "ดูทั้งหมด" target pads the heading.
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _home();
}
