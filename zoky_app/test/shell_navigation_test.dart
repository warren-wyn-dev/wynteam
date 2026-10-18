import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_cart_bar.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/home/widgets/zoky_home_header.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';
import 'package:zoky_app/features/store/store_screen.dart';

import 'support/pump_zoky.dart';

Finder _navItem(String label) =>
    find.descendant(of: find.byType(ZokyBottomNav), matching: find.text(label));

void main() {
  testWidgets('shows the four web nav destinations in web order', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    final labels = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ZokyBottomNav),
            matching: find.byType(Text),
          ),
        )
        .map((text) => text.data)
        .toList();
    expect(labels, [
      ZokyStrings.navHome,
      ZokyStrings.navOrders,
      ZokyStrings.navMessages,
      ZokyStrings.navAccount,
    ]);
  });

  testWidgets('home shows the Home v2 header, not the legacy body', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    expect(find.byType(ZokyHomeHeader), findsOneWidget);
    expect(find.text(ZokyStrings.nearbyStores), findsNothing);
    expect(find.byType(ZokyStoreCard), findsNothing);
  });

  testWidgets('tapping each tab shows its screen', (tester) async {
    await pumpZokyApp(tester);

    await tester.tap(_navItem(ZokyStrings.navOrders));
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.ordersPageTitle), findsOneWidget);
    expect(find.text(ZokyStrings.noOrdersTitle), findsOneWidget);

    await tester.tap(_navItem(ZokyStrings.navMessages));
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.noMessagesTitle), findsOneWidget);
    expect(find.text(ZokyStrings.noMessagesBody2), findsOneWidget);

    await tester.tap(_navItem(ZokyStrings.navAccount));
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.profileSetupPrompt), findsOneWidget);
    expect(find.text(ZokyStrings.demoModeTitle), findsOneWidget);

    await tester.tap(_navItem(ZokyStrings.navHome));
    await tester.pumpAndSettle();
    expect(find.byType(ZokyHomeHeader), findsOneWidget);
  });

  testWidgets('selected tab is exposed to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpZokyApp(tester);
    await tester.tap(_navItem(ZokyStrings.navOrders));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(ZokyBottomNav),
          matching: find.bySemanticsLabel(ZokyStrings.navOrders),
        ),
      ),
      isSemantics(isButton: true, isSelected: true),
    );
    handle.dispose();
  });

  testWidgets('system back from another tab returns to หน้าหลัก first', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    await tester.tap(_navItem(ZokyStrings.navAccount));
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.profileSetupPrompt), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.profileSetupPrompt), findsNothing);
    expect(find.byType(ZokyHomeHeader), findsOneWidget);
  });

  testWidgets('"สั่งอาหารเลย" on empty orders goes back to หน้าหลัก', (
    tester,
  ) async {
    await pumpZokyApp(tester);
    await tester.tap(_navItem(ZokyStrings.navOrders));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ZokyStrings.orderNow));
    await tester.pumpAndSettle();
    expect(find.text(ZokyStrings.noOrdersTitle), findsNothing);
    expect(find.byType(ZokyHomeHeader), findsOneWidget);
  });

  testWidgets('store card opens the store; adding an item shows the cart bar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpZokyWidget(
      tester,
      StoreSearchScreen(
        repository: DemoStoreRepository(),
        title: ZokyStrings.allStoresTitle,
        autofocus: false,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ZokyStoreCard).first);
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen), findsOneWidget);
    expect(find.byType(ZokyCartBar), findsNothing);

    await tester.tap(
      find.bySemanticsLabel(RegExp(r'^เพิ่ม .* ลงตะกร้า$')).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(ZokyCartBar), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ZokyCartBar), matching: find.text('1')),
      findsOneWidget,
    );

    // Back to the store list.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(StoreScreen), findsNothing);
    expect(find.text(ZokyStrings.allStoresTitle), findsOneWidget);
    semantics.dispose();
  });
}
