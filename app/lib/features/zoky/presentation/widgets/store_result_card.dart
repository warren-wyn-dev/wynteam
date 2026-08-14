import 'package:flutter/material.dart';

import '../../data/store.dart';

/// A full-width Store row for ZOKY-002's search results -- logo + name
/// + product count + short description, mirroring ClubDiscoveryCard
/// (WYN-015)'s shape. Unlike StoreMiniCard (a narrow horizontal-scroll
/// card used in ZOKY Home), this is meant for a vertical results list
/// where there's room to show the description too.
class StoreResultCard extends StatelessWidget {
  const StoreResultCard({super.key, required this.store, required this.onTap});

  final Store store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${store.name}, มีสินค้า ${store.productCount} ชิ้น',
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '${store.productCount} สินค้า',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    if (store.description != null && store.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        store.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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
