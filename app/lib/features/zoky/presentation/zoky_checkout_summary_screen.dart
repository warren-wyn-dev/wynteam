import 'package:flutter/material.dart';

import '../../../core/text_utils.dart';
import '../data/cart_item.dart';
import '../data/zoky_repository.dart';
import '../../../core/design/wyn_spacing.dart';

/// Screen 4 (ZOKY-003) -- Checkout step 2 of 2: the fee/total
/// breakdown per store, reviewed in full before the buyer can confirm.
/// Submitting calls ZokyRepository.createOrders() once for every store
/// represented in the cart, atomically, then returns all the way back
/// to ZOKY Home (see AuthGate's popUntil(isFirst) pattern) rather than
/// leaving this now-stale Checkout stack reachable via back button.
/// See .wyn/docs/design/zoky-003-cart-checkout-order.md, Screen 4.
class ZokyCheckoutSummaryScreen extends StatefulWidget {
  const ZokyCheckoutSummaryScreen({
    super.key,
    required this.zokyRepository,
    required this.cartItems,
    required this.recipientName,
    required this.recipientPhone,
    required this.shippingAddress,
  });

  final ZokyRepository zokyRepository;
  final List<CartItem> cartItems;
  final String recipientName;
  final String recipientPhone;
  final String shippingAddress;

  @override
  State<ZokyCheckoutSummaryScreen> createState() => _ZokyCheckoutSummaryScreenState();
}

class _ZokyCheckoutSummaryScreenState extends State<ZokyCheckoutSummaryScreen> {
  late Future<double> _feePercentFuture;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _feePercentFuture = widget.zokyRepository.fetchMarketplaceFeePercent();
  }

  Future<void> _confirm() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.zokyRepository.createOrders(
        recipientName: widget.recipientName,
        recipientPhone: widget.recipientPhone,
        shippingAddress: widget.shippingAddress,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('สั่งซื้อสำเร็จ')));
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${e.productName} มีสินค้าไม่เพียงพอ กรุณาแก้ไขตะกร้า')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('สั่งซื้อไม่สำเร็จ ลองใหม่อีกครั้ง')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final byStore = <String, List<CartItem>>{};
    for (final item in widget.cartItems) {
      byStore.putIfAbsent(item.product.storeId, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('สรุปคำสั่งซื้อ')),
      body: FutureBuilder<double>(
        future: _feePercentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final feePercent = snapshot.data ?? 10;
          return _buildContent(context, byStore, feePercent);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(WynSpacing.space4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _confirm,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('ยืนยันคำสั่งซื้อ'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, List<CartItem>> byStore,
    double feePercent,
  ) {
    var grandTotal = 0.0;

    final storeCards = <Widget>[];
    for (final entry in byStore.entries) {
      final items = entry.value;
      final subtotal = items.fold<double>(0, (sum, i) => sum + i.lineTotal);
      final feeAmount = (subtotal * feePercent / 100);
      final total = subtotal + feeAmount;
      grandTotal += total;

      storeCards.add(
        Card(
          margin: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: WynSpacing.space2),
          child: Padding(
            padding: const EdgeInsets.all(WynSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 18),
                    const SizedBox(width: 6),
                    Text(items.first.product.storeName, style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                const Divider(height: 20),
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.product.name} x${item.quantity}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          thaiBahtLabel(item.lineTotal),
                          style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                _summaryRow(context, 'ค่าสินค้า', thaiBahtLabel(subtotal)),
                _summaryRow(
                  context,
                  'ค่าธรรมเนียมแพลตฟอร์ม (${feePercent.toStringAsFixed(0)}%)',
                  thaiBahtLabel(feeAmount),
                ),
                _summaryRow(context, 'ยอดรวม', thaiBahtLabel(total), emphasize: true),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Padding(
            padding: const EdgeInsets.all(WynSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ที่อยู่จัดส่ง', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: WynSpacing.space1),
                Text('${widget.recipientName} · ${widget.recipientPhone}'),
                Text(widget.shippingAddress),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('แก้ไข'),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...storeCards,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: _summaryRow(
            context,
            'ยอดรวมทั้งหมดทุกร้าน',
            thaiBahtLabel(grandTotal),
            emphasize: true,
            large: true,
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
    bool large = false,
  }) {
    final style = emphasize
        ? (large ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.titleSmall)
            ?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
