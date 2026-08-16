import 'package:flutter/material.dart';

import '../../../../core/text_utils.dart';
import '../../data/product.dart';
import 'product_active_badge.dart';
import '../../../../core/design/wyn_spacing.dart';

/// One row in `SellerProductListScreen` -- mirrors `OrderSummaryCard`
/// (ZOKY-003)'s shape (leading thumbnail + text column + trailing
/// marker). See .wyn/docs/design/seller-002-product-management.md,
/// Widget: SellerProductListTile.
class SellerProductListTile extends StatelessWidget {
  const SellerProductListTile({
    super.key,
    required this.product,
    required this.onTap,
  });

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusLabel = product.isActive ? 'กำลังขาย' : 'ปิดการขาย';
    final stockLabel = product.stock == 0 ? 'หมด' : 'เหลือ ${product.stock} ชิ้น';

    return Semantics(
      label:
          '${product.name}, ${thaiBahtLabel(product.price)} บาท, สถานะ$statusLabel, $stockLabel',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: product.imageUrls.isNotEmpty
                      ? Image.network(product.imageUrls.first, fit: BoxFit.cover)
                      : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                ),
              ),
              const SizedBox(width: WynSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        ProductActiveBadge(isActive: product.isActive),
                      ],
                    ),
                    const SizedBox(height: WynSpacing.space1),
                    Row(
                      children: [
                        Text(
                          thaiBahtLabel(product.price),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.tertiary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        if (product.hasDiscount) ...[
                          const SizedBox(width: 6),
                          Text(
                            thaiBahtLabel(product.originalPrice!),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stockLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: product.stock == 0
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.outline,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
