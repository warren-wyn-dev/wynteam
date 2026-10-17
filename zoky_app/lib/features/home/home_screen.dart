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
import '../catalog/data/store_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../store/store_screen.dart';

/// Client-side store filters (parity C04, same rules as the web).
enum StoreFilter { all, freeDelivery, promo, near, rating }

/// หน้าหลัก placeholder: header, search, filter chips and the store grid.
/// Banners, featured stores, deals, re-order and popular sections arrive in
/// ZOKY-106 (parity C01-C16).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final StoreRepository repository;

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
    _load();
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

  @override
  Widget build(BuildContext context) {
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

  /// 2 columns, 3 at >=680px, 1 at text scale >=1.5 (design 6.4 / 10.2).
  Widget _grid(List<Widget> children) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = scale >= 1.5 ? 1 : (width >= 680 ? 3 : 2);
    final gap = width <= 359 ? ZokySpacing.s4 : ZokySpacing.s6;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: ZokySpacing.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < columns; c++) ...[
                if (c > 0) SizedBox(width: gap),
                Expanded(
                  child: i + c < children.length
                      ? children[i + c]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.gutter),
      sliver: SliverList.list(children: rows),
    );
  }

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
