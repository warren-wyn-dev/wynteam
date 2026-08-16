import 'package:flutter/material.dart';

import '../../../../core/text_utils.dart';
import '../../data/order.dart';
import '../../data/order_item.dart';
import 'order_status_badge.dart';
import '../../../../core/design/wyn_spacing.dart';

/// One row in `SellerOrderListScreen` -- mirrors `OrderSummaryCard`
/// (ZOKY-003)'s shape (leading thumbnail + text column + trailing
/// status badge) exactly, swapping the top row's store name for the
/// buyer's recipient name -- a seller already knows it's their own
/// store, so the name that actually discriminates one row from another
/// is who bought it. See .wyn/docs/design/seller-003-order-management.md,
/// Widget: SellerOrderListTile.
class SellerOrderListTile extends StatelessWidget {
  const SellerOrderListTile({
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
      label: 'ผู้ซื้อ ${order.recipientName}, ยอดรวม ${thaiBahtLabel(order.total)}',
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
                          child: Text(
                            'ผู้ซื้อ: ${order.recipientName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
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
                            color: Theme.of(context).colorScheme.tertiary,
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
