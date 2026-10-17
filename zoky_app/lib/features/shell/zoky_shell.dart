import 'package:flutter/material.dart';

import '../../app/app_dependencies.dart';
import '../../core/adaptive/zoky_icons.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_bottom_nav.dart';
import '../account/account_screen.dart';
import '../home/home_screen.dart';
import '../messages/messages_screen.dart';
import '../orders/orders_screen.dart';

/// The four tabs of the web customer app, in the web's order
/// (wynos-food-developer-app.tsx nav items).
enum ZokyTab { home, orders, messages, account }

/// App shell: IndexedStack keeps each tab's state (parity A05) with the
/// shared floating bottom nav on top.
///
/// Android/system back from any other tab returns to หน้าหลัก first; back on
/// หน้าหลัก leaves the app (A05).
class ZokyShell extends StatefulWidget {
  const ZokyShell({super.key});

  @override
  State<ZokyShell> createState() => _ZokyShellState();
}

class _ZokyShellState extends State<ZokyShell> {
  ZokyTab _tab = ZokyTab.home;

  void _select(ZokyTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependencies.of(context);
    return PopScope(
      canPop: _tab == ZokyTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(ZokyTab.home);
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: _tab.index,
              children: [
                HomeScreen(repository: deps.storeRepository),
                OrdersScreen(onBrowse: () => _select(ZokyTab.home)),
                const MessagesScreen(),
                AccountScreen(onOrderHistory: () => _select(ZokyTab.orders)),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ZokyBottomNav(
                currentIndex: _tab.index,
                onSelected: (index) => _select(ZokyTab.values[index]),
                items: const [
                  ZokyNavItem(
                    label: ZokyStrings.navHome,
                    icon: ZokyIcons.home,
                    activeIcon: ZokyIcons.homeActive,
                  ),
                  ZokyNavItem(
                    label: ZokyStrings.navOrders,
                    icon: ZokyIcons.orders,
                    activeIcon: ZokyIcons.orders,
                  ),
                  ZokyNavItem(
                    label: ZokyStrings.navMessages,
                    icon: ZokyIcons.messages,
                    activeIcon: ZokyIcons.messages,
                  ),
                  ZokyNavItem(
                    label: ZokyStrings.navAccount,
                    icon: ZokyIcons.account,
                    activeIcon: ZokyIcons.account,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
