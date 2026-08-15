import 'package:flutter/material.dart';

import '../../data/order.dart';

/// Shared status pill for Order List/Detail (ZOKY-003) -- always
/// color+icon+text together, never color alone, per the Accessibility
/// rule in design-principles.md ("ไม่สื่อสารข้อมูลด้วยสีอย่างเดียว").
/// pending is neutral gray (it's a middle state, not success/error);
/// delivered/cancelled reuse the project's existing green=success/
/// red=error convention rather than inventing new status colors.
class OrderStatusBadge extends StatelessWidget {
  const OrderStatusBadge({super.key, required this.status});

  final OrderStatus status;

  static const _labels = {
    OrderStatus.pending: 'รอดำเนินการ',
    OrderStatus.delivered: 'ได้รับสินค้าแล้ว',
    OrderStatus.cancelled: 'ยกเลิกแล้ว',
  };

  static const _icons = {
    OrderStatus.pending: Icons.hourglass_empty,
    OrderStatus.delivered: Icons.check_circle,
    OrderStatus.cancelled: Icons.cancel,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      OrderStatus.pending => (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant),
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
