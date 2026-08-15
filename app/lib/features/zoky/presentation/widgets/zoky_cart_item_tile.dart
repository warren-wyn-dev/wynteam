import 'package:flutter/material.dart';

import '../../../../core/text_utils.dart';
import '../../data/cart_item.dart';
import 'quantity_stepper.dart';

/// A single row in ZokyCartScreen -- thumbnail + name + variant
/// snapshot + price + quantity stepper + remove button. New shape, no
/// existing card fits it: ProductMiniCard is a narrow vertical card
/// meant for a horizontal-scroll row, not a full-width list row that
/// also needs interactive controls.
class ZokyCartItemTile extends StatelessWidget {
  const ZokyCartItemTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onTap;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: product.name,
            button: true,
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: Image.network(product.imageUrls.first, fit: BoxFit.cover),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: onTap,
                  child: Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (item.variantSelection.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.variantSelection,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  thaiBahtLabel(product.price),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    QuantityStepper(
                      quantity: item.quantity,
                      max: product.stock,
                      onChanged: onQuantityChanged,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'ลบออกจากตะกร้า',
                      onPressed: onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
