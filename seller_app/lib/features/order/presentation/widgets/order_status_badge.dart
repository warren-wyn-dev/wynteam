import 'package:flutter/material.dart';

import '../../data/order.dart';

/// Duplicated from `app/lib/features/zoky/presentation/widgets/
/// order_status_badge.dart` (SELLER-003, separate Flutter binary, same
/// pattern SELLER-001/002 already established) -- same table/text/color
/// exactly, so a seller sees the identical label for a given status
/// that a buyer would. See .wyn/docs/design/
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
      // DS-001 Section 4 rule #4 ("Commerce state ที่เป็นบวก") -- these
      // in-progress order states are ZOKY commerce state, so they use the
      // ZOKY sub-theme's tertiary (Orange) container, not primaryContainer
      // (Cyan) -- Cyan must never render as a visible accent in
      // seller_app (see wyn_zoky_theme.dart's header comment).
      OrderStatus.paid ||
      OrderStatus.sellerProcessing ||
      OrderStatus.readyToShip ||
      OrderStatus.shipped =>
        (colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer),
      OrderStatus.delivered => (Colors.green.shade100, Colors.green.shade800),
      OrderStatus.cancelled => (colorScheme.errorContainer, colorScheme.onErrorContainer),
    };
    final label = _labels[status]!;

    return Semantics(
      label: 'สถานะคำสั่งซื้อ: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[status], size: 14, color: foreground),
            const SizedBox(width: 4),
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
