import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/core/design/wyn_theme.dart';
import 'package:wyn/features/zoky/data/cart_item.dart';
import 'package:wyn/features/zoky/data/order.dart';
import 'package:wyn/features/zoky/data/order_item.dart';
import 'package:wyn/features/zoky/data/product.dart';
import 'package:wyn/features/zoky/presentation/product_detail_screen.dart';
import 'package:wyn/features/zoky/presentation/widgets/product_grid_tile.dart';
import 'package:wyn/features/zoky/presentation/widgets/zoky_theme_scope.dart';
import 'package:wyn/features/zoky/presentation/zoky_cart_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_checkout_summary_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_home_screen.dart';
import 'package:wyn/features/zoky/presentation/zoky_order_detail_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_zoky_repository.dart';

/// Permanent regression tests for DS-001c (BUG-1) -- see
/// .wyn/tasks/bugs/DS-001c-zoky-price-color-not-orange-in-app.md.
///
/// Every screen below is pumped under `app/`'s *real* theme wiring
/// (`WynTheme.light`/`WynTheme.dark`, matching `app/lib/main.dart`'s
/// `theme:`/`darkTheme:`), not a bare `MaterialApp()` default theme --
/// the bug only reproduces under `WynTheme`'s `socialLightScheme`/
/// `socialDarkScheme`, where `tertiary == cyan500`. A bare default
/// `ThemeData()` would never have caught this bug, since its own default
/// `tertiary` isn't Cyan or Orange either.
///
/// Every assertion below checks the *resolved* `Color` of the price
/// `Text` equals `WynColors.orange500` AND is not `WynColors.cyan500` --
/// a test that only checked "some color is applied" would not have
/// caught this bug (the pre-DS-001c `colorScheme.primary` also "applied
/// a color", just the wrong one).
///
/// Testing gotcha found while writing this file: constructing a
/// `RecordingZokyRepository` (which builds a real `SupabaseClient` ->
/// `GoTrueClient`, which auto-starts a periodic 10s auth-refresh
/// `Timer`) *inside* a `testWidgets` callback body trips
/// `flutter_test`'s `!timersPending` invariant at the end of that test,
/// because the `Timer` gets created inside that test's own `FakeAsync`
/// zone. Constructing it inside `setUp()` instead (this codebase's
/// existing convention in every other `*_test.dart` file under
/// `app/lib/features/zoky/`) avoids this -- `setUp()` runs outside the
/// `testWidgets` body's `FakeAsync` zone, so the `Timer` it creates is
/// invisible to that per-test check (same reason `setUpAll`'s
/// `initFakeSupabaseSession()` global client never trips it either).
void main() {
  setUpAll(() async {
    await initFakeSupabaseSession();
  });

  Color? textColor(WidgetTester tester, Finder finder) =>
      tester.widget<Text>(finder).style?.color;

  // ProductDetailScreen's image carousel (AspectRatio 1, ~800px wide in
  // this test viewport) pushes the price row out of the lazily-built
  // sliver range -- see .wyn/learning/PATTERNS.md and
  // product_detail_screen_test.dart's own scrollToFind for the same
  // technique.
  Future<void> scrollToFind(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
        finder,
        500,
        scrollable: find.byType(Scrollable).first,
      );

  Product product({
    String id = 'p1',
    double price = 199,
    String name = 'เสื้อยืด',
  }) =>
      Product(
        id: id,
        storeId: 'store-1',
        storeName: 'ร้านทดสอบ',
        name: name,
        price: price,
        stock: 10,
        imageUrls: const ['https://example.supabase.co/products/p1.jpg'],
        createdAt: DateTime.now(),
      );

  group('ZokyThemeScope', () {
    testWidgets('resolves colorScheme.tertiary to orange500, not cyan500 (light)',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        theme: WynTheme.light,
        home: ZokyThemeScope(
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ));

      final tertiary = Theme.of(captured).colorScheme.tertiary;
      expect(tertiary, WynColors.orange500);
      expect(tertiary, isNot(WynColors.cyan500));
    });

    testWidgets('resolves colorScheme.tertiary to orange500, not cyan500 (dark)',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        theme: WynTheme.dark,
        home: ZokyThemeScope(
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ));

      final tertiary = Theme.of(captured).colorScheme.tertiary;
      expect(tertiary, WynColors.orange500);
      expect(tertiary, isNot(WynColors.cyan500));
    });

    testWidgets('leaves primary (WYN Social Cyan) untouched -- only the tertiary '
        'family changes', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(MaterialApp(
        theme: WynTheme.light,
        home: ZokyThemeScope(
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox();
            },
          ),
        ),
      ));

      expect(Theme.of(captured).colorScheme.primary, WynColors.cyan500);
    });
  });

  for (final mode in [(name: 'light', theme: WynTheme.light), (name: 'dark', theme: WynTheme.dark)]) {
    group('ProductMiniCard price in ZokyHomeScreen (${mode.name})', () {
      late RecordingZokyRepository repo;

      setUp(() {
        repo = RecordingZokyRepository(newProducts: [product(price: 199)]);
      });

      testWidgets('resolves to orange500, not cyan500', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: mode.theme,
          home: ZokyHomeScreen(zokyRepository: repo),
        ));
        await tester.pumpAndSettle();
        tester.takeException();

        final color = textColor(tester, find.text('฿199'));
        expect(color, WynColors.orange500);
        expect(color, isNot(WynColors.cyan500));
      });
    });

    group('ProductDetailScreen price (${mode.name})', () {
      late RecordingZokyRepository repo;

      setUp(() {
        repo = RecordingZokyRepository();
      });

      testWidgets('resolves to orange500, not cyan500', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: mode.theme,
          home: ProductDetailScreen(zokyRepository: repo, product: product(price: 321)),
        ));
        await tester.pumpAndSettle();
        tester.takeException();
        await scrollToFind(tester, find.text('฿321'));
        tester.takeException();

        final color = textColor(tester, find.text('฿321'));
        expect(color, WynColors.orange500);
        expect(color, isNot(WynColors.cyan500));
      });
    });

    group('ZokyCartItemTile price in ZokyCartScreen (${mode.name})', () {
      late RecordingZokyRepository repo;

      setUp(() {
        // Quantity 2 so the tile's unit price (125) and the bottom
        // bar's line total (250) are different displayed values --
        // avoids an ambiguous find.text('฿125') match against another
        // Text showing the same number with a different (correct,
        // colorScheme.primary) color.
        repo = RecordingZokyRepository(cartItems: [
          CartItem(id: 'ci1', product: product(price: 125), variantSelection: '', quantity: 2),
        ]);
      });

      testWidgets('resolves to orange500, not cyan500', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: mode.theme,
          home: ZokyCartScreen(zokyRepository: repo),
        ));
        await tester.pumpAndSettle();
        tester.takeException();

        final color = textColor(tester, find.text('฿125'));
        expect(color, WynColors.orange500);
        expect(color, isNot(WynColors.cyan500));
      });
    });

    group('ZokyCheckoutSummaryScreen line price (${mode.name})', () {
      late RecordingZokyRepository repo;
      late List<CartItem> items;

      setUp(() {
        repo = RecordingZokyRepository(marketplaceFeePercent: 10);
        // Two items in the same store so each item's own lineTotal
        // (300, 150) differs from the store's subtotal (450) -- with
        // only one item, subtotal == that item's lineTotal, which would
        // make find.text ambiguous between the tertiary-colored line
        // price and the non-tertiary "ค่าสินค้า" summary row showing
        // the same number.
        items = [
          CartItem(id: 'ci1', product: product(id: 'p1', price: 300), variantSelection: '', quantity: 1),
          CartItem(
            id: 'ci2',
            product: product(id: 'p2', price: 150, name: 'กางเกงยีนส์'),
            variantSelection: '',
            quantity: 1,
          ),
        ];
      });

      testWidgets('resolves to orange500, not cyan500', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: mode.theme,
          home: ZokyCheckoutSummaryScreen(
            zokyRepository: repo,
            cartItems: items,
            recipientName: 'สมชาย ใจดี',
            recipientPhone: '0812345678',
            shippingAddress: '123 ถนนทดสอบ',
          ),
        ));
        await tester.pumpAndSettle();
        tester.takeException();

        final firstColor = textColor(tester, find.text('฿300'));
        expect(firstColor, WynColors.orange500);
        expect(firstColor, isNot(WynColors.cyan500));

        final secondColor = textColor(tester, find.text('฿150'));
        expect(secondColor, WynColors.orange500);
        expect(secondColor, isNot(WynColors.cyan500));
      });
    });

    group('ZokyOrderDetailScreen item prices (${mode.name})', () {
      late RecordingZokyRepository repo;

      setUp(() {
        // unitPrice=180/quantity=2 (lineTotal=360) kept deliberately
        // distinct from subtotal/feeAmount/total (200/20/220) below --
        // avoids an ambiguous find.text match between the tertiary-
        // colored item price rows and the non-tertiary order summary
        // rows.
        final order = Order(
          id: 'o1',
          storeId: 'store-1',
          storeName: 'ร้านทดสอบ',
          status: OrderStatus.paid,
          recipientName: 'สมชาย ใจดี',
          recipientPhone: '0812345678',
          shippingAddress: '123 ถนนทดสอบ',
          subtotal: 200,
          feePercent: 10,
          feeAmount: 20,
          total: 220,
          createdAt: DateTime.now(),
        );
        const orderItem = OrderItem(
          id: 'oi1',
          productId: 'p1',
          productName: 'เสื้อยืด',
          variantSelection: '',
          unitPrice: 180,
          quantity: 2,
          imageUrl: 'https://example.supabase.co/products/p1.jpg',
        );
        repo = RecordingZokyRepository(order: order, orderItems: [orderItem]);
      });

      testWidgets('resolves to orange500, not cyan500', (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: mode.theme,
          home: ZokyOrderDetailScreen(zokyRepository: repo, orderId: 'o1'),
        ));
        await tester.pumpAndSettle();
        tester.takeException();

        // Unit price row: "฿180 x2".
        final unitColor = textColor(tester, find.text('฿180 x2'));
        expect(unitColor, WynColors.orange500);
        expect(unitColor, isNot(WynColors.cyan500));

        // Line total: unitPrice * quantity = 360.
        final lineTotalColor = textColor(tester, find.text('฿360'));
        expect(lineTotalColor, WynColors.orange500);
        expect(lineTotalColor, isNot(WynColors.cyan500));
      });
    });
  }

  group('ProductGridTile price badge', () {
    testWidgets('is a fixed orange500 constant, not the pre-fix hardcoded white',
        (tester) async {
      // Deliberately pumped under Flutter's stock default ThemeData (no
      // WYN/ZOKY theme at all) to prove this is a direct WynColors
      // reference, not something relying on colorScheme.tertiary/
      // ZokyThemeScope being wired up correctly -- unlike the other
      // widgets above, this one doesn't need a Theme override at all
      // since it never reads Theme.of(context) for this color.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ProductGridTile(product: product(price: 150), onTap: () {})),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final color = textColor(tester, find.text('฿150'));
      expect(color, WynColors.orange500);
      expect(color, isNot(Colors.white));
    });
  });
}
