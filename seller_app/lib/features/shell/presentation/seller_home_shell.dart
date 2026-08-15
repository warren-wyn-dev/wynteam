import 'package:flutter/material.dart';

import '../../dashboard/presentation/seller_dashboard_screen.dart';
import '../../finance/presentation/seller_finance_screen.dart';
import '../../order/presentation/seller_order_list_screen.dart';
import '../../product/presentation/seller_product_list_screen.dart';
import '../../store/data/seller_repository.dart';
import '../../store/data/store.dart';
import '../../store/presentation/seller_store_screen.dart';

/// Bottom Nav 5 tab shell: Dashboard / สินค้า / คำสั่งซื้อ / ร้านค้า /
/// การเงิน -- every tab is now fully built (SELLER-005 replaced the last
/// placeholder, `SellerComingSoonScreen(label: 'การเงิน')`). Mirrors
/// `app/lib/features/root/presentation/root_shell.dart`'s
/// `IndexedStack` pattern -- every tab's State stays alive across
/// switches. See .wyn/docs/design/seller-001-foundation.md, Screen:
/// SellerHomeShell.
class SellerHomeShell extends StatefulWidget {
  const SellerHomeShell({
    super.key,
    required this.store,
    required this.sellerRepository,
  });

  final Store store;
  final SellerRepository sellerRepository;

  @override
  State<SellerHomeShell> createState() => _SellerHomeShellState();
}

class _SellerHomeShellState extends State<SellerHomeShell> {
  int _index = 0;

  /// Mutable so SellerStoreScreen's `onStoreUpdated` callback can make
  /// every tab below see the freshest store row within the same session,
  /// without a sign-out/sign-in round-trip or a re-fetch (the save
  /// response already carries the latest row). See .wyn/tasks/backlog/
  /// SELLER-004-store-management.md, Requirements #3.
  late Store _store = widget.store;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      SellerDashboardScreen(
        store: _store,
        sellerRepository: widget.sellerRepository,
      ),
      SellerProductListScreen(
        store: _store,
        sellerRepository: widget.sellerRepository,
      ),
      SellerOrderListScreen(
        store: _store,
        sellerRepository: widget.sellerRepository,
      ),
      SellerStoreScreen(
        store: _store,
        sellerRepository: widget.sellerRepository,
        onStoreUpdated: (updated) => setState(() => _store = updated),
      ),
      SellerFinanceScreen(
        store: _store,
        sellerRepository: widget.sellerRepository,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'สินค้า',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'คำสั่งซื้อ',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'ร้านค้า',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'การเงิน',
          ),
        ],
      ),
    );
  }
}
