import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_controller.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/screens/fulfillment_panels.dart';
import 'package:zoky_merchant/screens/order_dialogs.dart';
import 'support/fake_repository.dart';

class PausedRepository extends FakeRepository {
  Completer<void>? pause;
  @override
  Future<List<Json>> orders(String id, String status, int offset) async {
    await pause?.future;
    return super.orders(id, status, offset);
  }
}

void main() {
  test('pickup and delivery follow different paths and pickup is terminal', () {
    expect(
      orderNextStatus({'fulfillment_type': 'pickup', 'status': 'preparing'}),
      'ready_for_pickup',
    );
    expect(
      orderNextStatus({
        'fulfillment_type': 'pickup',
        'status': 'ready_for_pickup',
      }),
      'picked_up',
    );
    expect(
      orderNextStatus({'fulfillment_type': 'pickup', 'status': 'picked_up'}),
      isNull,
    );
    expect(orderNextStatus({'status': 'preparing'}), 'ready_for_delivery');
    expect(
      orderNextAction({
        'fulfillment_type': 'pickup',
        'status': 'ready_for_pickup',
      }),
      'ลูกค้ารับแล้ว',
    );
  });
  test(
    'realtime invalidation during a read queues another server refresh',
    () async {
      final repo = PausedRepository();
      final c = MerchantController(repo);
      await c.initialize();
      final before = repo.orderReads;
      repo.pause = Completer<void>();
      final first = c.refresh();
      await Future<void>.delayed(Duration.zero);
      await c.refresh();
      repo.pause!.complete();
      await first;
      await Future<void>.delayed(Duration.zero);
      expect(repo.orderReads, before + 2);
      c.dispose();
    },
  );
  testWidgets(
    'settings show server errors, validate minutes and never claim success',
    (tester) async {
      Json? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FulfillmentSettingsPanel(
              store: const {'id': 'store-1'},
              enabled: true,
              save: (values) async {
                submitted = values;
                return false;
              },
              error: () => 'pickup_requires_schedule',
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '4');
      await tester.tap(find.text('บันทึกรูปแบบรับอาหาร'));
      await tester.pump();
      expect(submitted, isNull);
      expect(
        find.text('เวลาเตรียมอาหารต้องเป็นจำนวนเต็ม 5–120 นาที'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '15');
      await tester.tap(find.text('บันทึกรูปแบบรับอาหาร'));
      await tester.pump();
      expect(submitted!['delivery'], true);
      expect(find.text('pickup_requires_schedule'), findsOneWidget);
    },
  );
  testWidgets('COD delivery requires explicit cash receipt confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeliveryProofDialog(
            repository: FakeRepository(),
            storeId: 'store-1',
            orderId: 'order-1',
            cod: true,
            save: (_, path, note) async => true,
            error: () => null,
          ),
        ),
      ),
    );
    final button = find.widgetWithText(FilledButton, 'ยืนยันส่งสำเร็จ');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(find.text('ได้รับเงินสดแล้ว'));
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  });
  testWidgets(
    'refund cannot be confirmed without a selected slip and receipt check',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RefundSlipDialog(
              repository: FakeRepository(),
              storeId: 'store-1',
              orderId: 'order-1',
              save: (_) async => true,
              error: () => null,
            ),
          ),
        ),
      );
      final button = find.widgetWithText(FilledButton, 'ยืนยันคืนเงิน');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.text('โอนเงินคืนครบแล้ว'));
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
    },
  );
}
