import 'package:flutter/material.dart';

import '../../../../core/text_utils.dart';
import '../../data/product.dart';
import '../../../../core/design/wyn_spacing.dart';

/// A New Products shortcut card for ZOKY Home's horizontal row --
/// mirrors ClubMiniCard (WYN-014)'s shape exactly, swapping icon+name+
/// member-count for image+name+price.
class ProductMiniCard extends StatelessWidget {
  const ProductMiniCard({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${product.name} ราคา ${thaiBahtLabel(product.price)} กดเพื่อดูสินค้า',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
        child: SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space1, vertical: WynSpacing.space2),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(WynSpacing.radiusSm),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(product.imageUrls.first, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: WynSpacing.space1),
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  thaiBahtLabel(product.price),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.tertiary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
