import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/screens/billing_panel.dart';
import 'support/fake_repository.dart';

class BillingRepository extends FakeRepository {
  Json data = {
    'enabled': true,
    'monthly_fee': 499,
    'in_trial': false,
    'trial_ends_on': '2026-10-01',
    'next_cycle_on': '2026-12-01',
    'account': {
      'promptpay_name': 'ZOKY',
      'promptpay_id': '0812345678',
      'bank_name': null,
      'bank_account_name': null,
      'bank_account_number': null,
    },
    'invoices': [
      {
        'id': 'inv-2',
        'period_start': '2026-11-01',
        'period_end': '2026-11-30',
        'amount': 499,
        'status': 'rejected',
        'due_on': '2026-11-08',
        'overdue_days': 3,
        'note': 'ยอดไม่ตรง',
      },
      {
        'id': 'inv-1',
        'period_start': '2026-10-01',
        'period_end': '2026-10-31',
        'amount': 499,
        'status': 'paid',
        'due_on': '2026-10-08',
        'overdue_days': 0,
        'receipt_no': 'ZK-202610-000001',
      },
    ],
  };
  bool picked = true;
  Object? failure;
  final slips = <String>[];
  @override
  Future<Json> billing(String storeId) async {
    if (failure != null) throw failure!;
    return data;
  }

  @override
  Future<bool> pickBillingSlip(String storeId, String invoiceId) async {
    slips.add(invoiceId);
    if (picked) {
      ((data['invoices'] as List).first as Json)['status'] = 'slip_submitted';
    }
    return picked;
  }
}

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('billing days are Bangkok calendar days in the Thai year', () {
    expect(billingDay('2026-11-08'), '8/11/2569');
    expect(billingDay(null), '—');
  });

  testWidgets('shows how to pay, attaches a slip and opens paid receipts', (
    tester,
  ) async {
    final repo = BillingRepository();
    final receipts = <String>[];
    await tester.pumpWidget(
      host(
        BillingPanel(
          repository: repo,
          storeId: 'store-1',
          openReceipt: receipts.add,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ค่าบริการ ฿499.00 ต่อเดือน'), findsOneWidget);
    expect(find.text('0812345678'), findsOneWidget);
    expect(find.textContaining('เลยกำหนด 3 วัน'), findsOneWidget);
    expect(find.text('หมายเหตุจาก ZOKY: ยอดไม่ตรง'), findsOneWidget);
    expect(find.textContaining('ใบเสร็จ ZK-202610-000001'), findsOneWidget);

    await tester.tap(find.text('แนบสลิปใหม่'));
    await tester.pumpAndSettle();
    expect(repo.slips, ['inv-2']);
    expect(find.text('ส่งสลิปแล้ว รอ ZOKY ตรวจ'), findsOneWidget);
    expect(find.textContaining('รอ ZOKY ตรวจสลิป'), findsOneWidget);
    expect(find.text('แนบสลิปใหม่'), findsNothing);
    // Nothing left to pay: the ZOKY account is no longer shown.
    expect(find.text('0812345678'), findsNothing);

    await tester.tap(find.text('ดูและบันทึกใบเสร็จ'));
    expect(receipts, ['inv-1']);
  });

  testWidgets('a cancelled picker shows no success message', (tester) async {
    final repo = BillingRepository()..picked = false;
    await tester.pumpWidget(
      host(BillingPanel(repository: repo, storeId: 's', openReceipt: (_) {})),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('แนบสลิปใหม่'));
    await tester.pumpAndSettle();
    expect(find.text('ส่งสลิปแล้ว รอ ZOKY ตรวจ'), findsNothing);
    expect(find.text('แนบสลิปใหม่'), findsOneWidget);
  });

  testWidgets('trial and not-started states, and load errors with retry', (
    tester,
  ) async {
    final repo = BillingRepository()
      ..data = {
        'enabled': true,
        'monthly_fee': 499,
        'in_trial': true,
        'trial_ends_on': '2026-12-01',
        'next_cycle_on': '2026-12-01',
        'invoices': [],
      };
    await tester.pumpWidget(
      host(BillingPanel(repository: repo, storeId: 's', openReceipt: (_) {})),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ทดลองใช้ฟรีถึง 1/12/2569'), findsOneWidget);
    expect(find.text('ยังไม่มีใบแจ้งหนี้'), findsOneWidget);

    repo.data = {'enabled': false, 'invoices': []};
    repo.failure = const MerchantException('โหลดค่าบริการไม่สำเร็จ');
    await tester.pumpWidget(
      host(
        BillingPanel(
          repository: repo,
          storeId: 's',
          openReceipt: (_) {},
          refreshedAt: DateTime(2026),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('โหลดค่าบริการไม่สำเร็จ'), findsOneWidget);
    repo.failure = null;
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(find.text('ZOKY ยังไม่เริ่มเก็บค่าบริการรายเดือน'), findsOneWidget);
  });

  testWidgets('home banner appears only while an invoice waits for payment', (
    tester,
  ) async {
    final repo = BillingRepository();
    var opened = 0;
    Widget banner(DateTime at) => host(
      BillingDueBanner(
        repository: repo,
        storeId: 's',
        refreshedAt: at,
        onOpen: () => opened++,
      ),
    );
    await tester.pumpWidget(banner(DateTime(2026)));
    await tester.pumpAndSettle();
    expect(find.text('ค่าบริการ ZOKY เลยกำหนด 3 วัน'), findsOneWidget);
    await tester.tap(find.text('ค่าบริการ ZOKY เลยกำหนด 3 วัน'));
    expect(opened, 1);
    ((repo.data['invoices'] as List).first as Json)['status'] = 'paid';
    await tester.pumpWidget(banner(DateTime(2027)));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
  });
}
