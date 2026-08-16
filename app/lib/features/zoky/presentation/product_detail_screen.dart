import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/text_utils.dart';
import '../data/order_item.dart';
import '../data/product.dart';
import '../data/product_variant.dart';
import '../data/review.dart';
import '../data/zoky_repository.dart';
import 'product_reviews_screen.dart';
import 'store_screen.dart';
import 'widgets/product_images.dart';
import 'widgets/review_form_sheet.dart';
import 'widgets/review_tile.dart';
import 'widgets/star_rating.dart';
import 'zoky_cart_screen.dart';
import 'zoky_order_list_screen.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_zoky_accent.dart';

const _reviewsPreviewLimit = 3;

/// Placeholder share link -- same "no real hosting/domain yet" caveat as
/// dropShareLink/popShareLink/clubPostShareLink (WYN-005/006/WYN CLUB).
/// See .wyn/tasks/backlog/WYN-010-share-formalization.md.
String productShareLink(String productId) => 'https://wyn.app/product/$productId';

/// Screen 2 — Product Detail (ZOKY-001). Add to Cart/Buy Now work for
/// real as of ZOKY-003. See
/// .wyn/docs/design/zoky-001-marketplace-foundation.md, Screen 2 and
/// .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 1.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.zokyRepository,
    required this.product,
  });

  final ZokyRepository zokyRepository;
  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<List<ProductVariant>> _variantsFuture;
  late Future<(double, int)> _ratingFuture;
  late Future<List<Review>> _reviewsFuture;
  late Future<List<OrderItem>> _reviewableOrderItemsFuture;

  // Selected value per variant type -- preview only, doesn't affect the
  // price/stock shown anywhere since there's no Cart yet to make this a
  // real transactional state.
  final Map<VariantType, String> _selectedVariant = {};

  @override
  void initState() {
    super.initState();
    _variantsFuture = widget.zokyRepository.fetchProductVariants(widget.product.id);
    _loadReviewData();
  }

  // Refreshed after ReviewFormSheet reports a change (write/edit/delete)
  // so the rating summary/list/entry-point all reflect it immediately.
  void _loadReviewData() {
    _ratingFuture = widget.zokyRepository.fetchProductRating(widget.product.id);
    _reviewsFuture = widget.zokyRepository
        .fetchProductReviews(widget.product.id, limit: _reviewsPreviewLimit);
    _reviewableOrderItemsFuture =
        widget.zokyRepository.fetchReviewableOrderItems(widget.product.id);
  }

  String _variantSelectionText() {
    if (_selectedVariant.isEmpty) return '';
    return _selectedVariant.entries
        .map((entry) => '${entry.key == VariantType.color ? 'สี' : 'ไซส์'}: ${entry.value}')
        .join(', ');
  }

  Future<bool> _addToCart() async {
    try {
      await widget.zokyRepository.addToCart(
        productId: widget.product.id,
        variantSelection: _variantSelectionText(),
      );
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('เพิ่มลงตะกร้าไม่สำเร็จ ลองใหม่อีกครั้ง')));
      return false;
    }
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZokyCartScreen(zokyRepository: widget.zokyRepository),
      ),
    );
  }

  Future<void> _onAddToCartPressed() async {
    final success = await _addToCart();
    if (!success || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('เพิ่มลงตะกร้าแล้ว'),
        action: SnackBarAction(label: 'ดูตะกร้า', onPressed: _openCart),
      ),
    );
  }

  Future<void> _onBuyNowPressed() async {
    final success = await _addToCart();
    if (!success || !mounted) return;
    _openCart();
  }

  void _openStore() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreScreen(
          zokyRepository: widget.zokyRepository,
          storeId: widget.product.storeId,
        ),
      ),
    );
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(
        text: productShareLink(widget.product.id),
        title: 'สินค้าบน WYN',
      ),
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: productShareLink(widget.product.id)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('คัดลอกลิงก์แล้ว')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return ZokyAccentTheme(child: Scaffold(
      appBar: AppBar(
        title: Text(product.name),
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ProductImages(imageUrls: product.imageUrls),
                Padding(
                  padding: const EdgeInsets.all(WynSpacing.space4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPriceRow(context),
                      const SizedBox(height: WynSpacing.space1),
                      Text(product.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: WynSpacing.space1),
                      Text(
                        product.stock > 0 ? 'เหลือ ${product.stock} ชิ้น' : 'สินค้าหมด',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: product.stock > 0
                                  ? Theme.of(context).colorScheme.outline
                                  : Theme.of(context).colorScheme.error,
                            ),
                      ),
                      _buildVariants(context),
                      if (product.description != null) ...[
                        const SizedBox(height: WynSpacing.space4),
                        Text('รายละเอียดสินค้า',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: WynSpacing.space1),
                        Text(product.description!),
                      ],
                      const SizedBox(height: WynSpacing.space4),
                      Text('รีวิว', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: WynSpacing.space1),
                      _buildReviewsSection(context),
                      const SizedBox(height: WynSpacing.space4),
                      _buildStoreCard(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildActionBar(context),
        ],
      ),
    ));
  }

  Widget _buildPriceRow(BuildContext context) {
    final product = widget.product;
    return Row(
      children: [
        Text(
          thaiBahtLabel(product.price),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.tertiary,
                fontWeight: FontWeight.bold,
              ),
        ),
        if (product.hasDiscount) ...[
          const SizedBox(width: WynSpacing.space2),
          Text(
            thaiBahtLabel(product.originalPrice!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  decoration: TextDecoration.lineThrough,
                ),
          ),
          const SizedBox(width: WynSpacing.space2),
          Chip(
            label: Text('-${product.discountPercent}%'),
            visualDensity: VisualDensity.compact,
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            labelStyle: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
          ),
        ],
      ],
    );
  }

  Widget _buildVariants(BuildContext context) {
    return FutureBuilder<List<ProductVariant>>(
      future: _variantsFuture,
      builder: (context, snapshot) {
        final variants = snapshot.data;
        if (variants == null || variants.isEmpty) return const SizedBox.shrink();

        final byType = <VariantType, List<ProductVariant>>{};
        for (final variant in variants) {
          byType.putIfAbsent(variant.type, () => []).add(variant);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: byType.entries.map((entry) {
            final label = entry.key == VariantType.color ? 'สี' : 'ไซส์';
            return Padding(
              padding: const EdgeInsets.only(top: WynSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: entry.value.map((variant) {
                      final selected = _selectedVariant[entry.key] == variant.value;
                      return ChoiceChip(
                        label: Text(variant.value),
                        selected: selected,
                        onSelected: (_) => setState(
                          () => _selectedVariant[entry.key] = variant.value,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildReviewsSection(BuildContext context) {
    return FutureBuilder<(double, int)>(
      future: _ratingFuture,
      builder: (context, ratingSnapshot) {
        final rating = ratingSnapshot.data;
        if (rating == null || rating.$2 == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ยังไม่มีรีวิว',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              _buildReviewEntryPoint(context),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StarRatingDisplay(rating: rating.$1),
                const SizedBox(width: 6),
                Text('${rating.$1.toStringAsFixed(1)} (${rating.$2} รีวิว)'),
              ],
            ),
            const SizedBox(height: WynSpacing.space2),
            FutureBuilder<List<Review>>(
              future: _reviewsFuture,
              builder: (context, reviewsSnapshot) {
                final reviews = reviewsSnapshot.data;
                if (reviews == null) return const SizedBox.shrink();
                return Column(
                  children: [for (final review in reviews) ReviewTile(review: review)],
                );
              },
            ),
            if (rating.$2 > _reviewsPreviewLimit)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductReviewsScreen(
                        zokyRepository: widget.zokyRepository,
                        productId: widget.product.id,
                        rating: rating.$1,
                        reviewCount: rating.$2,
                      ),
                    ),
                  ),
                  child: const Text('ดูรีวิวทั้งหมด'),
                ),
              ),
            _buildReviewEntryPoint(context),
          ],
        );
      },
    );
  }

  Widget _buildReviewEntryPoint(BuildContext context) {
    return FutureBuilder<List<OrderItem>>(
      future: _reviewableOrderItemsFuture,
      builder: (context, snapshot) {
        final reviewable = snapshot.data;
        if (reviewable == null || reviewable.isEmpty) return const SizedBox.shrink();

        if (reviewable.length == 1) {
          final item = reviewable.first;
          return TextButton.icon(
            onPressed: () async {
              final changed = await showReviewFormSheet(
                context,
                zokyRepository: widget.zokyRepository,
                orderItemId: item.id,
                productId: widget.product.id,
              );
              if (changed && mounted) setState(_loadReviewData);
            },
            icon: const Icon(Icons.star_border, size: 18),
            label: const Text('เขียนรีวิว'),
          );
        }

        // More than one delivered, unreviewed purchase of this product
        // -- can't tell which order_item the user means from here, so
        // point at Order List instead of building a picker (see the
        // Design spec's decision on this edge case).
        return TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ZokyOrderListScreen(zokyRepository: widget.zokyRepository),
            ),
          ),
          child: const Text('คุณมีสินค้าที่ยังไม่ได้รีวิว ไปที่คำสั่งซื้อของคุณ'),
        );
      },
    );
  }

  Widget _buildStoreCard(BuildContext context) {
    final product = widget.product;
    return Semantics(
      label: 'ร้านค้า ${product.storeName} กดเพื่อดูร้านค้า',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: _openStore,
        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: WynSpacing.space2),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  product.storeName.isNotEmpty ? product.storeName[0].toUpperCase() : '?',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Text(product.storeName, style: Theme.of(context).textTheme.titleSmall),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(BuildContext context) {
    final outOfStock = widget.product.stock <= 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(WynSpacing.space3),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: outOfStock ? null : _onAddToCartPressed,
                child: Text(outOfStock ? 'สินค้าหมด' : 'เพิ่มลงตะกร้า'),
              ),
            ),
            const SizedBox(width: WynSpacing.space3),
            Expanded(
              child: FilledButton(
                onPressed: outOfStock ? null : _onBuyNowPressed,
                child: Text(outOfStock ? 'สินค้าหมด' : 'ซื้อเลย'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
