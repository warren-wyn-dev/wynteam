import 'package:flutter/material.dart';

import '../../app/app_dependencies.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_chip.dart';
import '../../core/widgets/zoky_skeleton.dart';
import '../../core/widgets/zoky_state_view.dart';
import '../../core/widgets/zoky_store_card.dart';
import '../../core/widgets/zoky_store_grid.dart';
import '../address/address_sheet.dart';
import '../catalog/data/store_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../deals/data/promotion_repository.dart';
import '../deals/deal_sheet.dart';
import '../deals/deals_screen.dart';
import '../deals/domain/deal_models.dart';
import '../home/domain/home_content_models.dart';
import '../home/widgets/zoky_overscroll_backdrop.dart';
import '../home/widgets/zoky_today_deals_section.dart';
import '../search/store_search_screen.dart';
import '../store/store_screen.dart';
import 'widgets/zoky_food_address_button.dart';
import 'widgets/zoky_food_banner_carousel.dart';
import 'widgets/zoky_food_category_row.dart';
import 'widgets/zoky_food_header.dart';
import 'widgets/zoky_food_search_field.dart';

/// Client-side store filters (parity C04, same rules as the web).
enum StoreFilter { all, freeDelivery, promo, near, rating }

/// Food landing page (Founder, 2026-10-18), pushed from the Home hero card.
/// Top to bottom: the pink glossy header (back, "จัดส่งที่" address, heart,
/// orders), the "สั่งอะไรดี?" search field over the pink/white seam, the
/// banner carousel, the food category circles, "ดีลเด็ดวันนี้" and every
/// store ("ร้านอาหารทั้งหมด") with the C04 quick filters.
///
/// A full-screen pushed page like the store and search pages: the shell's
/// bottom nav stays under it and the back button / iOS edge swipe returns
/// to Home.
class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({
    super.key,
    required this.repository,
    required this.promotionRepository,
    required this.onOpenFavorites,
    this.onOpenOrders,
  });

  final StoreRepository repository;
  final PromotionRepository promotionRepository;

  /// Header heart: the "ร้านโปรด" sheet (same as Home's).
  final VoidCallback onOpenFavorites;

  /// Header orders shortcut; hidden when null.
  final VoidCallback? onOpenOrders;

  /// Store list heading key (tests).
  static const Key allStoresKey = ValueKey('zoky-food-all-stores');

  /// Quick filter row key (tests).
  static const Key filtersKey = ValueKey('zoky-food-filters');

  /// [stores] narrowed by [filter], open stores first, then by distance
  /// (parity C04/C08).
  static List<ZokyStoreSummary> applyFilter(
    List<ZokyStoreSummary> stores,
    StoreFilter filter,
  ) {
    final filtered = switch (filter) {
      StoreFilter.all => stores,
      StoreFilter.freeDelivery => stores.where((s) => s.deliveryFee <= 0),
      StoreFilter.promo => stores.where((s) => s.hasPromo),
      StoreFilter.near => stores.where(
        (s) => s.distanceKm != null && s.distanceKm! <= 3,
      ),
      StoreFilter.rating => stores.where((s) => (s.rating ?? 0) >= 4.5),
    };
    return [...filtered]..sort((a, b) {
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      return (a.distanceKm ?? double.infinity).compareTo(
        b.distanceKm ?? double.infinity,
      );
    });
  }

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  List<ZokyStoreSummary>? _stores;
  Object? _error;
  StoreFilter _filter = StoreFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loads once (no-op afterwards), so the header shows the default
    // address as soon as possible.
    AppDependencies.of(context).deliveryAddresses.load();
  }

  Future<void> _load() async {
    setState(() {
      _stores = null;
      _error = null;
    });
    try {
      final stores = await widget.repository.fetchDirectory();
      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
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

  void _openDeal(ZokyDeal deal) => showZokyDealSheet(context, deal);

  void _openAllDeals() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DealsScreen(repository: widget.promotionRepository),
      ),
    );
  }

  /// Gap between the header row and the search field (on the pink).
  static const double _searchGapAbove = ZokySpacing.s6;

  /// Gap between the search field and the header's bottom edge: the field
  /// is centered on the seam where the white sheet starts.
  static const double _searchGapBelow = ZokySpacing.s2;

  /// Pink overscroll backdrop at rest; smaller than the header.
  static double _backdropHeight(BuildContext context) =>
      MediaQuery.paddingOf(context).top + ZokySpacing.s24;

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    final searchHeight = ZokyFoodSearchField.heightFor(context);
    return Scaffold(
      backgroundColor: ZokyColors.surface,
      body: Semantics(
        // No visible title (super-app food page style); screen readers
        // still announce the page.
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: ZokyStrings.foodHomeTitle,
        child: ZokyOverscrollBackdrop(
          height: _backdropHeight(context),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                // The search field sits inside the header's box (painted
                // last, over the pink/white seam), so it stays inside
                // this sliver's hit-test area.
                child: Stack(
                  // The field's soft shadow may fall past the header.
                  clipBehavior: Clip.none,
                  children: [
                    ZokyFoodHeader(
                      address: ZokyFoodAddressButton(
                        controller: deps.deliveryAddresses,
                        onPressed: _openAddresses,
                      ),
                      onFavorites: widget.onOpenFavorites,
                      onOrders: widget.onOpenOrders,
                      bottomSpace:
                          _searchGapAbove + searchHeight + _searchGapBelow,
                    ),
                    Positioned(
                      left: ZokySpacing.gutter,
                      right: ZokySpacing.gutter,
                      bottom: _searchGapBelow,
                      height: searchHeight,
                      child: ZokyFoodSearchField(onPressed: _openSearch),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: ZokyFoodBannerCarousel(
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
              SliverToBoxAdapter(
                child: ZokyTodayDealsSection(
                  repository: widget.promotionRepository,
                  onOpenDeal: _openDeal,
                  onSeeAll: _openAllDeals,
                ),
              ),
              SliverToBoxAdapter(child: _storesHeading()),
              SliverToBoxAdapter(child: _filters()),
              const SliverToBoxAdapter(child: SizedBox(height: ZokySpacing.s6)),
              ..._storeSlivers(),
              // Home indicator room (no bottom nav on this page).
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      ZokySpacing.s12 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storesHeading() {
    return Padding(
      key: FoodHomeScreen.allStoresKey,
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.gutter,
        0,
        ZokySpacing.gutter,
        ZokySpacing.s2,
      ),
      child: Semantics(
        header: true,
        child: Text(
          ZokyStrings.allStoresTitle,
          // Same heading style as the deals section.
          style: ZokyTextStyles.titleSm.copyWith(fontSize: 20),
        ),
      ),
    );
  }

  Widget _filters() {
    const labels = {
      StoreFilter.all: ZokyStrings.filterAll,
      StoreFilter.freeDelivery: ZokyStrings.filterFreeDelivery,
      StoreFilter.promo: ZokyStrings.filterPromo,
      StoreFilter.near: ZokyStrings.filterNear,
      StoreFilter.rating: ZokyStrings.filterRating,
    };
    return SingleChildScrollView(
      key: FoodHomeScreen.filtersKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.gutter),
      child: Row(
        children: [
          for (final (i, entry) in labels.entries.indexed) ...[
            if (i > 0) const SizedBox(width: ZokySpacing.s4),
            ZokyChip(
              label: entry.value,
              selected: _filter == entry.key,
              onSelected: () => setState(() => _filter = entry.key),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _storeSlivers() {
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: ZokyStateView.error(
            title: ZokyStrings.loadErrorTitle,
            messages: const [ZokyStrings.offlineBody],
            onAction: _load,
          ),
        ),
      ];
    }
    final stores = _stores;
    if (stores == null) {
      return [
        ZokyStoreGrid(children: List.filled(4, const ZokyStoreCardSkeleton())),
      ];
    }
    final shown = FoodHomeScreen.applyFilter(stores, _filter);
    if (shown.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: ZokyStateView.empty(
            icon: ZokyIcons.store,
            title: ZokyStrings.noStoresTitle,
            messages: [ZokyStrings.noStoresBody],
          ),
        ),
      ];
    }
    return [
      ZokyStoreGrid(
        children: [
          for (final store in shown)
            ZokyStoreCard(store: store, onTap: () => _openStore(store)),
        ],
      ),
    ];
  }
}
