import 'package:flutter/material.dart';

import '../../dashboard/presentation/seller_dashboard_screen.dart';
import '../../store/data/seller_repository.dart';
import '../../store/data/store.dart';
import 'seller_coming_soon_screen.dart';

/// Bottom Nav 5 tab shell: Dashboard (fully built) / สินค้า / คำสั่งซื้อ
/// / ร้านค้า / การเงิน (placeholders until SELLER-002/003/004/005).
/// Mirrors `app/lib/features/root/presentation/root_shell.dart`'s
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

  @override
  Widget build(BuildContext context) {
    final tabs = [
      SellerDashboardScreen(
        store: widget.store,
        sellerRepository: widget.sellerRepository,
      ),
      const SellerComingSoonScreen(label: 'สินค้า'),
      const SellerComingSoonScreen(label: 'คำสั่งซื้อ'),
      const SellerComingSoonScreen(label: 'ร้านค้า'),
      const SellerComingSoonScreen(label: 'การเงิน'),
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
