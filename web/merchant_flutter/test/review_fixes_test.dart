import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/main.dart';
import 'package:zoky_merchant/screens/order_dialogs.dart';
import 'support/fake_repository.dart';

class SelectionRepository extends FakeRepository {
  final released = <String>[];
  @override
  Future<void> releaseDeliveryPhoto(
    String storeId,
    String orderId,
    String imagePath,
  ) async {
    released.add(imagePath);
  }
}

void main() {
  testWidgets('manual no-slip payment requires explicit receipt confirmation', (
    tester,
  ) async {
    bool? savedConfirmation;
    await tester.pumpWidget(
      ZokyApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PaymentReviewDialog(
                  repository: FakeRepository(),
                  storeId: 'store-1',
                  order: const {
                    'id': 'order-1',
                    'order_number': 'TEST-1',
                    'total': 75,
                    'payment_status': 'pending',
                  },
                  save: (status, note, manualConfirmation) async {
                    savedConfirmation = manualConfirmation;
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
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'ยืนยันว่ารับเงินแล้ว'),
          )
          .onPressed,
      isNull,
    );
    expect(savedConfirmation, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยันว่ารับเงินแล้ว'));
    await tester.pumpAndSettle();
    expect(savedConfirmation, true);
  });

  testWidgets('a cancelled delivery dialog releases its selected local photo', (
    tester,
  ) async {
    final repo = SelectionRepository();
    await tester.pumpWidget(
      ZokyApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DeliveryProofDialog(
                  repository: repo,
                  storeId: 'store-1',
                  orderId: 'order-1',
                  save: (_, _, _) async => true,
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
    expect(repo.released, isEmpty);
    await tester.tap(find.text('ปิด'));
    await tester.pumpAndSettle();
    expect(repo.released, ['delivery/order-1/proof.jpg']);
  });

  testWidgets('delivery failure retains the selection for a retry', (
    tester,
  ) async {
    final repo = SelectionRepository();
    var attempts = 0;
    await tester.pumpWidget(
      ZokyApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => DeliveryProofDialog(
                  repository: repo,
                  storeId: 'store-1',
                  orderId: 'order-1',
                  save: (_, _, _) async => ++attempts == 2,
                  error: () => 'ลองอีกครั้ง',
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
    await tester.tap(find.text('ยืนยันส่งสำเร็จ').last);
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(repo.released, isEmpty);
    await tester.tap(find.text('ยืนยันส่งสำเร็จ').last);
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(repo.released, ['delivery/order-1/proof.jpg']);
  });
}
