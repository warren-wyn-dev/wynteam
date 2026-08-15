import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_seller/features/product/data/product.dart';
import 'package:zoky_seller/features/product/presentation/seller_product_form_screen.dart';
import 'package:zoky_seller/features/product/presentation/seller_product_list_screen.dart';
import 'package:zoky_seller/features/product/presentation/widgets/product_active_badge.dart';
import 'package:zoky_seller/features/store/data/seller_repository.dart';
import 'package:zoky_seller/features/store/data/store.dart';

import 'support/recording_seller_repository.dart';

/// Regression tests for SellerProductListScreen (SELLER-002), per
/// .wyn/docs/design/seller-002-product-management.md, Screen:
/// SellerProductListScreen.
void main() {
  final store = Store(
    id: 'store-1',
    ownerId: 'u1',
    name: 'ร้านทดสอบ',
    createdAt: DateTime(2026, 1, 1),
  );

  Product product({
    String id = 'p1',
    String name = 'เสื้อยืด',
    double price = 199,
    double? originalPrice,
    int stock = 10,
    bool isActive = true,
  }) =>
      Product(
        id: id,
        storeId: store.id,
        storeName: store.name,
        name: name,
        price: price,
        originalPrice: originalPrice,
        stock: stock,
        imageUrls: const ['https://example.supabase.co/products/p1.jpg'],
        isActive: isActive,
        createdAt: DateTime(2026, 1, 1),
      );

  // See seller_auth_gate_test.dart's comment on why Recording*Repository
  // must be built in setUp(), not inline inside testWidgets.
  late RecordingSellerRepository emptyRepo;
  late RecordingSellerRepository populatedRepo;

  setUp(() {
    emptyRepo = RecordingSellerRepository();
    populatedRepo = RecordingSellerRepository(
      products: [
        product(id: 'p1', name: 'เสื้อยืด', price: 199),
        product(id: 'p2', name: 'กางเกงยีนส์', price: 590, stock: 0, isActive: false),
      ],
    );
  });

  testWidgets('shows the onboarding empty state with a CTA when the store has no products',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductListScreen(store: store, sellerRepository: emptyRepo),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีสินค้าในร้านเลย เริ่มเพิ่มสินค้าชิ้นแรกกันเถอะ'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '+ เพิ่มสินค้า'), findsOneWidget);
  });

  testWidgets('renders each product with name, price, status badge and stock text',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductListScreen(store: store, sellerRepository: populatedRepo),
    ));
    await tester.pumpAndSettle();
    // The tile's thumbnail is a real Image.network -- the test HTTP
    // client always returns 400, which is expected/harmless here (see
    // app/test/store_screen_test.dart's identical convention).
    tester.takeException();

    expect(find.text('เสื้อยืด'), findsOneWidget);
    expect(find.text('฿199'), findsOneWidget);
    expect(find.text('เหลือ 10 ชิ้น'), findsOneWidget);

    expect(find.text('กางเกงยีนส์'), findsOneWidget);
    expect(find.text('฿590'), findsOneWidget);
    expect(find.text('หมด'), findsOneWidget);

    // "กำลังขาย"/"ปิดการขาย" also appear as filter chip labels, so assert
    // via ProductActiveBadge's own isActive value instead of raw text.
    final badges = tester
        .widgetList<ProductActiveBadge>(find.byType(ProductActiveBadge))
        .toList();
    expect(badges.map((b) => b.isActive).toList(), [true, false]);
  });

  testWidgets('tapping a filter chip re-fetches with that filter, scoped to this store',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductListScreen(store: store, sellerRepository: populatedRepo),
    ));
    await tester.pumpAndSettle();
    // The tile's thumbnail is a real Image.network -- the test HTTP
    // client always returns 400, which is expected/harmless here (see
    // app/test/store_screen_test.dart's identical convention).
    tester.takeException();

    expect(populatedRepo.lastFetchProductsFilter, ProductStatusFilter.all);
    expect(populatedRepo.lastFetchProductsStoreId, 'store-1');

    await tester.tap(find.widgetWithText(ChoiceChip, 'ปิดการขาย'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(populatedRepo.lastFetchProductsFilter, ProductStatusFilter.inactive);
  });

  testWidgets('typing a query debounces 400ms then searches by name/SKU',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductListScreen(store: store, sellerRepository: populatedRepo),
    ));
    await tester.pumpAndSettle();
    // The tile's thumbnail is a real Image.network -- the test HTTP
    // client always returns 400, which is expected/harmless here (see
    // app/test/store_screen_test.dart's identical convention).
    tester.takeException();

    await tester.enterText(find.byType(TextField), 'เสื้อ');
    await tester.pump(const Duration(milliseconds: 200));
    // Not fired yet -- still mid-debounce.
    expect(populatedRepo.lastFetchProductsQuery, '');

    await tester.pump(const Duration(milliseconds: 250));
    expect(populatedRepo.lastFetchProductsQuery, 'เสื้อ');
  });

  testWidgets('tapping the FAB opens SellerProductFormScreen in create mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductListScreen(store: store, sellerRepository: populatedRepo),
    ));
    await tester.pumpAndSettle();
    // The tile's thumbnail is a real Image.network -- the test HTTP
    // client always returns 400, which is expected/harmless here (see
    // app/test/store_screen_test.dart's identical convention).
    tester.takeException();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    tester.takeException();

    final formScreen = tester.widget<SellerProductFormScreen>(
      find.byType(SellerProductFormScreen),
    );
    expect(formScreen.existingProduct, isNull);
    expect(find.text('เพิ่มสินค้า'), findsOneWidget);
  });

  testWidgets('tapping a product row opens SellerProductFormScreen in edit mode',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SellerProductListScreen(store: store, sellerRepository: populatedRepo),
    ));
    await tester.pumpAndSettle();
    // The tile's thumbnail is a real Image.network -- the test HTTP
    // client always returns 400, which is expected/harmless here (see
    // app/test/store_screen_test.dart's identical convention).
    tester.takeException();

    await tester.tap(find.text('เสื้อยืด'));
    await tester.pumpAndSettle();
    tester.takeException();

    final formScreen = tester.widget<SellerProductFormScreen>(
      find.byType(SellerProductFormScreen),
    );
    expect(formScreen.existingProduct?.id, 'p1');
    expect(find.text('แก้ไขสินค้า'), findsOneWidget);
  });
}
