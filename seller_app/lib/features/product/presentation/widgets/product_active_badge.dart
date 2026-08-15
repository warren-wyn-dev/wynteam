import 'package:flutter/material.dart';

/// Status pill for a product's `is_active` flag -- always color+icon+
/// text together, mirroring `OrderStatusBadge` (ZOKY-003)'s
/// accessibility principle ("ไม่สื่อสารข้อมูลด้วยสีอย่างเดียว").
/// Deliberately always exactly 2 states, never tied to `stock == 0` --
/// active and out-of-stock are different dimensions (an active product
/// can be sold out, an inactive one is hidden regardless of stock). See
/// .wyn/docs/design/seller-002-product-management.md, Widget:
/// ProductActiveBadge.
class ProductActiveBadge extends StatelessWidget {
  const ProductActiveBadge({super.key, required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = isActive
        ? (Colors.green.shade100, Colors.green.shade800)
        : (colorScheme.surfaceContainerHighest, colorScheme.onSurfaceVariant);
    final label = isActive ? 'กำลังขาย' : 'ปิดการขาย';
    final icon = isActive ? Icons.check_circle : Icons.visibility_off;

    return Semantics(
      label: 'สถานะสินค้า: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
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
