import 'package:flutter/material.dart';

import '../data/category.dart';
import '../data/product.dart';
import '../data/store.dart';
import '../data/zoky_repository.dart';
import 'product_detail_screen.dart';
import 'store_screen.dart';
import 'widgets/product_grid_tile.dart';
import 'widgets/product_mini_card.dart';
import 'widgets/store_mini_card.dart';
import 'zoky_cart_screen.dart';
import 'zoky_order_list_screen.dart';
import 'zoky_search_screen.dart';

/// Screen 1 — ZOKY Home (ZOKY-001), the 5th Bottom Nav tab. Search and
/// category-tap open ZokySearchScreen for real as of ZOKY-002; Cart/
/// Orders open ZokyCartScreen/ZokyOrderListScreen for real as of
/// ZOKY-003. See .wyn/docs/design/zoky-001-marketplace-foundation.md,
/// Screen 1.
class ZokyHomeScreen extends StatefulWidget {
  const ZokyHomeScreen({super.key, required this.zokyRepository});

  final ZokyRepository zokyRepository;

  @override
  State<ZokyHomeScreen> createState() => _ZokyHomeScreenState();
}

class _ZokyHomeScreenState extends State<ZokyHomeScreen> {
  final _scrollController = ScrollController();

  late Future<List<Category>> _categoriesFuture;
  late Future<List<Product>> _newProductsFuture;
  late Future<List<Store>> _recommendedStoresFuture;

  final List<Product> _gridProducts = [];
  int _gridPage = 0;
  bool _isLoadingGrid = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.zokyRepository.fetchCategories();
    _newProductsFuture = widget.zokyRepository.fetchNewProducts();
    _recommendedStoresFuture = widget.zokyRepository.fetchRecommendedStores();
    _loadGridInitial();
    _loadCartItemCount();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 300) {
      _loadGridMore();
    }
  }

  Future<void> _loadGridInitial() async {
    setState(() => _isLoadingGrid = true);
    final products = await widget.zokyRepository.fetchProducts(page: 0);
    if (!mounted) return;
    setState(() {
      _gridProducts
        ..clear()
        ..addAll(products);
      _gridPage = 0;
      _hasMore = products.length == ZokyRepository.gridPageSize;
      _isLoadingGrid = false;
    });
  }

  Future<void> _loadGridMore() async {
    setState(() => _isLoadingMore = true);
    final page = _gridPage + 1;
    final products = await widget.zokyRepository.fetchProducts(page: page);
    if (!mounted) return;
    setState(() {
      _gridProducts.addAll(products);
      _gridPage = page;
      _hasMore = products.length == ZokyRepository.gridPageSize;
      _isLoadingMore = false;
    });
  }

  Future<void> _loadCartItemCount() async {
    try {
      final count = await widget.zokyRepository.cartItemCount();
      if (!mounted) return;
      setState(() => _cartItemCount = count);
    } catch (_) {
      // Silent, same as _buildNotificationButton's badge fetch
      // (home_feed_screen.dart, WYN-012) -- a failed count leaves the
      // badge showing its last known value, not worth a blocking error
      // UI for a number in the corner of an icon.
    }
  }

  Future<void> _openCart() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZokyCartScreen(zokyRepository: widget.zokyRepository),
      ),
    );
    _loadCartItemCount();
  }

  void _openOrders() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZokyOrderListScreen(zokyRepository: widget.zokyRepository),
      ),
    );
  }

  void _openSearch({Category? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZokySearchScreen(
          zokyRepository: widget.zokyRepository,
          initialCategory: category,
        ),
      ),
    );
  }

  void _openProduct(Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          zokyRepository: widget.zokyRepository,
          product: product,
        ),
      ),
    );
  }

  void _openStore(Store store) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreScreen(zokyRepository: widget.zokyRepository, storeId: store.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildTopRow(context)),
            SliverToBoxAdapter(child: _buildCategoryChips(context)),
            SliverToBoxAdapter(child: _buildBanner(context)),
            SliverToBoxAdapter(
              child: _buildComingSoonSection(context, 'แนะนำสำหรับคุณ'),
            ),
            SliverToBoxAdapter(child: _buildComingSoonSection(context, 'ขายดี')),
            SliverToBoxAdapter(child: _buildNewProducts(context)),
            SliverToBoxAdapter(child: _buildRecommendedStores(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text('สินค้าทั้งหมด', style: Theme.of(context).textTheme.titleSmall),
              ),
            ),
            _buildGrid(context),
            if (_hasMore && !_isLoadingGrid)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(child: _buildSearchBar(context)),
          _buildCartButton(context),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            tooltip: 'คำสั่งซื้อของฉัน',
            onPressed: _openOrders,
          ),
        ],
      ),
    );
  }

  /// Mirrors home_feed_screen.dart's _buildNotificationButton (WYN-012)
  /// exactly -- same Stack+Positioned badge shape, showing the number
  /// of distinct cart lines (not summed quantity).
  Widget _buildCartButton(BuildContext context) {
    final count = _cartItemCount;
    final badgeText = count > 9 ? '9+' : '$count';

    return Semantics(
      label: count > 0 ? 'ตะกร้าสินค้า มี $count รายการ' : 'ตะกร้าสินค้า',
      button: true,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: _openCart,
          ),
          if (count > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Semantics(
      label: 'ค้นหาสินค้า/ร้านค้า',
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _openSearch(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'ค้นหาสินค้า/ร้านค้า',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        final categories = snapshot.data ?? const [];
        if (categories.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: categories
                .map(
                  (category) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(category.name),
                      onPressed: () => _openSearch(category: category),
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          'โปรโมชั่นเร็ว ๆ นี้',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildComingSoonSection(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text('เร็ว ๆ นี้', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );
  }

  Widget _buildNewProducts(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _newProductsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final products = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('สินค้าใหม่', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 4),
              if (products.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ยังไม่มีสินค้าในระบบ'),
                )
              else
                SizedBox(
                  height: 148,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: products
                        .map(
                          (product) => ProductMiniCard(
                            product: product,
                            onTap: () => _openProduct(product),
                          ),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecommendedStores(BuildContext context) {
    return FutureBuilder<List<Store>>(
      future: _recommendedStoresFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final stores = snapshot.data!;
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('ร้านค้าแนะนำ', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(height: 4),
              if (stores.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('ยังไม่มีสินค้าในระบบ'),
                )
              else
                SizedBox(
                  height: 108,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    children: stores
                        .map(
                          (store) => StoreMiniCard(store: store, onTap: () => _openStore(store)),
                        )
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context) {
    if (_isLoadingGrid) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_gridProducts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('ยังไม่มีสินค้าในระบบ')),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = _gridProducts[index];
            return ProductGridTile(product: product, onTap: () => _openProduct(product));
          },
          childCount: _gridProducts.length,
        ),
      ),
    );
  }
}
