import 'package:flutter/material.dart';

import '../../../core/text_utils.dart';
import '../../search/presentation/widgets/search_state_message.dart';
import '../data/cart_item.dart';
import '../data/zoky_repository.dart';
import 'product_detail_screen.dart';
import 'store_screen.dart';
import 'widgets/zoky_cart_item_tile.dart';
import 'widgets/zoky_theme_scope.dart';
import 'zoky_checkout_address_screen.dart';

/// Screen 2 (ZOKY-003) -- the buyer's cart, grouped by store. Opened
/// from ZOKY Home's Cart icon (replacing the SnackBar placeholder from
/// ZOKY-001) and from ProductDetailScreen's "ซื้อเลย" button. See
/// .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 2.
class ZokyCartScreen extends StatefulWidget {
  const ZokyCartScreen({super.key, required this.zokyRepository});

  final ZokyRepository zokyRepository;

  @override
  State<ZokyCartScreen> createState() => _ZokyCartScreenState();
}

class _ZokyCartScreenState extends State<ZokyCartScreen> {
  List<CartItem>? _items;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final items = await widget.zokyRepository.fetchCartItems();
    if (!mounted) return;
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeQuantity(CartItem item, int newQuantity) async {
    final items = _items;
    if (items == null) return;
    final index = items.indexOf(item);
    setState(() {
      items[index] = CartItem(
        id: item.id,
        product: item.product,
        variantSelection: item.variantSelection,
        quantity: newQuantity,
      );
    });
    try {
      await widget.zokyRepository.updateCartItemQuantity(item.id, newQuantity);
    } catch (_) {
      if (!mounted) return;
      setState(() => items[index] = item);
      _showError('อัปเดตจำนวนไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  Future<void> _remove(CartItem item) async {
    final items = _items;
    if (items == null) return;
    setState(() => items.remove(item));
    try {
      await widget.zokyRepository.removeCartItem(item.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => items.add(item));
      _showError('ลบสินค้าไม่สำเร็จ ลองใหม่อีกครั้ง');
    }
  }

  void _openProduct(CartItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          zokyRepository: widget.zokyRepository,
          product: item.product,
        ),
      ),
    );
  }

  void _openStore(String storeId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StoreScreen(zokyRepository: widget.zokyRepository, storeId: storeId),
      ),
    );
  }

  void _checkout() {
    final items = _items;
    if (items == null || items.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZokyCheckoutAddressScreen(
          zokyRepository: widget.zokyRepository,
          cartItems: items,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return ZokyThemeScope(
      // Builder gives every nested Theme.of(context) call below (e.g.
      // inside _buildGroupedList -> ZokyCartItemTile) a context that is
      // a genuine *descendant* of ZokyThemeScope's Theme override.
      // Reusing the outer build(context) parameter directly would NOT
      // work -- see product_detail_screen.dart's build() for the full
      // explanation. Caught by this file's regression test
      // (zoky_price_orange_theme_regression_test.dart) before being
      // fixed here.
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('ตะกร้าสินค้า')),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : (items == null || items.isEmpty)
                  ? _buildEmptyState(context)
                  : _buildGroupedList(context, items),
          bottomNavigationBar:
              (items != null && items.isNotEmpty) ? _buildBottomBar(context, items) : null,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Expanded(
          child: SearchStateMessage(
            icon: Icons.shopping_cart_outlined,
            text: 'ตะกร้าของคุณว่างเปล่า',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('เลือกซื้อสินค้า'),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupedList(BuildContext context, List<CartItem> items) {
    final byStore = <String, List<CartItem>>{};
    for (final item in items) {
      byStore.putIfAbsent(item.product.storeId, () => []).add(item);
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          for (final entry in byStore.entries) ...[
            InkWell(
              onTap: () => _openStore(entry.key),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      entry.value.first.product.storeName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
            ),
            for (final item in entry.value)
              ZokyCartItemTile(
                item: item,
                onTap: () => _openProduct(item),
                onQuantityChanged: (quantity) => _changeQuantity(item, quantity),
                onRemove: () => _remove(item),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'รวมร้านนี้: ${thaiBahtLabel(entry.value.fold<double>(0, (sum, i) => sum + i.lineTotal))}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
            const Divider(height: 24, thickness: 1),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, List<CartItem> items) {
    final total = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                // Column defaults to MainAxisSize.max, which under
                // Scaffold.bottomNavigationBar's loose/unbounded height
                // constraint collapses the whole Scaffold body to zero
                // height instead of the usual visible overflow stripes
                // -- explicit .min keeps this Column only as tall as
                // its two Text children need.
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ยอดรวมทั้งหมด', style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    thaiBahtLabel(total),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: _checkout, child: const Text('ยืนยันคำสั่งซื้อ')),
          ],
        ),
      ),
    );
  }
}
