import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_app/core/adaptive/zoky_icons.dart';
import 'package:zoky_app/core/l10n/zoky_strings.dart';
import 'package:zoky_app/core/widgets/zoky_bottom_nav.dart';
import 'package:zoky_app/core/widgets/zoky_button.dart';
import 'package:zoky_app/core/widgets/zoky_cart_bar.dart';
import 'package:zoky_app/core/widgets/zoky_chip.dart';
import 'package:zoky_app/core/widgets/zoky_logo.dart';
import 'package:zoky_app/core/widgets/zoky_menu_item_card.dart';
import 'package:zoky_app/core/widgets/zoky_nav_icon.dart';
import 'package:zoky_app/core/widgets/zoky_page_header.dart';
import 'package:zoky_app/core/widgets/zoky_skeleton.dart';
import 'package:zoky_app/core/widgets/zoky_state_view.dart';
import 'package:zoky_app/core/widgets/zoky_store_card.dart';
import 'package:zoky_app/features/catalog/data/demo_store_repository.dart';
import 'package:zoky_app/features/catalog/domain/catalog_models.dart';
import 'package:zoky_app/features/search/store_search_screen.dart';

import 'support/pump_zoky.dart';

// Worst-case synthetic data: long Thai names, every overlay at once.
const _busyStore = ZokyStoreSummary(
  id: 's1',
  name: 'ร้านข้าวมันไก่และก๋วยเตี๋ยวต้มยำสูตรโบราณเจ้าเก่าแก่ที่สุดในตัวเมือง',
  isOpen: false,
  deliveryFee: 1250,
  etaMinMinutes: 120,
  etaMaxMinutes: 180,
  isAd: true,
  promoLabel: 'ลด 20% เมื่อสั่งครบ ฿300',
  ratingAverage: 4.85,
  ratingCount: 123456,
  distanceKm: 12.34,
  categories: ['อาหารตามสั่งและเครื่องดื่ม', 'ของหวานนานาชาติ', 'เกิน'],
);

const _newStore = ZokyStoreSummary(
  id: 's2',
  name: 'ร้านเปิดใหม่ตัวอย่าง',
  isOpen: true,
  deliveryFee: 0,
  etaMinMinutes: 15,
  etaMaxMinutes: 25,
);

const _items = [
  ZokyMenuItem(
    id: 'm1',
    storeId: 's1',
    category: 'a',
    name: 'ข้าวมันไก่ต้มพิเศษเพิ่มเครื่องในและไข่ต้มยางมะตูมสองฟองพร้อมซุป',
    description:
        'คำอธิบายยาวมากเพื่อทดสอบการตัดบรรทัดของรายการเมนูในหน้าร้าน '
        'ว่าไม่ล้นจอที่ความกว้าง 360 และขนาดตัวอักษร 1.3 เท่า',
    price: 1234.5,
    remainingStock: 3,
  ),
  ZokyMenuItem(
    id: 'm2',
    storeId: 's1',
    category: 'a',
    name: 'ซุปฟัก',
    price: 20,
    isAvailable: false,
  ),
  ZokyMenuItem(
    id: 'm3',
    storeId: 's1',
    category: 'a',
    name: 'น้ำเปล่า',
    price: 10,
  ),
];

void main() {
  for (final width in [360.0, 430.0]) {
    group('width $width, text scale 1.3', () {
      Future<void> pump(WidgetTester tester, Widget child) =>
          pumpZokyWidget(tester, child, width: width, textScale: 1.3);

      testWidgets('buttons (all variants, loading, expanded)', (tester) async {
        await pump(
          tester,
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final variant in ZokyButtonVariant.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ZokyButton(
                      label: 'ใส่ตะกร้า • ฿1,250 สำหรับทดสอบปุ่มยาว',
                      variant: variant,
                      icon: ZokyIcons.cart,
                      onPressed: () {},
                    ),
                  ),
                ZokyButton.primary(
                  label: 'ยืนยัน',
                  onPressed: () {},
                  loading: true,
                ),
                const ZokyButton.primary(label: 'ปิดใช้งาน', onPressed: null),
                ZokyButton.primary(
                  label: 'สั่งอาหาร',
                  onPressed: () {},
                  expand: true,
                  size: ZokyButtonSize.lg,
                ),
              ],
            ),
          ),
        );
        expect(find.byType(ZokyButton), findsNWidgets(9));
        expect(tester.takeException(), isNull);
      });

      testWidgets('chips', (tester) async {
        await pump(
          tester,
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              children: [
                ZokyChip(
                  label: ZokyStrings.filterAll,
                  selected: true,
                  onSelected: () {},
                ),
                ZokyChip(
                  label: ZokyStrings.filterRating,
                  selected: true,
                  selectedStyle: ZokyChipSelectedStyle.soft,
                  onSelected: () {},
                ),
                ZokyChip(
                  label: 'ตัวกรองที่ยาวมากเกินความกว้างของหน้าจอโทรศัพท์แน่นอน',
                  selected: false,
                  onSelected: () {},
                ),
              ],
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('store cards in the 2-column grid', (tester) async {
        await pump(
          tester,
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ZokyStoreCard(store: _busyStore, onTap: () {}),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ZokyStoreCard(store: _newStore, onTap: () {}),
                ),
              ],
            ),
          ),
        );
        expect(find.text(ZokyStrings.adLabel), findsOneWidget);
        expect(find.text(ZokyStrings.closedLabel), findsOneWidget);
        expect(find.text(ZokyStrings.newStore), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('menu item cards (normal, sold out, low stock)', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pump(
          tester,
          ListView(
            children: [
              for (final item in _items)
                ZokyMenuItemCard(item: item, onTap: () {}, onAdd: () {}),
            ],
          ),
        );
        // Sold-out row has no add button.
        expect(find.bySemanticsLabel('เพิ่ม ซุปฟัก ลงตะกร้า'), findsNothing);
        expect(
          find.bySemanticsLabel('เพิ่ม น้ำเปล่า ลงตะกร้า'),
          findsOneWidget,
        );
        expect(find.text(ZokyStrings.soldOut), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });

      testWidgets('cart bar with a large count and total', (tester) async {
        await pump(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ZokyCartBar(itemCount: 128, total: 123456.5, onTap: () {}),
            ),
          ),
        );
        expect(find.text('99+'), findsOneWidget);
        expect(find.text('฿123,456.50'), findsOneWidget);
        expect(find.text(ZokyStrings.viewCart), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('bottom nav with badge', (tester) async {
        await pump(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: ZokyBottomNav(
              currentIndex: 1,
              onSelected: (_) {},
              items: const [
                ZokyNavItem(
                  label: ZokyStrings.navHome,
                  glyph: ZokyNavGlyph.home,
                ),
                ZokyNavItem(
                  label: ZokyStrings.navOrders,
                  glyph: ZokyNavGlyph.orders,
                  badgeCount: 128,
                  badgeSemanticLabel: '128 ออเดอร์ที่กำลังดำเนินการ',
                ),
                ZokyNavItem(
                  label: ZokyStrings.navMessages,
                  glyph: ZokyNavGlyph.messages,
                ),
                ZokyNavItem(
                  label: ZokyStrings.navAccount,
                  glyph: ZokyNavGlyph.account,
                ),
              ],
            ),
          ),
        );
        expect(find.text('99+'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('empty / error states, header, logo', (tester) async {
        await pump(
          tester,
          ListView(
            children: [
              const ZokyPageHeader(title: ZokyStrings.ordersPageTitle),
              const ZokyStateView.empty(
                icon: ZokyIcons.store,
                title: ZokyStrings.noStoresTitle,
                messages: [ZokyStrings.noStoresBody],
              ),
              ZokyStateView.error(
                title: ZokyStrings.loadErrorTitle,
                messages: const [ZokyStrings.offlineBody],
                onAction: () {},
              ),
              const Center(child: ZokyLogo(size: 56)),
            ],
          ),
        );
        expect(find.text(ZokyStrings.retry), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('skeletons', (tester) async {
        await pump(
          tester,
          ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              ZokySkeleton(height: 48),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: ZokyStoreCardSkeleton()),
                  SizedBox(width: 12),
                  Expanded(child: ZokyStoreCardSkeleton()),
                ],
              ),
            ],
          ),
        );
        // Shimmer repeats forever: advance a frame instead of settling.
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
      });

      testWidgets('whole app: every tab and a store page', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpZokyApp(tester, width: width, textScale: 1.3);
        expect(tester.takeException(), isNull);
        for (final label in [
          ZokyStrings.navOrders,
          ZokyStrings.navMessages,
          ZokyStrings.navAccount,
          ZokyStrings.navHome,
        ]) {
          await tester.tap(
            find.descendant(
              of: find.byType(ZokyBottomNav),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        // The all-stores list (store grid) and a store page.
        await pumpZokyWidget(
          tester,
          StoreSearchScreen(
            repository: DemoStoreRepository(),
            title: ZokyStrings.allStoresTitle,
            autofocus: false,
          ),
          width: width,
          textScale: 1.3,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(ZokyStoreCard).first);
        await tester.pumpAndSettle();
        await tester.tap(
          find.bySemanticsLabel(RegExp(r'^เพิ่ม .* ลงตะกร้า$')).first,
        );
        await tester.pumpAndSettle();
        expect(find.byType(ZokyCartBar), findsOneWidget);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    });
  }

  group('large text (scale 1.5)', () {
    testWidgets('cart bar drops the "ดูตะกร้า" label', (tester) async {
      await pumpZokyWidget(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: ZokyCartBar(itemCount: 2, total: 120, onTap: () {}),
        ),
        width: 360,
        textScale: 1.5,
      );
      expect(find.text(ZokyStrings.viewCart), findsNothing);
      expect(find.text('฿120'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('store grid becomes one column', (tester) async {
      await pumpZokyWidget(
        tester,
        StoreSearchScreen(
          repository: DemoStoreRepository(),
          title: ZokyStrings.allStoresTitle,
          autofocus: false,
        ),
        width: 360,
        textScale: 1.5,
      );
      await tester.pumpAndSettle();
      final cards = find.byType(ZokyStoreCard);
      expect(cards, findsWidgets);
      final first = tester.getRect(cards.at(0));
      expect(first.width, greaterThan(300));
      expect(tester.takeException(), isNull);
    });
  });
}
