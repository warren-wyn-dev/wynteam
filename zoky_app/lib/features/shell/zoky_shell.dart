import 'package:flutter/material.dart';

import '../../app/app_dependencies.dart';
import '../../core/widgets/zoky_3d_icon.dart';
import '../../core/l10n/zoky_strings.dart';
import '../../core/widgets/zoky_bottom_nav.dart';
import '../../core/widgets/zoky_nav_icon.dart';
import '../account/account_screen.dart';
import '../home/home_screen.dart';
import '../messages/messages_screen.dart';
import '../orders/orders_screen.dart';

/// The four tabs of the web customer app, in the web's order
/// (wynos-food-developer-app.tsx nav items).
enum ZokyTab { home, orders, messages, account }

/// App shell: IndexedStack keeps each tab's state (parity A05) with the
/// shared bottom tab bar on top.
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
  final GlobalKey<HomeScreenState> _homeKey = GlobalKey<HomeScreenState>();

  void _select(ZokyTab tab) {
    if (tab == _tab) return;
    setState(() => _tab = tab);
  }

  /// Nav tap: re-tapping the selected หน้าหลัก scrolls it to the top.
  void _onNavTap(ZokyTab tab) {
    if (tab == _tab && tab == ZokyTab.home) {
      _homeKey.currentState?.scrollToTop();
      return;
    }
    _select(tab);
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
                HomeScreen(
                  key: _homeKey,
                  repository: deps.storeRepository,
                  promotionRepository: deps.promotionRepository,
                ),
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
                onSelected: (index) => _onNavTap(ZokyTab.values[index]),
                // Founder reference set (2026-10-17): rounded house with
                // door / clipboard / bubble with dots / person, gray
                // outline; selected = pink 3D filled. Switch the selected
                // glyph to ZokyNavSelectedGlyph.outlinePink if asked.
                iconStyle: ZokyNavIconStyle.rounded,
                selectedGlyph: ZokyNavSelectedGlyph.filled3d,
                // Exactly these four, in this order (Founder, Phase 5).
                items: const [
                  ZokyNavItem(
                    label: ZokyStrings.navHome,
                    glyph: Zoky3DGlyph.home,
                  ),
                  ZokyNavItem(
                    label: ZokyStrings.navOrders,
                    glyph: Zoky3DGlyph.receipt,
                  ),
                  ZokyNavItem(
                    label: ZokyStrings.navMessages,
                    glyph: Zoky3DGlyph.chat,
                  ),
                  ZokyNavItem(
                    label: ZokyStrings.navAccount,
                    glyph: Zoky3DGlyph.person,
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
