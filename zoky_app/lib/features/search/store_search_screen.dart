import 'package:flutter/material.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_colors.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/design/zoky_typography.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_skeleton.dart';
import '../../core/widgets/zoky_state_view.dart';
import '../../core/widgets/zoky_store_card.dart';
import '../../core/widgets/zoky_store_grid.dart';
import '../catalog/data/store_repository.dart';
import '../catalog/domain/catalog_models.dart';
import '../home/domain/home_content_models.dart';
import '../store/store_screen.dart';

/// Minimal store search / browse page opened by the food page search field
/// ("ค้นหาร้านอาหารหรือเมนู"). Reuses the store directory query (names and
/// categories, same as the web `food_store_directory`), the store card grid
/// and [StoreScreen], so the existing ordering flow continues from here.
///
/// A food page category circle opens it with [category]: the directory rows are
/// then narrowed client-side to that category ([ZokyFoodCategory.matches]
/// on the store's menu categories), together with any typed query.
///
/// Placeholder until the full search experience (ZOKY-106) is specified.
class StoreSearchScreen extends StatefulWidget {
  const StoreSearchScreen({
    super.key,
    required this.repository,
    this.title = ZokyStrings.heroSearchButton,
    this.autofocus = true,
    this.category,
  });

  final StoreRepository repository;

  /// Page title: "ค้นหาของอร่อย" from the hero search, "ร้านอาหารทั้งหมด"
  /// from Home "ดูทั้งหมด" (browse first, so no keyboard).
  final String title;
  final bool autofocus;

  /// Category filter from a food page category circle (null = all stores).
  final ZokyFoodCategory? category;

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  List<ZokyStoreSummary>? _stores;
  Object? _error;
  String _query = '';

  /// Incremented per request so a slow, stale response never replaces the
  /// results of a newer query.
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _stores = null;
      _error = null;
    });
    try {
      final stores = await widget.repository.fetchDirectory(query: _query);
      if (!mounted || request != _request) return;
      final category = widget.category;
      setState(
        () => _stores = category == null
            ? stores
            : stores.where(category.matches).toList(),
      );
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error);
    }
  }

  void _search(String value) {
    if (value.trim() == _query.trim()) return;
    _query = value;
    _load();
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
        title: Text(widget.title),
      ),
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(child: _field()),
          ..._body(),
          SliverToBoxAdapter(
            child: SizedBox(
              height: ZokySpacing.s12 + MediaQuery.paddingOf(context).bottom,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZokySpacing.gutter,
        ZokySpacing.s4,
        ZokySpacing.gutter,
        ZokySpacing.s8,
      ),
      child: TextField(
        autofocus: widget.autofocus,
        textInputAction: TextInputAction.search,
        onChanged: _search,
        onSubmitted: _search,
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
      return [
        ZokyStoreGrid(children: List.filled(4, const ZokyStoreCardSkeleton())),
      ];
    }
    if (stores.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: ZokyStateView.empty(
            icon: ZokyIcons.search,
            title: ZokyStrings.searchNoResultsTitle,
            messages: [ZokyStrings.searchNoResultsBody],
          ),
        ),
      ];
    }
    return [
      ZokyStoreGrid(
        children: [
          for (final store in stores)
            ZokyStoreCard(store: store, onTap: () => _openStore(store)),
        ],
      ),
    ];
  }
}
