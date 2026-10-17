import 'package:flutter/material.dart';

import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_bottom_nav.dart';
import '../../core/widgets/zoky_chip.dart';
import '../../core/widgets/zoky_logo.dart';
import '../../core/widgets/zoky_skeleton.dart';
import '../../core/widgets/zoky_state_view.dart';
import '../../core/widgets/zoky_store_card.dart';
import '../../core/widgets/zoky_store_grid.dart';
import '../catalog/data/store_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../deals/data/promotion_repository.dart';
import '../deals/deal_sheet.dart';
import '../deals/deals_screen.dart';
import '../deals/domain/deal_models.dart';
import '../search/store_search_screen.dart';
import '../store/store_screen.dart';
import 'widgets/zoky_food_hero_card.dart';
import 'widgets/zoky_home_header.dart';
import 'widgets/zoky_recommended_stores_section.dart';
import 'widgets/zoky_today_deals_section.dart';

/// Client-side store filters (parity C04, same rules as the web).
enum StoreFilter { all, freeDelivery, promo, near, rating }

/// Home redesign review switch (Founder mockup, built phase by phase).
///
/// While false, หน้าหลัก shows the new [ZokyHomeHeader] (Phase 1), the
/// [ZokyFoodHeroCard] (Phase 2), [ZokyTodayDealsSection] (Phase 3) and
/// [ZokyRecommendedStoresSection] (Phase 4) so the Founder can review each
/// phase; the earlier demo body (search, filter chips, store grid) is kept
/// intact behind this flag and comes back when it is true.
const bool kShowLegacyHomeBody = false;

/// หน้าหลัก placeholder: header, search, filter chips and the store grid.
/// Banners, featured stores, deals, re-order and popular sections arrive in
/// ZOKY-106 (parity C01-C16).
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.promotionRepository,
    this.showLegacyBody = kShowLegacyHomeBody,
  });

  final StoreRepository repository;
  final PromotionRepository promotionRepository;

  /// See [kShowLegacyHomeBody]; tests pass true to cover the old body.
  final bool showLegacyBody;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ZokyStoreSummary>? _stores;
  Object? _error;
  StoreFilter _filter = StoreFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // The phased review canvas shows no stores, so it fetches nothing.
    if (widget.showLegacyBody) _load();
  }

  Future<void> _load() async {
    setState(() {
      _stores = null;
      _error = null;
    });
    try {
      final stores = await widget.repository.fetchDirectory(query: _query);
      if (!mounted) return;
      setState(() => _stores = stores);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  List<ZokyStoreSummary> _filtered(List<ZokyStoreSummary> stores) {
    final filtered = switch (_filter) {
      StoreFilter.all => stores,
      StoreFilter.freeDelivery =>
        stores.where((s) => s.deliveryFee <= 0).toList(),
      StoreFilter.promo => stores.where((s) => s.hasPromo).toList(),
      StoreFilter.near =>
        stores
            .where((s) => s.distanceKm != null && s.distanceKm! <= 3)
            .toList(),
      StoreFilter.rating =>
        stores.where((s) => s.ratingAverage >= 4.5).toList(),
    };
    // Open stores first, then by distance (parity C08).
    final sorted = [...filtered]
      ..sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        return (a.distanceKm ?? double.infinity).compareTo(
          b.distanceKm ?? double.infinity,
        );
      });
    return sorted;
  }

  void _openStore(ZokyStoreSummary store) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            StoreScreen(store: store, repository: widget.repository),
      ),
    );
  }

  /// Hero button: store search/browse, which continues into [StoreScreen].
  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoreSearchScreen(repository: widget.repository),
      ),
    );
  }

  /// Web parity: the header heart opens the "ร้านโปรด" sheet. The app has
  /// no favorites storage yet, so for the Phase 1 review the sheet only
  /// says "เร็ว ๆ นี้" (it must not pretend to list saved stores).
  void _openFavorites() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => const SafeArea(
        top: false,
        child: ZokyStateView.empty(
          icon: ZokyIcons.favorite,
          title: ZokyStrings.favoriteStores,
          messages: [ZokyStrings.comingSoon],
        ),
      ),
    );
  }

  /// Phase 4 card heart. There is no favorites storage yet, so instead of
  /// pretending to save it opens the same "ร้านโปรด · เร็ว ๆ นี้" sheet as
  /// the header heart (Phase 1).
  void _favoriteStore(ZokyStoreSummary store) => _openFavorites();

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

  /// Phased review layout: header, hero card, then a plain white canvas.
  Widget _phase1() {
    final bottomInset = ZokyBottomNav.reservedHeight(context);
    return ColoredBox(
      color: ZokyColors.surface,
      child: Stack(
        children: [
          // Pink behind the top edge so an iOS overscroll bounce reveals
          // the header color instead of a white gap. Always covered by the
          // header otherwise.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top + ZokySpacing.s24,
            child: const ColoredBox(color: ZokyColors.headerTop),
          ),
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                // One box so the card's lifted top edge stays inside this
                // sliver's hit-test area (the card is painted last, so it
                // wins taps over the sheet it overlaps).
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ZokyHomeHeader(onFavorites: _openFavorites),
                    Transform.translate(
                      offset: const Offset(0, -_heroOverlap),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: ZokySpacing.gutter,
                        ),
                        child: ZokyFoodHeroCard(onSearch: _openSearch),
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
                  onFavorite: _favoriteStore,
                  onSeeAll: _openAllStores,
                ),
              ),
              // Room for the floating bottom nav: scrolled to the end, the
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showLegacyBody) return _phase1();
    final bottomInset = ZokyBottomNav.reservedHeight(context);
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _header()),
          SliverToBoxAdapter(child: _search()),
          SliverToBoxAdapter(child: _filters()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              ZokySpacing.gutter,
              ZokySpacing.s6,
              ZokySpacing.gutter,
              ZokySpacing.s4,
            ),
            sliver: SliverToBoxAdapter(
              child: Semantics(
                header: true,
                child: Text(
                  ZokyStrings.nearbyStores,
                  style: ZokyTextStyles.titleSm,
                ),
              ),
            ),
          ),
          ..._body(),
          SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
        ],
      ),
    );
  }

  List<Widget> _body() {
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
      return [_grid(List.filled(4, const ZokyStoreCardSkeleton()))];
    }
    final shown = _filtered(stores);
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
      _grid([
        for (final store in shown)
          ZokyStoreCard(store: store, onTap: () => _openStore(store)),
      ]),
    ];
  }

  Widget _grid(List<Widget> children) => ZokyStoreGrid(children: children);

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.gutter,
        ZokySpacing.s4,
        ZokySpacing.gutter,
        ZokySpacing.s4,
      ),
      child: Row(
        children: [
          const ZokyLogo(size: 36),
          const SizedBox(width: ZokySpacing.s6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ZokyStrings.deliverTo, style: ZokyTextStyles.bodySm),
                Row(
                  children: [
                    const Icon(
                      ZokyIcons.location,
                      size: 16,
                      color: ZokyColors.brand,
                    ),
                    const SizedBox(width: ZokySpacing.s1),
                    Flexible(
                      child: Text(
                        ZokyStrings.demoAddressLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZokyTextStyles.weight(
                          ZokyTextStyles.bodyMd,
                          FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _search() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZokySpacing.gutter,
        vertical: ZokySpacing.s2,
      ),
      child: TextField(
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          _query = value;
          _load();
        },
        style: ZokyTextStyles.bodyLg,
        decoration: const InputDecoration(
          hintText: ZokyStrings.searchHint,
          prefixIcon: Icon(ZokyIcons.search, color: ZokyColors.neutral600),
          filled: true,
          fillColor: ZokyColors.chip,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: ZokyRadius.full,
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: ZokyRadius.full,
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: ZokyRadius.full,
            borderSide: BorderSide(color: ZokyColors.brand, width: 2),
          ),
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
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.gutter),
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            ZokyChip(
              label: entry.value,
              selected: _filter == entry.key,
              onSelected: () => setState(() => _filter = entry.key),
            ),
            const SizedBox(width: ZokySpacing.s4),
          ],
        ],
      ),
    );
  }
}
