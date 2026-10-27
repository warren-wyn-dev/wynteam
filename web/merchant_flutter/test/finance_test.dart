import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/screens/finance_panel.dart';
import 'support/fake_repository.dart';

class FinanceRepository extends FakeRepository {
  final requests = <String>[];
  final pending = <String, Completer<Json>>{};
  @override
  Future<Json> finance(String storeId, String period) {
    requests.add(period);
    return (pending[period] = Completer<Json>()).future;
  }
}

Widget host(MerchantRepository repo) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: FinancePanel(repository: repo, storeId: 'store-1'),
    ),
  ),
);

void main() {
  testWidgets('shows server figures and the change from the last period', (
    tester,
  ) async {
    final repo = FinanceRepository();
    await tester.pumpWidget(host(repo));
    expect(repo.requests, ['today']);
    repo.pending['today']!.complete({
      'sales_net': 900,
      'prev_sales_net': 600,
      'orders': 4,
      'income': 850,
      'refunds': 50,
      'refund_count': 1,
      'ad_spend': 50,
      'pending_slip_count': 2,
      'pending_slip_total': 120,
      'platform_owed': 0,
      'gp': 0,
      'days': [],
    });
    await tester.pumpAndSettle();
    expect(find.text('฿900.00'), findsOneWidget);
    expect(find.text('4 ออเดอร์ · +50% จากช่วงก่อนหน้า'), findsOneWidget);
    expect(find.text('฿850.00'), findsOneWidget);
    expect(find.text('สลิปรอตรวจ'), findsOneWidget);
    expect(find.text('ZOKY ค้างโอนให้ร้าน'), findsNothing);
    expect(find.text('GP'), findsNothing);
  });

  testWidgets('switching the period loads that period from the server', (
    tester,
  ) async {
    final repo = FinanceRepository();
    await tester.pumpWidget(host(repo));
    repo.pending['today']!.complete({'sales_net': 1, 'days': []});
    await tester.pumpAndSettle();
    await tester.tap(find.text('เดือนนี้'));
    await tester.pump();
    expect(repo.requests, ['today', 'month']);
    repo.pending['month']!.complete({'sales_net': 3000, 'days': []});
    await tester.pumpAndSettle();
    expect(find.text('฿3000.00'), findsOneWidget);
  });

  testWidgets('errors are shown with a retry and no stale figures', (
    tester,
  ) async {
    final repo = FinanceRepository();
    await tester.pumpWidget(host(repo));
    repo.pending['today']!.completeError(
      const MerchantException('บัญชีนี้ไม่มีสิทธิ์ดำเนินการ'),
    );
    await tester.pumpAndSettle();
    expect(find.text('บัญชีนี้ไม่มีสิทธิ์ดำเนินการ'), findsOneWidget);
    expect(find.text('ยอดขายสุทธิ'), findsNothing);
    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pump();
    expect(repo.requests, ['today', 'today']);
  });
}
