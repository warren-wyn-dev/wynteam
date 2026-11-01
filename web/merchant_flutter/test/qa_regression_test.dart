import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/main.dart';
import 'package:zoky_merchant/data/merchant_controller.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/screens/merchant_home.dart';
import 'package:zoky_merchant/screens/order_dialogs.dart';
import 'support/fake_repository.dart';

class SelectedPhotoWithoutPreview extends FakeRepository {
  @override
  Future<Json?> pickDeliveryPhoto(String storeId, String orderId) async => {
    'path': 'delivery/$orderId/photo.jpg',
    'previewUrl': null,
  };
}

void main() {
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'a selected delivery photo without preview does not crash or lose its handle',
    (tester) async {
      phoneSize(tester);
      String? savedPath;
      await tester.pumpWidget(
        ZokyApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => DeliveryProofDialog(
                    repository: SelectedPhotoWithoutPreview(),
                    storeId: 'store-1',
                    orderId: 'order-1',
                    save: (method, path, note) async {
                      savedPath = path;
                      return true;
                    },
                    error: () => null,
                  ),
                ),
                child: const Text('เปิด'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('แนบรูปหลักฐาน (จำเป็น)'));
      await tester.pumpAndSettle();
      expect(find.text('แนบรูปแล้ว แต่แสดงตัวอย่างไม่ได้'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('ยืนยันส่งสำเร็จ').last);
      await tester.pumpAndSettle();
      expect(savedPath, 'delivery/order-1/photo.jpg');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual slip fallback remains reviewable after an earlier Stripe checkout session',
    (tester) async {
      phoneSize(tester);
      final repo = FakeRepository();
      repo.orderRows = [
        {
          ...repo.orderRows.first,
          'payment_status': 'submitted',
          'payment_provider': 'merchant_manual',
          'stripe_checkout_session_id': 'cs_previous',
          'payment_slip_path': 'buyer/slips/manual.jpg',
        },
      ];
      await tester.pumpWidget(
        ZokyApp(
          home: MerchantHome(repository: repo, onSignOut: () async {}),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ออเดอร์').first);
      await tester.pumpAndSettle();
      expect(find.text('ตรวจสลิป · รับออเดอร์'), findsOneWidget);
      expect(find.text('รอระบบยืนยันการชำระเงินอัตโนมัติ'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('Stripe webhook-managed payment cannot open manual slip review', (
    tester,
  ) async {
    phoneSize(tester);
    final repo = FakeRepository();
    repo.orderRows = [
      {
        ...repo.orderRows.first,
        'payment_status': 'submitted',
        'payment_provider': 'stripe',
        'stripe_checkout_session_id': 'cs_active',
        'payment_slip_path': 'buyer/slips/old.jpg',
      },
    ];
    await tester.pumpWidget(
      ZokyApp(
        home: MerchantHome(repository: repo, onSignOut: () async {}),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ออเดอร์').first);
    await tester.pumpAndSettle();
    expect(find.text('ตรวจการชำระเงิน'), findsNothing);
    expect(find.text('รอระบบยืนยันการชำระเงินอัตโนมัติ'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'payment review shows expected money and receiving account before any manual decision',
    (tester) async {
      await tester.pumpWidget(
        ZokyApp(
          home: PaymentReviewDialog(
            repository: FakeRepository(),
            storeId: 'store-1',
            order: {'id': 'order-1', 'order_number': 'TEST-1', 'total': 125.50},
            store: const {'promptpay_name': 'ร้านตัวอย่าง'},
            save: (status, note, manualConfirmation) async => true,
            error: () => null,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ยอดที่ต้องได้รับ ฿125.50'), findsOneWidget);
      expect(find.text('ชื่อผู้รับเงิน: ร้านตัวอย่าง'), findsOneWidget);
      expect(find.text('ยืนยันว่ารับเงินแล้ว'), findsNothing);
    },
  );

  test('a disposed controller cannot start a mutation', () async {
    final repo = FakeRepository(),
        controller = MerchantController(FakeRepository());
    await controller.initialize();
    controller.dispose();
    expect(controller.writable, false);
    expect(
      await controller.mutate(
        () => repo.saveStore('store-1', {'name': 'หลังปิด'}),
      ),
      false,
    );
    expect(repo.writes, 0);
  });

  test(
    'a mutation finishing after disposal cannot report success to an old account view',
    () async {
      final controller = MerchantController(FakeRepository());
      await controller.initialize();
      final complete = Completer<void>();
      final pending = controller.mutate(() => complete.future);
      controller.dispose();
      complete.complete();
      expect(await pending, false);
    },
  );
}
