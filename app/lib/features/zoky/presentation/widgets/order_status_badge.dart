import 'package:flutter/material.dart';

import '../../data/order.dart';
import '../../../../core/design/wyn_spacing.dart';

/// Shared status pill for Order List/Detail (ZOKY-003, expanded to 8
/// statuses by SELLER-003) -- always color+icon+text together, never
/// color alone, per the Accessibility rule in design-principles.md
/// ("ไม่สื่อสารข้อมูลด้วยสีอย่างเดียว"). The 4 "in progress" statuses
/// (paid/sellerProcessing/readyToShip/shipped) intentionally share one
/// blue tone (`primaryContainer`/`onPrimaryContainer`) -- they're all
/// "someone still needs to act on this, not a final state" -- and are
/// told apart by icon+text only, same accessibility rule this widget
/// already had to satisfy for every other status. delivered/cancelled
/// keep the project's existing green=success/red=error convention
/// unchanged; refunded reuses pendingPayment's neutral gray rather than
/// cancelled's red, since a refund isn't "the order failed from the
/// start" the way a cancellation is. See .wyn/docs/design/
/// seller-003-order-management.md, Widget: OrderStatusBadge.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  static const _labels = {
    OrderStatus.pendingPayment: 'รอชำระเงิน',
    OrderStatus.paid: 'ชำระเงินแล้ว',
    OrderStatus.sellerProcessing: 'ร้านค้ากำลังเตรียมสินค้า',
    OrderStatus.readyToShip: 'พร้อมจัดส่ง',
    OrderStatus.shipped: 'จัดส่งแล้ว',
    OrderStatus.delivered: 'ได้รับสินค้าแล้ว',
    OrderStatus.cancelled: 'ยกเลิกแล้ว',
    OrderStatus.refunded: 'คืนเงินแล้ว',
  };

  static const _icons = {
    OrderStatus.pendingPayment: Icons.hourglass_empty,
    OrderStatus.paid: Icons.payments,
    OrderStatus.sellerProcessing: Icons.inventory_2,
    OrderStatus.readyToShip: Icons.outbox,
    OrderStatus.shipped: Icons.local_shipping,
    OrderStatus.delivered: Icons.check_circle,
    OrderStatus.cancelled: Icons.cancel,
    OrderStatus.refunded: Icons.currency_exchange,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      OrderStatus.pendingPayment ||
      OrderStatus.refunded =>
        (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
      OrderStatus.paid ||
      OrderStatus.sellerProcessing ||
      OrderStatus.readyToShip ||
      OrderStatus.shipped =>
        (colorScheme.primaryContainer, colorScheme.onPrimaryContainer),
      OrderStatus.delivered => (Colors.green.shade100, Colors.green.shade800),
      OrderStatus.cancelled => (colorScheme.errorContainer, colorScheme.onErrorContainer),
    };
    final label = _labels[status]!;

    return Semantics(
      label: 'สถานะคำสั่งซื้อ: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space2, vertical: WynSpacing.space1),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(WynSpacing.radiusMd)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[status], size: 14, color: foreground),
            const SizedBox(width: WynSpacing.space1),
            Text(
              label,
              style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
