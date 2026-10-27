import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/screens/store_settings_panels.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('PromptPay and bank numbers follow the database rule', () {
    expect(promptPayError(''), isNull);
    expect(promptPayError('081-234-5678'), isNull);
    expect(promptPayError('1234567890123'), isNull);
    expect(promptPayError('123456789012345'), isNull);
    expect(promptPayError('1812345678'), isNotNull);
    expect(promptPayError('08123'), isNotNull);
    expect(promptPayError('08x2345678'), isNotNull);
    expect(bankAccountError('123-4-56789-0'), isNull);
    expect(bankAccountError('12345'), isNotNull);
  });

  testWidgets(
    'payment channels validate before saving and show server errors',
    (tester) async {
      Json? submitted;
      await tester.pumpWidget(
        host(
          PaymentChannelsPanel(
            store: const {
              'id': 'store-1',
              'promptpay_name': 'ร้านเรา',
              'promptpay_id': '0812345678',
            },
            enabled: true,
            save: (values) async {
              submitted = values;
              return false;
            },
            pickQr: () async => true,
            error: () => 'บัญชีนี้ไม่มีสิทธิ์ดำเนินการ',
          ),
        ),
      );
      expect(find.text('ยังไม่มี QR รับเงิน'), findsOneWidget);
      expect(find.text('ลบ QR'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'เบอร์หรือเลข PromptPay'),
        '1812345678',
      );
      await tester.tap(find.text('บันทึกช่องทางรับเงิน'));
      await tester.pump();
      expect(submitted, isNull);
      expect(find.textContaining('PromptPay ต้องเป็น'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'เบอร์หรือเลข PromptPay'),
        '0899999999',
      );
      await tester.tap(find.text('บันทึกช่องทางรับเงิน'));
      await tester.pump();
      expect(submitted!['promptpay_id'], '0899999999');
      expect(submitted!['promptpay_name'], 'ร้านเรา');
      expect(find.text('บัญชีนี้ไม่มีสิทธิ์ดำเนินการ'), findsOneWidget);
    },
  );

  testWidgets('an existing QR can be replaced or removed', (tester) async {
    Json? submitted;
    var picks = 0;
    await tester.pumpWidget(
      host(
        PaymentChannelsPanel(
          store: const {
            'id': 'store-1',
            'payment_qr_path': 'stores/store-1/payment/qr.png',
          },
          enabled: true,
          save: (values) async {
            submitted = values;
            return true;
          },
          pickQr: () async {
            picks++;
            return true;
          },
          error: () => null,
        ),
      ),
    );
    expect(find.text('มี QR รับเงินแล้ว'), findsOneWidget);
    await tester.tap(find.text('เปลี่ยน QR'));
    await tester.pump();
    expect(picks, 1);
    await tester.tap(find.text('ลบ QR'));
    await tester.pump();
    expect(submitted, {'payment_qr_path': null});
  });

  testWidgets('read-only payment channels cannot be edited', (tester) async {
    await tester.pumpWidget(
      host(
        PaymentChannelsPanel(
          store: const {'id': 'store-1'},
          enabled: false,
          save: (_) async => true,
          pickQr: () async => true,
          error: () => null,
        ),
      ),
    );
    final save = find.widgetWithText(FilledButton, 'บันทึกช่องทางรับเงิน');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
  });

  testWidgets('opening hours keep the stored week and refuse a closed week', (
    tester,
  ) async {
    Json? submitted;
    const weekly = {
      'mon': {'enabled': true, 'open': '18:00', 'close': '02:00'},
      'tue': {'enabled': false, 'open': '09:00', 'close': '21:00'},
    };
    await tester.pumpWidget(
      host(
        BusinessHoursPanel(
          store: const {
            'id': 'store-1',
            'business_schedule': {'weekly': weekly},
            'special_closed_dates': ['2026-12-31', '2026-11-01'],
          },
          enabled: true,
          save: (values) async {
            submitted = values;
            return true;
          },
          error: () => null,
        ),
      ),
    );
    expect(find.text('18:00'), findsOneWidget);
    expect(find.text('02:00'), findsOneWidget);
    expect(find.text('2026-11-01'), findsOneWidget);
    await tester.ensureVisible(find.text('บันทึกเวลาเปิดร้าน'));
    await tester.tap(find.text('บันทึกเวลาเปิดร้าน'));
    await tester.pump();
    final saved = (submitted!['business_schedule'] as Map)['weekly'] as Map;
    expect(saved.keys, ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']);
    expect(saved['mon'], {'enabled': true, 'open': '18:00', 'close': '02:00'});
    expect((saved['tue'] as Map)['enabled'], false);
    expect(submitted!['special_closed_dates'], ['2026-11-01', '2026-12-31']);

    // Remove a closed day, then switch every day off: not saved.
    submitted = null;
    await tester.tap(find.byTooltip('ลบวันหยุด 2026-11-01'));
    await tester.pump();
    expect(find.text('2026-11-01'), findsNothing);
    for (final day in [
      'จันทร์',
      'พุธ',
      'พฤหัสบดี',
      'ศุกร์',
      'เสาร์',
      'อาทิตย์',
    ]) {
      final toggle = find.widgetWithText(SwitchListTile, day);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
    }
    await tester.ensureVisible(find.text('บันทึกเวลาเปิดร้าน'));
    await tester.tap(find.text('บันทึกเวลาเปิดร้าน'));
    await tester.pump();
    expect(submitted, isNull);
    expect(find.text('ต้องเปิดร้านอย่างน้อย 1 วันต่อสัปดาห์'), findsOneWidget);
  });

  testWidgets('a refresh from another save keeps unsaved drafts', (
    tester,
  ) async {
    Widget build(Json store) => host(
      Column(
        children: [
          PaymentChannelsPanel(
            store: store,
            enabled: true,
            save: (_) async => true,
            pickQr: () async => true,
            error: () => null,
          ),
          BusinessHoursPanel(
            store: store,
            enabled: true,
            save: (_) async => true,
            error: () => null,
          ),
        ],
      ),
    );
    final before = {
      'id': 'store-1',
      'promptpay_id': '0812345678',
      'updated_at': '1',
      'special_closed_dates': ['2026-12-31'],
    };
    await tester.pumpWidget(build(before));
    await tester.enterText(
      find.widgetWithText(TextField, 'เบอร์หรือเลข PromptPay'),
      '0899999999',
    );
    await tester.ensureVisible(find.byTooltip('ลบวันหยุด 2026-12-31'));
    await tester.tap(find.byTooltip('ลบวันหยุด 2026-12-31'));
    await tester.pump();
    expect(find.text('2026-12-31'), findsNothing);
    // QR saved elsewhere: updated_at and the QR change, the draft fields do not.
    await tester.pumpWidget(
      build({
        ...before,
        'updated_at': '2',
        'payment_qr_path': 'stores/store-1/payment/qr.png',
      }),
    );
    await tester.pump();
    expect(find.text('0899999999'), findsOneWidget);
    expect(find.text('2026-12-31'), findsNothing);
    // A change to the saved number itself replaces the draft.
    await tester.pumpWidget(
      build({...before, 'updated_at': '3', 'promptpay_id': '0811111111'}),
    );
    await tester.pump();
    expect(find.text('0811111111'), findsOneWidget);
  });
}
