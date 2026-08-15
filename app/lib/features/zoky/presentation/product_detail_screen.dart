import 'package:flutter/material.dart';

import '../../../core/text_utils.dart';
import '../data/product.dart';
import '../data/product_variant.dart';
import '../data/zoky_repository.dart';
import 'store_screen.dart';
import 'widgets/product_images.dart';
import 'zoky_cart_screen.dart';

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

  // Selected value per variant type -- preview only, doesn't affect the
  // price/stock shown anywhere since there's no Cart yet to make this a
  // real transactional state.
  final Map<VariantType, String> _selectedVariant = {};

  @override
  void initState() {
    super.initState();
    _variantsFuture = widget.zokyRepository.fetchProductVariants(widget.product.id);
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

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                ProductImages(imageUrls: product.imageUrls),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPriceRow(context),
                      const SizedBox(height: 4),
                      Text(product.name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
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
                        const SizedBox(height: 16),
                        Text('รายละเอียดสินค้า',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 4),
                        Text(product.description!),
                      ],
                      const SizedBox(height: 16),
                      Text('รีวิว', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Text(
                        'ยังไม่มีรีวิว',
                        style: TextStyle(color: Theme.of(context).colorScheme.outline),
                      ),
                      const SizedBox(height: 16),
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
    );
  }

  Widget _buildPriceRow(BuildContext context) {
    final product = widget.product;
    return Row(
      children: [
        Text(
          thaiBahtLabel(product.price),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        if (product.hasDiscount) ...[
          const SizedBox(width: 8),
          Text(
            thaiBahtLabel(product.originalPrice!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                  decoration: TextDecoration.lineThrough,
                ),
          ),
          const SizedBox(width: 8),
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
              padding: const EdgeInsets.only(top: 12),
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

  Widget _buildStoreCard(BuildContext context) {
    final product = widget.product;
    return Semantics(
      label: 'ร้านค้า ${product.storeName} กดเพื่อดูร้านค้า',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: _openStore,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
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
              const SizedBox(width: 12),
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
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: outOfStock ? null : _onAddToCartPressed,
                child: Text(outOfStock ? 'สินค้าหมด' : 'เพิ่มลงตะกร้า'),
              ),
            ),
            const SizedBox(width: 12),
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
