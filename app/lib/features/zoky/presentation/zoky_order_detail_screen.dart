import 'package:flutter/material.dart';

import '../../../core/text_utils.dart';
import '../data/order.dart';
import '../data/order_item.dart';
import '../data/review.dart';
import '../data/zoky_repository.dart';
import 'widgets/order_status_badge.dart';
import 'widgets/review_form_sheet.dart';
import 'widgets/star_rating.dart';
import '../../../core/design/wyn_spacing.dart';
import '../../../core/design/wyn_zoky_accent.dart';

/// Screen 6 (ZOKY-003, action bar made per-status by SELLER-003) -- a
/// single Order's full detail. Cancel shows only while status is
/// [OrderStatus.paid] (before the seller starts processing it); Confirm
/// Received shows only while [OrderStatus.shipped] -- the two buttons
/// are no longer all-or-nothing together the way they were when this
/// screen only had "pending" to check against. Every other status
/// (including the 2 middle "seller is handling this" ones) shows no
/// action bar at all -- there's nothing left for the buyer to do until
/// the seller ships it. See .wyn/docs/design/
/// seller-003-order-management.md, Screen: ZokyOrderDetailScreen.
class ZokyOrderDetailScreen extends StatefulWidget {
  const ZokyOrderDetailScreen({
    super.key,
    required this.zokyRepository,
    required this.orderId,
  });

  final ZokyRepository zokyRepository;
  final String orderId;

  @override
  State<ZokyOrderDetailScreen> createState() => _ZokyOrderDetailScreenState();
}

class _ZokyOrderDetailScreenState extends State<ZokyOrderDetailScreen> {
  Order? _order;
  List<OrderItem> _items = [];
  Map<String, Review?> _reviewsByOrderItemId = {};
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final order = await widget.zokyRepository.fetchOrder(widget.orderId);
    final items = await widget.zokyRepository.fetchOrderItems(widget.orderId);
    final reviews = order?.status == OrderStatus.delivered
        ? await _fetchReviews(items)
        : <String, Review?>{};
    if (!mounted) return;
    setState(() {
      _order = order;
      _items = items;
      _reviewsByOrderItemId = reviews;
      _isLoading = false;
    });
  }

  Future<Map<String, Review?>> _fetchReviews(List<OrderItem> items) async {
    final entries = <String, Review?>{};
    for (final item in items) {
      entries[item.id] = await widget.zokyRepository.fetchReviewForOrderItem(item.id);
    }
    return entries;
  }

  Future<void> _openReviewForm(OrderItem item) async {
    final productId = item.productId;
    if (productId == null) return;

    final changed = await showReviewFormSheet(
      context,
      zokyRepository: widget.zokyRepository,
      orderItemId: item.id,
      productId: productId,
      existingReview: _reviewsByOrderItemId[item.id],
    );
    if (changed) await _load();
  }

  Future<bool> _confirmDialog(String title, String content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _cancelOrder() async {
    final confirmed = await _confirmDialog(
      'ยกเลิกคำสั่งซื้อ?',
      'ยกเลิกแล้วไม่สามารถกู้คืนได้ ระบบจะคืนสินค้ากลับเข้าสต็อก',
    );
    if (!confirmed) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.zokyRepository.cancelOrder(widget.orderId);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ยกเลิกคำสั่งซื้อไม่สำเร็จ ลองใหม่อีกครั้ง')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _confirmReceived() async {
    final confirmed = await _confirmDialog(
      'ยืนยันได้รับสินค้าแล้ว?',
      'เมื่อยืนยันแล้วจะไม่สามารถยกเลิกคำสั่งซื้อนี้ได้อีก',
    );
    if (!confirmed) return;

    setState(() => _isSubmitting = true);
    try {
      await widget.zokyRepository.confirmOrderReceived(widget.orderId);
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ยืนยันไม่สำเร็จ ลองใหม่อีกครั้ง')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return ZokyAccentTheme(child: Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดคำสั่งซื้อ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : order == null
              ? const Center(child: Text('ไม่พบคำสั่งซื้อนี้'))
              : _buildContent(context, order),
      bottomNavigationBar: order != null && _hasAnyAction(order.status)
          ? _buildActionBar(context, order.status)
          : null,
    ));
  }

  /// Whether _buildActionBar has anything to render at all for
  /// [status] -- kept in sync with _buildActionBar's own per-button
  /// conditions below.
  bool _hasAnyAction(OrderStatus status) =>
      status == OrderStatus.paid || status == OrderStatus.shipped;

  Widget _buildContent(BuildContext context, Order order) {
    return ListView(
      padding: const EdgeInsets.all(WynSpacing.space4),
      children: [
        Align(alignment: Alignment.centerLeft, child: OrderStatusBadge(status: order.status)),
        const SizedBox(height: WynSpacing.space4),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(WynSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ที่อยู่จัดส่ง', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: WynSpacing.space1),
                Text('${order.recipientName} · ${order.recipientPhone}'),
                Text(order.shippingAddress),
              ],
            ),
          ),
        ),
        if (order.shippingProvider != null) ...[
          const SizedBox(height: WynSpacing.space3),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(WynSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ข้อมูลการจัดส่ง', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: WynSpacing.space1),
                  Text('ขนส่งโดย: ${order.shippingProvider}'),
                  Text('เลขพัสดุ: ${order.trackingNumber}'),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: WynSpacing.space3),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(WynSpacing.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('รายการสินค้า', style: Theme.of(context).textTheme.labelLarge),
                const Divider(height: 20),
                for (final item in _items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                              child: SizedBox(
                                width: 48,
                                height: 48,
                                child: item.imageUrl != null
                                    ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                                    : Container(
                                        color:
                                            Theme.of(context).colorScheme.surfaceContainerHighest,
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.productName),
                                  if (item.variantSelection.isNotEmpty)
                                    Text(
                                      item.variantSelection,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                    ),
                                  Text(
                                    '${thaiBahtLabel(item.unitPrice)} x${item.quantity}',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.tertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              thaiBahtLabel(item.lineTotal),
                              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
                            ),
                          ],
                        ),
                        if (order.status == OrderStatus.delivered && item.productId != null)
                          _buildReviewRow(context, item),
                      ],
                    ),
                  ),
                const Divider(height: 20),
                _summaryRow(context, 'ค่าสินค้า', thaiBahtLabel(order.subtotal)),
                _summaryRow(
                  context,
                  'ค่าธรรมเนียมแพลตฟอร์ม (${order.feePercent.toStringAsFixed(0)}%)',
                  thaiBahtLabel(order.feeAmount),
                ),
                _summaryRow(context, 'ยอดรวม', thaiBahtLabel(order.total), emphasize: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(BuildContext context, OrderItem item) {
    final review = _reviewsByOrderItemId[item.id];
    return Padding(
      padding: const EdgeInsets.only(left: 58, top: 2),
      child: review == null
          ? TextButton.icon(
              onPressed: () => _openReviewForm(item),
              icon: const Icon(Icons.star_border, size: 18),
              label: const Text('เขียนรีวิว'),
            )
          : Row(
              children: [
                StarRatingDisplay(rating: review.rating.toDouble()),
                const SizedBox(width: WynSpacing.space2),
                TextButton(
                  onPressed: () => _openReviewForm(item),
                  child: const Text('แก้ไขรีวิว'),
                ),
              ],
            ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value, {bool emphasize = false}) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)
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

  /// Per-status button set (SELLER-003) -- [status] is guaranteed to be
  /// one that [_hasAnyAction] returns true for, since [build] only
  /// calls this when that's the case.
  Widget _buildActionBar(BuildContext context, OrderStatus status) {
    final buttons = <Widget>[
      if (status == OrderStatus.paid)
        Expanded(
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _cancelOrder,
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('ยกเลิกคำสั่งซื้อ'),
          ),
        ),
      if (status == OrderStatus.shipped)
        Expanded(
          child: FilledButton(
            onPressed: _isSubmitting ? null : _confirmReceived,
            child: const Text('ยืนยันได้รับสินค้าแล้ว'),
          ),
        ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(WynSpacing.space3),
        child: Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: WynSpacing.space3),
              buttons[i],
            ],
          ],
        ),
      ),
    );
  }
}
