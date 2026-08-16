import 'package:flutter/material.dart';

import '../../data/store.dart';
import '../../../../core/design/wyn_spacing.dart';

/// A Recommended Stores shortcut card for ZOKY Home's horizontal row --
/// mirrors ClubMiniCard (WYN-014)'s shape exactly, swapping member-count
/// for product-count.
class StoreMiniCard extends StatelessWidget {
  const StoreMiniCard({super.key, required this.store, required this.onTap});

  final Store store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${store.name} มีสินค้า ${store.productCount} ชิ้น กดเพื่อดูร้านค้า',
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
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage:
                      store.logoUrl != null ? NetworkImage(store.logoUrl!) : null,
                  child: store.logoUrl == null
                      ? Text(
                          store.name.isNotEmpty ? store.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: WynSpacing.space1),
                Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${store.productCount} สินค้า',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
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
