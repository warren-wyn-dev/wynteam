import 'package:flutter/material.dart';

import '../../../core/text_utils.dart';
import '../../store/data/seller_repository.dart';
import '../data/order.dart';
import '../data/order_item.dart';
import 'widgets/order_status_badge.dart';

/// A single order's full detail + status-transition actions -- mirrors
/// `ZokyOrderDetailScreen` (ZOKY-003)'s recipient/items/summary card
/// shape exactly (minus the review row, which is buyer-only), plus a
/// per-status action bar that only ever shows the transitions valid
/// from the order's *current* status (never a disabled button for an
/// invalid one). See .wyn/docs/design/seller-003-order-management.md,
/// Screen: SellerOrderDetailScreen.
class SellerOrderDetailScreen extends StatefulWidget {
  const SellerOrderDetailScreen({
    super.key,
    required this.sellerRepository,
    required this.orderId,
  });

  final SellerRepository sellerRepository;
  final String orderId;

  @override
  State<SellerOrderDetailScreen> createState() => _SellerOrderDetailScreenState();
}

/// Which action is currently in flight, if any -- lets the action bar
/// disable every button while one is submitting (no double-tap) while
/// only showing a spinner inside the specific button that was pressed,
/// mirroring StockAdjustmentSheet's (SELLER-002) `_isSubmitting` pattern.
enum _PendingAction { startProcessing, markReadyToShip, shipOrder, cancelOrder, markRefunded }

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  final _shippingProviderController = TextEditingController();
  final _trackingNumberController = TextEditingController();

  Order? _order;
  List<OrderItem> _items = [];
  bool _isLoading = true;
  _PendingAction? _pendingAction;

  bool get _isSubmitting => _pendingAction != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _shippingProviderController.dispose();
    _trackingNumberController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final order = await widget.sellerRepository.fetchStoreOrder(widget.orderId);
    final items = await widget.sellerRepository.fetchStoreOrderItems(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = order;
      _items = items;
      _isLoading = false;
    });
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

  Future<void> _run(
    _PendingAction action,
    Future<void> Function() call, {
    required String failureMessage,
  }) async {
    setState(() => _pendingAction = action);
    try {
      await call();
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failureMessage)));
    } finally {
      if (mounted) setState(() => _pendingAction = null);
    }
  }

  Future<void> _startProcessing() => _run(
        _PendingAction.startProcessing,
        () => widget.sellerRepository.sellerStartProcessing(widget.orderId),
        failureMessage: 'เริ่มเตรียมสินค้าไม่สำเร็จ ลองใหม่อีกครั้ง',
      );

  Future<void> _markReadyToShip() => _run(
        _PendingAction.markReadyToShip,
        () => widget.sellerRepository.sellerMarkReadyToShip(widget.orderId),
        failureMessage: 'อัปเดตสถานะไม่สำเร็จ ลองใหม่อีกครั้ง',
      );

  Future<void> _shipOrder() {
    final provider = _shippingProviderController.text.trim();
    final tracking = _trackingNumberController.text.trim();
    if (provider.isEmpty || tracking.isEmpty) return Future.value();
    return _run(
      _PendingAction.shipOrder,
      () => widget.sellerRepository.sellerShipOrder(widget.orderId, provider, tracking),
      failureMessage: 'ยืนยันจัดส่งไม่สำเร็จ ลองใหม่อีกครั้ง',
    );
  }

  Future<void> _cancelOrder() async {
    final confirmed = await _confirmDialog(
      'ยกเลิกคำสั่งซื้อ?',
      'ยกเลิกแล้วไม่สามารถกู้คืนได้ ระบบจะคืนสินค้ากลับเข้าสต็อก',
    );
    if (!confirmed) return;
    await _run(
      _PendingAction.cancelOrder,
      () => widget.sellerRepository.sellerCancelOrder(widget.orderId),
      failureMessage: 'ยกเลิกคำสั่งซื้อไม่สำเร็จ ลองใหม่อีกครั้ง',
    );
  }

  Future<void> _markRefunded() async {
    final confirmed = await _confirmDialog(
      'ทำเครื่องหมายคืนเงินแล้ว?',
      'การกระทำนี้เป็นการบันทึกบัญชีเท่านั้น ระบบยังไม่มีการโอนเงินคืนอัตโนมัติ '
          'กรุณาดำเนินการคืนเงินจริงให้ลูกค้าด้วยตนเองก่อนยืนยัน',
    );
    if (!confirmed) return;
    await _run(
      _PendingAction.markRefunded,
      () => widget.sellerRepository.sellerMarkRefunded(widget.orderId),
      failureMessage: 'บันทึกการคืนเงินไม่สำเร็จ ลองใหม่อีกครั้ง',
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      appBar: AppBar(title: const Text('รายละเอียดคำสั่งซื้อ')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : order == null
              ? const Center(child: Text('ไม่พบคำสั่งซื้อนี้'))
              : _buildContent(context, order),
      bottomNavigationBar: order != null ? _buildActionBar(context, order.status) : null,
    );
  }

  Widget _buildContent(BuildContext context, Order order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(alignment: Alignment.centerLeft, child: OrderStatusBadge(status: order.status)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ข้อมูลผู้รับ', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text('${order.recipientName} · ${order.recipientPhone}'),
                Text(order.shippingAddress),
              ],
            ),
          ),
        ),
        if (order.shippingProvider != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ข้อมูลการจัดส่ง', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text('ขนส่งโดย: ${order.shippingProvider}'),
                  Text('เลขพัสดุ: ${order.trackingNumber}'),
                ],
              ),
            ),
          ),
        ],
        if (order.status == OrderStatus.readyToShip) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('กรอกข้อมูลการจัดส่ง', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _shippingProviderController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(labelText: 'ผู้ให้บริการขนส่ง'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _trackingNumberController,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(labelText: 'เลขพัสดุ'),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('รายการสินค้า', style: Theme.of(context).textTheme.labelLarge),
                const Divider(height: 20),
                for (final item in _items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: item.imageUrl != null
                                ? Image.network(item.imageUrl!, fit: BoxFit.cover)
                                : Container(
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                              Text('${thaiBahtLabel(item.unitPrice)} x${item.quantity}'),
                            ],
                          ),
                        ),
                        Text(thaiBahtLabel(item.lineTotal)),
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

  Widget _spinnerOr(_PendingAction action, String label) {
    return _pendingAction == action
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(label);
  }

  /// Returns `null` (no `bottomNavigationBar` at all) for
  /// cancelled/refunded/pendingPayment -- final or unreachable states,
  /// per the Design spec.
  Widget? _buildActionBar(BuildContext context, OrderStatus status) {
    final canShip = _shippingProviderController.text.trim().isNotEmpty &&
        _trackingNumberController.text.trim().isNotEmpty;

    final Widget? primary = switch (status) {
      OrderStatus.paid => FilledButton(
          onPressed: _isSubmitting ? null : _startProcessing,
          child: _spinnerOr(_PendingAction.startProcessing, 'เริ่มเตรียมสินค้า'),
        ),
      OrderStatus.sellerProcessing => FilledButton(
          onPressed: _isSubmitting ? null : _markReadyToShip,
          child: _spinnerOr(_PendingAction.markReadyToShip, 'พร้อมจัดส่ง'),
        ),
      OrderStatus.readyToShip => FilledButton(
          onPressed: (_isSubmitting || !canShip) ? null : _shipOrder,
          child: _spinnerOr(_PendingAction.shipOrder, 'ยืนยันจัดส่งแล้ว'),
        ),
      _ => null,
    };

    final Widget? cancel = (status == OrderStatus.paid ||
            status == OrderStatus.sellerProcessing ||
            status == OrderStatus.readyToShip)
        ? OutlinedButton(
            onPressed: _isSubmitting ? null : _cancelOrder,
            style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: _spinnerOr(_PendingAction.cancelOrder, 'ยกเลิกคำสั่งซื้อ'),
          )
        : null;

    final Widget? refund = (status == OrderStatus.shipped || status == OrderStatus.delivered)
        ? OutlinedButton(
            onPressed: _isSubmitting ? null : _markRefunded,
            child: _spinnerOr(_PendingAction.markRefunded, 'ทำเครื่องหมายคืนเงินแล้ว'),
          )
        : null;

    final buttons = [primary, cancel, refund].whereType<Widget>().toList();
    if (buttons.isEmpty) return null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            for (var i = 0; i < buttons.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: buttons[i]),
            ],
          ],
        ),
      ),
    );
  }
}
