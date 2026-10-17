import 'package:flutter/material.dart';

import '../../core/adaptive/zoky_icons.dart';
import '../../core/design/zoky_tokens.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_bottom_nav.dart';
import '../../core/widgets/zoky_chip.dart';
import '../../core/widgets/zoky_page_header.dart';
import '../../core/widgets/zoky_state_view.dart';

/// ออเดอร์ tab placeholder (web OrdersPanel): active/history segment and the
/// empty state. Order list, realtime, tracking and payment arrive in
/// ZOKY-108/109 (parity G, H).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, required this.onBrowse});

  /// "สั่งอาหารเลย" -> back to หน้าหลัก.
  final VoidCallback onBrowse;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _history = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.only(bottom: ZokyBottomNav.reservedHeight(context)),
        children: [
          const ZokyPageHeader(title: ZokyStrings.ordersPageTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZokySpacing.gutter),
            child: Wrap(
              spacing: ZokySpacing.s4,
              children: [
                ZokyChip(
                  label: ZokyStrings.ordersActive,
                  selected: !_history,
                  onSelected: () => setState(() => _history = false),
                ),
                ZokyChip(
                  label: ZokyStrings.ordersHistory,
                  selected: _history,
                  onSelected: () => setState(() => _history = true),
                ),
              ],
            ),
          ),
          ZokyStateView.empty(
            icon: ZokyIcons.orders,
            title: _history
                ? ZokyStrings.noHistoryTitle
                : ZokyStrings.noOrdersTitle,
            messages: [
              _history ? ZokyStrings.noHistoryBody : ZokyStrings.noOrdersBody,
            ],
            actionLabel: ZokyStrings.orderNow,
            onAction: widget.onBrowse,
          ),
        ],
      ),
    );
  }
}
