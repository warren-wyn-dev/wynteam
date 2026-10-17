import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/format/money.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_cart_bar.dart';
import '../../core/widgets/zoky_menu_item_card.dart';
import '../../core/widgets/zoky_skeleton.dart';
import '../../core/widgets/zoky_state_view.dart';
import '../catalog/data/store_repository.dart';
import '../catalog/domain/catalog_models.dart';

/// Store page placeholder: store info + menu rows + floating cart bar.
///
/// The cart here is a throwaway local tally for the demo; the real
/// single-store cart, item sheet with options, server quote and checkout
/// arrive in ZOKY-106/107 (parity D01-D13, E01-E09).
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, required this.store, required this.repository});

  final ZokyStoreSummary store;
  final StoreRepository repository;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<ZokyMenuItem>? _menu;
  Object? _error;
  final Map<String, int> _quantities = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _menu = null;
      _error = null;
    });
    try {
      final menu = await widget.repository.fetchMenu(widget.store.id);
      if (!mounted) return;
      setState(() => _menu = menu);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  int get _count => _quantities.values.fold(0, (a, b) => a + b);

  num get _subtotal {
    final menu = _menu ?? const [];
    num total = 0;
    for (final item in menu) {
      total += item.price * (_quantities[item.id] ?? 0);
    }
    return total;
  }

  void _add(ZokyMenuItem item) {
    setState(() => _quantities[item.id] = (_quantities[item.id] ?? 0) + 1);
  }

  void _openCart() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(ZokyStrings.demoCartPending)));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(ZokyIcons.back(context)),
          tooltip: ZokyStrings.back,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        // Pushed-page title: centered on iOS, start-aligned on Android
        // (design 11.2).
        centerTitle: isCupertino(context),
        title: Text(store.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _info(store)),
              const SliverToBoxAdapter(child: Divider()),
              ..._menuSlivers(),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: _count > 0
                      ? ZokySizes.cartBar +
                            32 +
                            MediaQuery.paddingOf(context).bottom
                      : 24,
                ),
              ),
            ],
          ),
          if (_count > 0)
            Positioned(
              left: ZokySpacing.gutter,
              right: ZokySpacing.gutter,
              bottom: ZokySpacing.s8 + MediaQuery.paddingOf(context).bottom,
              child: ZokyCartBar(
                itemCount: _count,
                total: _subtotal,
                onTap: _openCart,
              ),
            ),
        ],
      ),
    );
  }

  Widget _info(ZokyStoreSummary store) {
    return Padding(
      padding: const EdgeInsets.all(ZokySpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(store.name, style: ZokyTextStyles.titleMd),
          const SizedBox(height: ZokySpacing.s3),
          Wrap(
            spacing: ZokySpacing.s6,
            runSpacing: ZokySpacing.s2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (!store.isOpen)
                Text(
                  ZokyStrings.closedLabel,
                  style: ZokyTextStyles.labelSm.copyWith(
                    color: ZokyColors.textSecondary,
                  ),
                ),
              // Same rule as the Home card: a score only with real reviews
              // (ZOKY-121); "ร้านใหม่" copy unchanged.
              if (store.rating != null)
                Text(
                  '★ ${store.rating!.toStringAsFixed(1)}',
                  style: ZokyTextStyles.bodySm,
                )
              else if (store.isNew)
                Text(ZokyStrings.newStore, style: ZokyTextStyles.bodySm),
              if (store.hasEta)
                Text(
                  '${store.etaMinMinutes}–${store.etaMaxMinutes} ${ZokyStrings.minutes}',
                  style: ZokyTextStyles.bodySm,
                ),
              Text(
                '${ZokyStrings.deliveryFee} ${formatBaht(store.deliveryFee)}',
                style: ZokyTextStyles.bodySm,
              ),
              if (store.minimumOrder > 0)
                Text(
                  'สั่งขั้นต่ำ ${formatBaht(store.minimumOrder)}',
                  style: ZokyTextStyles.bodySm,
                ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _menuSlivers() {
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: ZokyStateView.error(
            title: ZokyStrings.loadErrorTitle,
            onAction: _load,
          ),
        ),
      ];
    }
    final menu = _menu;
    if (menu == null) {
      return [
        SliverList.list(
          children: List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.all(ZokySpacing.gutter),
              child: ZokySkeleton(height: 84, borderRadius: ZokyRadius.md),
            ),
          ),
        ),
      ];
    }
    // Sold-out items go last (parity D09).
    final ordered = [
      ...menu.where((item) => !item.isSoldOut),
      ...menu.where((item) => item.isSoldOut),
    ];
    return [
      SliverList.separated(
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const Divider(
          indent: ZokySpacing.gutter,
          endIndent: ZokySpacing.gutter,
        ),
        itemBuilder: (context, index) {
          final item = ordered[index];
          return ZokyMenuItemCard(
            item: item,
            onTap: () {},
            onAdd: widget.store.isOpen ? () => _add(item) : null,
          );
        },
      ),
    ];
  }
}
