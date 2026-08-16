import 'package:flutter/material.dart';

import '../../../../core/text_utils.dart';
import '../../../order/data/order.dart';
import '../../../order/presentation/widgets/order_status_badge.dart';
import '../../../../core/design/wyn_spacing.dart';

/// One row in `SellerFinanceScreen`'s Transaction History -- mirrors
/// `SellerOrderListTile`'s shape (`Semantics`+`InkWell`+`Row`) but drops
/// the thumbnail/`order_items` query entirely: this row only needs
/// order-level totals (Requirements #4), and item detail is always one
/// tap away via `SellerOrderDetailScreen`. [order.status] must be
/// [OrderStatus.delivered] or [OrderStatus.refunded] -- the only 2
/// statuses `SellerRepository.fetchTransactionHistory` ever returns.
/// See .wyn/docs/design/seller-005-finance.md, Widget:
/// SellerTransactionTile.
class SellerTransactionTile extends StatelessWidget {
  const SellerTransactionTile({
    super.key,
    required this.order,
    required this.onTap,
  });

  final Order order;
  final VoidCallback onTap;

  bool get _isRefunded => order.status == OrderStatus.refunded;

  String get _shortId => order.id.length >= 8
      ? order.id.substring(0, 8).toUpperCase()
      : order.id.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    final net = order.subtotal; // net == subtotal, per Requirements #1.

    final semanticsLabel = _isRefunded
        ? 'ผู้ซื้อ ${order.recipientName}, คืนเงินแล้ว, ไม่นับรวมในยอดคงเหลือ'
        : 'ผู้ซื้อ ${order.recipientName}, ยอดสุทธิ ${thaiBahtLabel(net)} บาท, '
            'นับรวมในยอดคงเหลือ';

    return Semantics(
      label: semanticsLabel,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: WynSpacing.space4, vertical: 10),
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
              Text(
                '#$_shortId · ${relativeTimeLabel(order.createdAt, now: DateTime.now())}',
                style: bodySmall?.copyWith(color: colorScheme.outline),
              ),
              const SizedBox(height: WynSpacing.space1),
              _buildFormula(context, net),
              if (_isRefunded) ...[
                const SizedBox(height: 2),
                Text(
                  'คืนเงินแล้ว — ไม่นับรวมในยอดคงเหลือ',
                  style: bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormula(BuildContext context, double net) {
    final colorScheme = Theme.of(context).colorScheme;
    final bodySmall = Theme.of(context).textTheme.bodySmall;

    if (_isRefunded) {
      return Text(
        '${thaiBahtLabel(order.subtotal)} − ${thaiBahtLabel(order.feeAmount)} = '
        '${thaiBahtLabel(net)}',
        style: bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
          decoration: TextDecoration.lineThrough,
        ),
      );
    }

    return Text.rich(
      TextSpan(
        style: bodySmall,
        children: [
          TextSpan(text: '${thaiBahtLabel(order.subtotal)} − '),
          TextSpan(text: '${thaiBahtLabel(order.feeAmount)} = '),
          TextSpan(
            text: thaiBahtLabel(net),
            style: bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.tertiary,
            ),
          ),
        ],
      ),
    );
  }
}
