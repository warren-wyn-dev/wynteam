import 'package:flutter/material.dart';

import '../../../../core/design/wyn_colors.dart';
import '../../../../core/text_utils.dart';
import '../../data/product.dart';

/// One square tile in ZOKY Home's main product grid -- mirrors
/// PopGridTile/DropGridTile's "media area + overlay badge" shape
/// (WYN-013), swapping the duration badge for a price badge since a
/// Product's price must always be visible, unlike a Pop's duration
/// which is secondary information.
class ProductGridTile extends StatelessWidget {
  const ProductGridTile({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${product.name} ราคา ${thaiBahtLabel(product.price)}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 1,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(product.imageUrls.first, fit: BoxFit.cover),
              Positioned(
                left: 4,
                bottom: 4,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: WynColors.imageScrim,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      thaiBahtLabel(product.price),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
