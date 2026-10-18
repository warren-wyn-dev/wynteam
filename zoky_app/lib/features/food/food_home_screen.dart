import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OrdinalSortKey;

import '../../app/app_dependencies.dart';
import '../../core/adaptive/adaptive.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_chip.dart';
import '../../core/widgets/zoky_line_icon.dart';
import '../../core/widgets/zoky_skeleton.dart';
import '../../core/widgets/zoky_state_view.dart';
import '../address/address_sheet.dart';
import '../catalog/data/store_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../deals/domain/deal_models.dart';
import '../fulfillment/fulfillment_mode_controller.dart';
import '../home/domain/home_content_models.dart';
import '../search/store_search_screen.dart';
import '../store/store_screen.dart';
import 'widgets/zoky_food_address_button.dart';
import 'widgets/zoky_food_cart_button.dart';
import 'widgets/zoky_food_category_row.dart';
import 'widgets/zoky_food_coupon_section.dart';
import 'widgets/zoky_food_header.dart';
import 'widgets/zoky_food_mode_toggle.dart';
import 'widgets/zoky_food_search_field.dart';
import 'widgets/zoky_food_store_row.dart';

/// Client-side store filters (parity C04, same rules as the web).
enum StoreFilter { all, freeDelivery, promo, near, rating }

/// Food landing page (Founder mockup v2, 2026-10-18), pushed from the Home
/// hero card. Top to bottom:
/// 1. pinned full-bleed pink header (back, "จัดส่งที่ / บ้าน ▾", heart,
///    coupons; compact "จัดส่ง | รับเองที่ร้าน" chips -- pickup: Founder
///    decision "ค"; search field) that folds to just the search field on
///    scroll (Founder feedback 2026-10-18);
/// 2. category circles;
/// 3. "โค้ดลดเพิ่มสำหรับคุณ" coupons (only when promos exist);
/// 4. "ร้านอาหารทั้งหมด" + "ตัวกรอง", quick filter chips (pinned once
///    reached) and the store rows;
/// 5. floating cart button.
///
/// Pull to refresh reloads the directory and the categories. A full-screen
/// pushed page: the back button / iOS edge swipe returns to Home.
class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({
    super.key,
    required this.repository,
    required this.onOpenFavorites,
    this.cartItemCount = 0,
    this.cartTotal = 0,
  });

  final StoreRepository repository;

  /// Header heart: the "ร้านโปรด" sheet (same as Home's).
  final VoidCallback onOpenFavorites;

  /// Cart shown on the floating button. The app has no shared cart yet
  /// (each store page keeps a demo tally until ZOKY-107), so callers pass
  /// nothing and the button stays the empty circle.
  final int cartItemCount;
  final num cartTotal;

  /// Store list heading key (tests).
  static const Key allStoresKey = ValueKey('zoky-food-all-stores');

  /// Quick filter row key (tests).
  static const Key filtersKey = ValueKey('zoky-food-filters');

  /// "ตัวกรอง" button key (tests).
  static const Key filterButtonKey = ValueKey('zoky-food-filter-button');

  /// Floating cart button key (tests).
  static const Key cartKey = ValueKey('zoky-food-cart');

  /// Filters offered in [mode]: free delivery means nothing for pickup.
  static List<StoreFilter> filtersFor(FulfillmentMode mode) => [
    for (final filter in StoreFilter.values)
      if (!(mode == FulfillmentMode.pickup &&
          filter == StoreFilter.freeDelivery))
        filter,
  ];

  /// Chip/sheet label of [filter].
  static String labelFor(StoreFilter filter) => switch (filter) {
    StoreFilter.all => ZokyStrings.filterAll,
    StoreFilter.freeDelivery => ZokyStrings.filterFreeDelivery,
    StoreFilter.promo => ZokyStrings.filterPromo,
    StoreFilter.near => ZokyStrings.filterNear,
    StoreFilter.rating => ZokyStrings.filterRating,
  };

  /// [stores] narrowed by [filter] (and, for pickup, to pickup stores),
  /// open stores first, then by distance (parity C04/C08).
  static List<ZokyStoreSummary> applyFilter(
    List<ZokyStoreSummary> stores,
    StoreFilter filter, {
    FulfillmentMode mode = FulfillmentMode.delivery,
  }) {
    final available = mode == FulfillmentMode.pickup
        ? stores.where((s) => s.supportsPickup)
        : stores;
    final filtered = switch (filter) {
      StoreFilter.all => available,
      StoreFilter.freeDelivery => available.where((s) => s.deliveryFee <= 0),
      StoreFilter.promo => available.where(
        (s) =>
            s.hasPromo &&
            !(mode == FulfillmentMode.pickup && s.promoFreeDelivery),
      ),
      StoreFilter.near => available.where(
        (s) => s.distanceKm != null && s.distanceKm! <= 3,
      ),
      StoreFilter.rating => available.where((s) => (s.rating ?? 0) >= 4.5),
    };
    return [...filtered]..sort((a, b) {
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      return (a.distanceKm ?? double.infinity).compareTo(
        b.distanceKm ?? double.infinity,
      );
    });
  }

  /// Dish art for a store without a photo or art of its own: the first
  /// category circle that matches it, else the made-to-order plate.
  static ZokyDealArt fallbackArtFor(
    ZokyStoreSummary store,
    List<ZokyFoodCategory>? categories,
  ) =>
      categories?.where((c) => c.matches(store)).firstOrNull?.art ??
      ZokyDealArt.kaprao;

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  List<ZokyStoreSummary>? _stores;
  Object? _storesError;
  List<ZokyFoodCategory>? _categories;
  bool _categoriesFailed = false;
  StoreFilter _filter = StoreFilter.all;
  bool _started = false;
  late FulfillmentModeController _mode;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final deps = AppDependencies.of(context);
    // Loads once (no-op afterwards), so the header shows the default
    // address as soon as possible.
    deps.deliveryAddresses.load();
    if (!_started) {
      _started = true;
      _mode = deps.fulfillmentMode..addListener(_onModeChanged);
      // State starts empty (skeletons), so no setState is needed here.
      _loadAll();
    }
  }

  @override
  void dispose() {
    _mode.removeListener(_onModeChanged);
    super.dispose();
  }

  /// Rebuilds for the new mode; pickup has no free-delivery filter, so
  /// that one falls back to "ทั้งหมด".
  void _onModeChanged() {
    if (!mounted) return;
    setState(() {
      if (!FoodHomeScreen.filtersFor(_mode.mode).contains(_filter)) {
        _filter = StoreFilter.all;
      }
    });
  }

  /// Loads the directory and the categories. First load / retry show
  /// skeletons; pull to refresh keeps the current content until the new
  /// one arrives.
  Future<void> _loadAll({bool showSkeletons = false}) {
    return Future.wait([
      _loadStores(showSkeleton: showSkeletons),
      _loadCategories(showSkeleton: showSkeletons),
    ]);
  }

  Future<void> _loadStores({bool showSkeleton = true}) async {
    if (showSkeleton) {
      setState(() {
        _stores = null;
        _storesError = null;
      });
    }
    try {
      final stores = await widget.repository.fetchDirectory();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _storesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _stores = null;
        _storesError = error;
      });
    }
  }

  Future<void> _loadCategories({bool showSkeleton = true}) async {
    if (showSkeleton) {
      setState(() {
        _categories = null;
        _categoriesFailed = false;
      });
    }
    try {
      final repository = AppDependencies.of(context).homeContentRepository;
      final categories = await repository.fetchFoodCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoriesFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categories = null;
        _categoriesFailed = true;
      });
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

  /// Header coupon icon and "ดูทั้งหมด": the "รวมโค้ดลดเพิ่ม" sheet.
  void _openCoupons() => showZokyCouponsSheet(
    context,
    stores: couponStores(_stores ?? const [], _mode.mode),
    collected: AppDependencies.of(context).collectedPromos,
  );

  /// Floating cart button: same placeholder as the store page's cart bar
  /// until the cart page ships (ZOKY-107).
  void _openCart() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(ZokyStrings.demoCartPending)));
  }

  void _setFilter(StoreFilter filter) => setState(() => _filter = filter);

  void _openFilterSheet() {
    showZokySheet<void>(
      context: context,
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: ZokySpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                ZokySpacing.s12,
                ZokySpacing.s4,
                ZokySpacing.s12,
                ZokySpacing.s4,
              ),
              child: Semantics(
                header: true,
                child: Text(ZokyStrings.filters, style: ZokyTextStyles.titleSm),
              ),
            ),
            for (final filter in FoodHomeScreen.filtersFor(_mode.mode))
              _FilterOption(
                label: FoodHomeScreen.labelFor(filter),
                selected: filter == _filter,
                onTap: () {
                  _setFilter(filter);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;
    const fabMargin = ZokySpacing.s8;
    return Scaffold(
      backgroundColor: ZokyColors.surface,
      body: Semantics(
        // No visible title (super-app food page style); screen readers
        // still announce the page.
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: ZokyStrings.foodHomeTitle,
        child: Stack(
          children: [
            RefreshIndicator.adaptive(
              onRefresh: _loadAll,
              edgeOffset: ZokyFoodHeader.minExtentFor(context),
              color: ZokyColors.brandDeep,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Screen readers follow the visual order: header, body,
                  // chips, rows. Each part is one ordered node; without
                  // this the pinned header and chips were read after the
                  // scrolling content (ZOKY-130).
                  for (final (i, sliver) in [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _HeaderDelegate(
                        maxHeight: ZokyFoodHeader.maxExtentFor(context),
                        minHeight: ZokyFoodHeader.minExtentFor(context),
                        builder: (collapse) => ZokyFoodHeader(
                          collapse: collapse,
                          title: ZokyFoodAddressButton(
                            controller: deps.deliveryAddresses,
                            mode: deps.fulfillmentMode,
                            onPressed: _openAddresses,
                          ),
                          modeChips: ZokyFoodModeToggle(
                            controller: deps.fulfillmentMode,
                          ),
                          search: ZokyFoodSearchField(onPressed: _openSearch),
                          onFavorites: widget.onOpenFavorites,
                          onCoupons: _openCoupons,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ZokyFoodCategoryRow(
                        categories: _categories,
                        failed: _categoriesFailed,
                        onRetry: _loadCategories,
                        onOpenCategory: _openCategory,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ZokyFoodCouponSection(
                        stores: _stores,
                        failed: _storesError != null,
                        mode: _mode.mode,
                        collected: deps.collectedPromos,
                        onSeeAll: _openCoupons,
                      ),
                    ),
                    SliverToBoxAdapter(child: _storesHeading()),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ChipsDelegate(
                        height: _chipsHeight(context),
                        child: _filters(),
                      ),
                    ),
                    ..._storeSlivers(),
                  ].indexed)
                    SliverSemantics(
                      container: true,
                      explicitChildNodes: true,
                      sortKey: OrdinalSortKey(i.toDouble()),
                      sliver: sliver,
                    ),
                  // Room for the floating cart button above the home
                  // indicator, so it never covers the last row.
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          ZokyFoodCartButton.height +
                          2 * fabMargin +
                          bottomInset,
                    ),
                  ),
                ],
              ),
            ),
            PositionedDirectional(
              end: ZokySpacing.gutter,
              bottom: bottomInset + fabMargin,
              child: ZokyFoodCartButton(
                key: FoodHomeScreen.cartKey,
                itemCount: widget.cartItemCount,
                total: widget.cartTotal,
                onPressed: _openCart,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storesHeading() {
    return Padding(
      key: FoodHomeScreen.allStoresKey,
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.gutter,
        ZokySpacing.s6,
        ZokySpacing.s4,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                ZokyStrings.allStoresTitle,
                style: ZokyTextStyles.titleSm.copyWith(fontSize: 20),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: ZokyStrings.filters,
            excludeSemantics: true,
            child: InkWell(
              key: FoodHomeScreen.filterButtonKey,
              onTap: _openFilterSheet,
              borderRadius: ZokyRadius.full,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: ZokySizes.tapTargetIos,
                  minWidth: ZokySizes.tapTargetIos,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ZokySpacing.s4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ZokyLineIcon(
                        ZokyLineGlyph.sliders,
                        size: 22,
                        color: ZokyColors.brandDeep,
                      ),
                      const SizedBox(width: ZokySpacing.s2),
                      Text(
                        ZokyStrings.filters,
                        style: ZokyTextStyles.labelLg.copyWith(
                          color: ZokyColors.brandDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chip row height: 48pt chips (taller with large text) plus padding.
  static double _chipsHeight(BuildContext context) {
    final text = MediaQuery.textScalerOf(context).scale(14) * 1.3;
    final chip = text + 2 * ZokySpacing.s3 + 2 * ZokySpacing.s2;
    return (chip > ZokySizes.tapTargetAndroid
            ? chip
            : ZokySizes.tapTargetAndroid) +
        ZokySpacing.s4;
  }

  /// Quick chips (mockup order). "เรตติ้ง 4.5+" lives in the filter
  /// sheet and shows here only while it is the active filter.
  Widget _filters() {
    final chips = [
      StoreFilter.all,
      StoreFilter.near,
      if (!_mode.isPickup) StoreFilter.freeDelivery,
      StoreFilter.promo,
      if (_filter == StoreFilter.rating) StoreFilter.rating,
    ];
    return SingleChildScrollView(
      key: FoodHomeScreen.filtersKey,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.gutter),
      child: Row(
        children: [
          for (final (i, filter) in chips.indexed) ...[
            if (i > 0) const SizedBox(width: ZokySpacing.s4),
            ZokyChip(
              label: FoodHomeScreen.labelFor(filter),
              selected: _filter == filter,
              unselectedStyle: ZokyChipUnselectedStyle.filled,
              onSelected: () => _setFilter(filter),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _storeSlivers() {
    if (_storesError != null) {
      return [
        SliverToBoxAdapter(
          child: ZokyStateView.error(
            glyph: ZokyLineGlyph.wifiOff,
            title: ZokyStrings.offlineTitle,
            messages: const [ZokyStrings.offlineBody],
            onAction: _loadAll,
          ),
        ),
      ];
    }
    final stores = _stores;
    if (stores == null) {
      return [
        SliverList.list(children: List.filled(3, const _StoreRowSkeleton())),
      ];
    }
    final shown = FoodHomeScreen.applyFilter(stores, _filter, mode: _mode.mode);
    if (shown.isEmpty) {
      final filtered = _filter != StoreFilter.all;
      return [
        SliverToBoxAdapter(
          child: filtered
              ? ZokyStateView.empty(
                  glyph: ZokyLineGlyph.store,
                  title: ZokyStrings.noFilteredStores,
                  actionLabel: ZokyStrings.clearFilters,
                  onAction: () => _setFilter(StoreFilter.all),
                )
              : const ZokyStateView.empty(
                  glyph: ZokyLineGlyph.store,
                  title: ZokyStrings.noStoresTitle,
                  messages: [ZokyStrings.noStoresBody],
                ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: shown.length,
        itemBuilder: (context, i) {
          final store = shown[i];
          return ZokyFoodStoreRow(
            store: store,
            mode: _mode.mode,
            fallbackArt: FoodHomeScreen.fallbackArtFor(store, _categories),
            onTap: () => _openStore(store),
          );
        },
      ),
    ];
  }
}

/// Pinned header that folds from [maxHeight] to [minHeight].
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({
    required this.maxHeight,
    required this.minHeight,
    required this.builder,
  });

  final double maxHeight;
  final double minHeight;
  final Widget Function(double collapse) builder;

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final range = maxHeight - minHeight;
    final collapse = range <= 0 ? 1.0 : (shrinkOffset / range).clamp(0.0, 1.0);
    return SizedBox.expand(child: builder(collapse));
  }

  @override
  bool shouldRebuild(_HeaderDelegate oldDelegate) => true;
}

/// Pinned quick filter row on white, with a hairline once content scrolls
/// under it.
class _ChipsDelegate extends SliverPersistentHeaderDelegate {
  _ChipsDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get maxExtent => height;

  @override
  double get minExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ZokyColors.surface,
        border: Border(
          bottom: BorderSide(
            color: overlapsContent
                ? ZokyColors.borderSubtle
                : ZokyColors.surface,
          ),
        ),
      ),
      child: Align(alignment: Alignment.centerLeft, child: child),
    );
  }

  @override
  bool shouldRebuild(_ChipsDelegate oldDelegate) => true;
}

/// One filter in the "ตัวกรอง" sheet: label and a check when selected.
class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ZokySizes.tapTargetAndroid,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZokySpacing.s12,
              vertical: ZokySpacing.s4,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: ZokyTextStyles.bodyLg.copyWith(
                      color: selected
                          ? ZokyColors.brandDeep
                          : ZokyColors.textPrimary,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (selected)
                  const ZokyLineIcon(
                    ZokyLineGlyph.check,
                    color: ZokyColors.brandDeep,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder shaped like [ZokyFoodStoreRow].
class _StoreRowSkeleton extends StatelessWidget {
  const _StoreRowSkeleton();

  @override
  Widget build(BuildContext context) {
    final photo = ZokyFoodStoreRow.photoSize(MediaQuery.sizeOf(context).width);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZokySpacing.gutter,
        vertical: ZokySpacing.s4,
      ),
      child: Row(
        children: [
          ZokySkeleton(
            width: photo,
            height: photo,
            borderRadius: ZokyRadius.lg,
          ),
          const SizedBox(width: ZokySpacing.s7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ZokySkeleton(height: 18),
                const SizedBox(height: ZokySpacing.s4),
                FractionallySizedBox(
                  widthFactor: 0.7,
                  child: const ZokySkeleton(height: 14),
                ),
                const SizedBox(height: ZokySpacing.s4),
                FractionallySizedBox(
                  widthFactor: 0.35,
                  child: const ZokySkeleton(height: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
