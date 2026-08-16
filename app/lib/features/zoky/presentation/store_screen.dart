import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/product.dart';
import '../data/review.dart';
import '../data/store.dart';
import '../data/zoky_repository.dart';
import 'product_detail_screen.dart';
import 'widgets/product_grid_tile.dart';
import 'widgets/review_tile.dart';
import 'widgets/star_rating.dart';
import 'zoky_strings.dart';
import '../../../core/design/wyn_spacing.dart';

/// Placeholder share link -- same "no real hosting/domain yet" caveat as
/// dropShareLink/popShareLink/clubPostShareLink/productShareLink
/// (WYN-005/006/WYN CLUB/WYN-010). See
/// .wyn/tasks/backlog/WYN-010-share-formalization.md.
String storeShareLink(String storeId) => 'https://wyn.app/store/$storeId';

/// Screen 3 — Store (ZOKY-001). Follow Store shows but doesn't work yet
/// (needs a new store_follows data model, not built this round). Chat
/// Seller is omitted entirely -- there's no messaging system in the app
/// to build even a placeholder for. See
/// .wyn/docs/design/zoky-001-marketplace-foundation.md, Screen 3.
class StoreScreen extends StatefulWidget {
  const StoreScreen({
    super.key,
    required this.zokyRepository,
    required this.storeId,
  });

  final ZokyRepository zokyRepository;
  final String storeId;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late Future<Store?> _storeFuture;
  late Future<List<Product>> _productsFuture;
  late Future<(double, int)> _ratingFuture;
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _storeFuture = widget.zokyRepository.fetchStore(widget.storeId);
    _productsFuture = widget.zokyRepository.fetchStoreProducts(widget.storeId);
    _ratingFuture = widget.zokyRepository.fetchStoreRating(widget.storeId);
    _reviewsFuture = widget.zokyRepository.fetchStoreReviews(widget.storeId);
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(zokyComingSoonMessage)));
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

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: storeShareLink(widget.storeId),
        title: 'ร้านค้าบน WYN',
      ),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: storeShareLink(widget.storeId)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('ร้านค้า'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'แชร์',
              onPressed: _share,
            ),
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'คัดลอกลิงก์',
              onPressed: _copyLink,
            ),
          ],
        ),
        body: FutureBuilder<Store?>(
          future: _storeFuture,
          builder: (context, snapshot) {
            // Store? is a legitimately nullable future (null means "not
            // found", not "still loading") -- AsyncSnapshot.hasData is
            // `data != null`, which would stay false forever for a
            // completed-but-null future, so the connection state (not
            // hasData) is what actually distinguishes "still loading"
            // here.
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final store = snapshot.data;
            if (store == null) {
              return const Center(child: Text('ไม่พบร้านค้านี้'));
            }
            // The banner + header scroll away with the page instead of
            // sitting in a non-scrollable Column above the tabs: their
            // height depends on the seller's own data (a 16:9 banner is
            // 56.25% of the screen width, the "ข้อมูลร้านค้า" card grows
            // with the address/hours text, and both grow again at large
            // text scales), so a fixed Column would hand whatever is left
            // -- sometimes nothing at all -- to the tab content. See
            // .wyn/tasks/bugs/SELLER-004-store-screen-header-overflow.md.
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (store.bannerUrl != null) _buildBanner(context, store),
                      _buildHeader(context, store),
                    ],
                  ),
                ),
                // The pinned TabBar covers the top of the body while the
                // page is scrolled, so its height is absorbed here and
                // re-injected at the top of each tab (see
                // `_buildProductsTab`/`_buildReviewsTab`) -- otherwise the
                // first row of products scrolls *underneath* the tabs and
                // can't be tapped there.
                SliverOverlapAbsorber(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: const SliverPersistentHeader(
                    pinned: true,
                    delegate: _StoreTabBarHeaderDelegate(),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  _buildProductsTab(context),
                  _buildReviewsTab(context),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Edge-to-edge, above `_buildHeader` -- deliberately not the
  /// Stack+Positioned overlap `club_page.dart`'s cover uses, per the
  /// Design spec (banner sits *above* the logo+name row, doesn't overlap
  /// it). Only rendered by the caller when `store.bannerUrl != null`, so
  /// stores with no banner (every seed store as of SELLER-004) render
  /// identically to before this change.
  Widget _buildBanner(BuildContext context, Store store) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Image.network(store.bannerUrl!, fit: BoxFit.cover),
    );
  }

  bool _hasStoreInfo(Store store) =>
      store.address != null || store.contactPhone != null || store.businessHours != null;

  /// "ข้อมูลร้านค้า" section -- only ever called when [_hasStoreInfo] is
  /// true, and only renders the rows whose field is actually non-null.
  /// See .wyn/docs/design/seller-004-store-management.md, Screen:
  /// StoreScreen.
  Widget _buildStoreInfoSection(BuildContext context, Store store) {
    final rows = <Widget>[
      if (store.address != null)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_outlined, size: 18),
            const SizedBox(width: WynSpacing.space2),
            Expanded(child: Text(store.address!)),
          ],
        ),
      if (store.contactPhone != null)
        Row(
          children: [
            const Icon(Icons.call_outlined, size: 18),
            const SizedBox(width: WynSpacing.space2),
            Text(store.contactPhone!),
          ],
        ),
      if (store.businessHours != null)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.access_time_outlined, size: 18),
            const SizedBox(width: WynSpacing.space2),
            Expanded(child: Text(store.businessHours!)),
          ],
        ),
    ];

    final semanticsParts = <String>[
      if (store.address != null) 'ที่อยู่ ${store.address!}',
      if (store.contactPhone != null) 'เบอร์ติดต่อ ${store.contactPhone!}',
      if (store.businessHours != null) 'เวลาทำการ ${store.businessHours!}',
    ];

    return Semantics(
      label: 'ข้อมูลร้านค้า: ${semanticsParts.join(', ')}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: WynSpacing.space2),
                rows[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Store store) {
    return Padding(
      padding: const EdgeInsets.all(WynSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage:
                    store.logoUrl != null ? NetworkImage(store.logoUrl!) : null,
                child: store.logoUrl == null
                    ? Text(
                        store.name.isNotEmpty ? store.name[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 22,
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: WynSpacing.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: WynSpacing.space1),
                    FutureBuilder<(double, int)>(
                      future: _ratingFuture,
                      builder: (context, snapshot) {
                        final rating = snapshot.data;
                        if (rating == null || rating.$2 == 0) {
                          return Text(
                            'ยังไม่มีรีวิว · 0 ผู้ติดตาม · ${store.productCount} สินค้า',
                            style: TextStyle(color: Theme.of(context).colorScheme.outline),
                          );
                        }
                        return Row(
                          children: [
                            StarRatingDisplay(rating: rating.$1),
                            const SizedBox(width: WynSpacing.space1),
                            Expanded(
                              child: Text(
                                '${rating.$1.toStringAsFixed(1)} · 0 ผู้ติดตาม · ${store.productCount} สินค้า',
                                style: TextStyle(color: Theme.of(context).colorScheme.outline),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (store.description != null && store.description!.isNotEmpty) ...[
            const SizedBox(height: WynSpacing.space3),
            Text(store.description!),
          ],
          if (_hasStoreInfo(store)) ...[
            const SizedBox(height: WynSpacing.space3),
            _buildStoreInfoSection(context, store),
          ],
          const SizedBox(height: WynSpacing.space3),
          Semantics(
            label: 'ติดตามร้าน ${store.name}',
            child: OutlinedButton(
              onPressed: _showComingSoon,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
              child: const Text('ติดตามร้าน'),
            ),
          ),
        ],
      ),
    );
  }

  /// Each tab is its own CustomScrollView (rather than a plain GridView/
  /// ListView) purely so it can start with the [SliverOverlapInjector] that
  /// pairs with the [SliverOverlapAbsorber] around the pinned TabBar. The
  /// content, padding and empty/loading states are the same as before.
  Widget _buildProductsTab(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        final products = snapshot.data;
        return CustomScrollView(
          key: const PageStorageKey<String>('store-products-tab'),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            if (products == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (products.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('ร้านนี้ยังไม่มีสินค้า')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = products[index];
                      return ProductGridTile(
                        product: product,
                        onTap: () => _openProduct(product),
                      );
                    },
                    childCount: products.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildReviewsTab(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        final reviews = snapshot.data;
        return CustomScrollView(
          key: const PageStorageKey<String>('store-reviews-tab'),
          slivers: [
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            if (reviews == null)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (reviews.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('ยังไม่มีรีวิว')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => ReviewTile(review: reviews[index]),
                    childCount: reviews.length,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Keeps the same TabBar as before (same 2 tabs, same icons, same labels,
/// same DefaultTabController) pinned to the top of the scroll view once the
/// banner/header have scrolled past it, so the tabs stay reachable no
/// matter how tall the header grew.
class _StoreTabBarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _StoreTabBarHeaderDelegate();

  static const TabBar _tabBar = TabBar(
    tabs: [
      Tab(icon: Icon(Icons.grid_view_outlined), text: 'สินค้าทั้งหมด'),
      Tab(icon: Icon(Icons.star_outline), text: 'รีวิว'),
    ],
  );

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // Opaque, otherwise the header/product content scrolls visibly
    // underneath the pinned tabs.
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _StoreTabBarHeaderDelegate oldDelegate) => false;
}
