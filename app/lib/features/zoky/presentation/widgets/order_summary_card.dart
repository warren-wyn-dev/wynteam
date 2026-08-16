import 'package:flutter/material.dart';

import '../../../../core/text_utils.dart';
import '../../data/order.dart';
import '../../data/order_item.dart';
import 'order_status_badge.dart';
import '../../../../core/design/wyn_spacing.dart';

/// A full-width Order row for ZokyOrderListScreen -- mirrors
/// StoreResultCard (ZOKY-002)'s shape (leading thumbnail + text column
/// + trailing marker), swapping store-info for order summary + status
/// badge in the top-right corner.
class OrderSummaryCard extends StatelessWidget {
  const OrderSummaryCard({
    super.key,
    required this.order,
    required this.items,
    required this.onTap,
  });

  final Order order;
  final List<OrderItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final firstItem = items.isNotEmpty ? items.first : null;
    final extraCount = items.length - 1;

    return Semantics(
      label: '${order.storeName}, ยอดรวม ${thaiBahtLabel(order.total)}',
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
                  child: firstItem?.imageUrl != null
                      ? Image.network(firstItem!.imageUrl!, fit: BoxFit.cover)
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
                          child: Text(order.storeName, style: Theme.of(context).textTheme.titleSmall),
                        ),
                        OrderStatusBadge(status: order.status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (extraCount > 0)
                      Text(
                        '${firstItem?.productName ?? ''} และอีก $extraCount ชิ้น',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else if (firstItem != null)
                      Text(
                        firstItem.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: WynSpacing.space1),
                    Text(
                      relativeTimeLabel(order.createdAt, now: DateTime.now()),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      thaiBahtLabel(order.total),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
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
