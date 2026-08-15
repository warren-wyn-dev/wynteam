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
            return Column(
              children: [
                _buildHeader(context, store),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.grid_view_outlined), text: 'สินค้าทั้งหมด'),
                    Tab(icon: Icon(Icons.star_outline), text: 'รีวิว'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildProductsTab(context),
                      _buildReviewsTab(context),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Store store) {
    return Padding(
      padding: const EdgeInsets.all(16),
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
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
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
                            const SizedBox(width: 4),
                            Text(
                              '${rating.$1.toStringAsFixed(1)} · 0 ผู้ติดตาม · ${store.productCount} สินค้า',
                              style: TextStyle(color: Theme.of(context).colorScheme.outline),
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
            const SizedBox(height: 12),
            Text(store.description!),
          ],
          const SizedBox(height: 12),
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

  Widget _buildProductsTab(BuildContext context) {
    return FutureBuilder<List<Product>>(
      future: _productsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data!;
        if (products.isEmpty) {
          return const Center(child: Text('ร้านนี้ยังไม่มีสินค้า'));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            return ProductGridTile(product: product, onTap: () => _openProduct(product));
          },
        );
      },
    );
  }

  Widget _buildReviewsTab(BuildContext context) {
    return FutureBuilder<List<Review>>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final reviews = snapshot.data!;
        if (reviews.isEmpty) {
          return const Center(child: Text('ยังไม่มีรีวิว'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: reviews.length,
          itemBuilder: (context, index) => ReviewTile(review: reviews[index]),
        );
      },
    );
  }
}
