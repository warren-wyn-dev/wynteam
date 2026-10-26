import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/main.dart';
import 'package:zoky_merchant/screens/order_dialogs.dart';
import 'support/fake_repository.dart';

void main() {
  testWidgets(
    'delivery requires a photo and dropoff location before completion',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? savedMethod, savedPath, savedNote;
      await tester.pumpWidget(
        ZokyApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => DeliveryProofDialog(
                    repository: FakeRepository(),
                    storeId: 'store-1',
                    orderId: 'order-1',
                    save: (method, path, note) async {
                      savedMethod = method;
                      savedPath = path;
                      savedNote = note;
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
      await tester.tap(find.text('ยืนยันส่งสำเร็จ').last);
      await tester.pumpAndSettle();
      expect(find.text('กรุณาแนบรูปหลักฐานส่งสำเร็จ'), findsOneWidget);
      expect(savedMethod, isNull);
      await tester.tap(find.text('แนบรูปหลักฐาน (จำเป็น)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ส่งให้ผู้รับโดยตรง'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('วางอาหารตามจุดนัดหมาย').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยืนยันส่งสำเร็จ').last);
      await tester.pumpAndSettle();
      expect(find.text('กรุณาระบุจุดวางอาหาร'), findsOneWidget);
      expect(savedMethod, isNull);
      await tester.enterText(find.byType(TextField).first, 'หน้าประตูบ้าน');
      await tester.tap(find.text('ยืนยันส่งสำเร็จ').last);
      await tester.pumpAndSettle();
      expect(savedMethod, 'dropoff');
      expect(savedPath, 'delivery/order-1/proof.jpg');
      expect(savedNote, 'หน้าประตูบ้าน');
    },
  );
  testWidgets(
    'cancelling a paid order requires a reason and explains pending refund',
    (tester) async {
      String? reason;
      await tester.pumpWidget(
        ZokyApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  reason = await requestCancellation(ctx, 'TEST-1', true);
                },
                child: const Text('เปิด'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('เปิด'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ไม่ได้คืนเงินอัตโนมัติ'), findsOneWidget);
      await tester.tap(find.text('ยืนยันยกเลิก'));
      await tester.pumpAndSettle();
      expect(reason, isNull);
      await tester.enterText(find.byType(TextFormField), 'อาหารหมด');
      await tester.tap(find.text('ยืนยันยกเลิก'));
      await tester.pumpAndSettle();
      expect(reason, 'อาหารหมด');
    },
  );
  testWidgets(
    'a missing slip cannot be marked paid and issue requires a note',
    (tester) async {
      String? saved;
      await tester.pumpWidget(
        ZokyApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: ctx,
                  builder: (_) => PaymentReviewDialog(
                    repository: FakeRepository(),
                    storeId: 'store-1',
                    order: {'id': 'order-1', 'order_number': 'TEST-1'},
                    save: (status, note, manualConfirmation) async {
                      saved = status;
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
      expect(find.text('ยังไม่มีสลิปที่ตรวจสอบได้'), findsOneWidget);
      expect(find.text('ยืนยันว่ารับเงินแล้ว'), findsNothing);
      await tester.tap(find.text('แจ้งปัญหาสลิป'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.text('กรุณาระบุปัญหาที่พบในสลิป'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'ยอดเงินไม่ตรง');
      await tester.tap(find.text('แจ้งปัญหาสลิป'));
      await tester.pumpAndSettle();
      expect(saved, 'issue');
    },
  );
  testWidgets('paid no-show returns an explicit no-refund decision and reason', (tester) async {
    Map<String, dynamic>? decision;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        decision = await requestStoreCancellation(context, 'QA-1', true);
      }, child: const Text('เปิด')),
    ))));
    await tester.tap(find.text('เปิด'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('คืนเงิน'));
    await tester.enterText(find.byType(TextFormField), 'ลูกค้าไม่มารับ');
    await tester.tap(find.text('ยืนยันยกเลิก'));
    await tester.pumpAndSettle();
    expect(decision, {'note': 'ลูกค้าไม่มารับ', 'refund': false});
  });

}
