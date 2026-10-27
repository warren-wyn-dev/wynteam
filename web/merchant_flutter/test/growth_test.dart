import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/screens/growth_panels.dart';
import 'support/fake_repository.dart';

class GrowthRepository extends FakeRepository {
  Json account = {
    'can_manage': true,
    'ads_enabled': true,
    'cost_per_click': 2,
    'min_topup': 100,
    'wynos_promptpay_name': 'ZOKY',
    'wynos_promptpay_id': '0812345678',
    'balance': 50,
    'status': 'paused',
    'clicks_today': 3,
    'clicks_7d': 12,
    'topups': [
      {'id': 't1', 'amount': 200, 'status': 'pending', 'note': null},
    ],
  };
  bool slipPicked = true;
  final topups = <num>[];
  final active = <bool>[];
  final joins = <List<Object>>[];
  Json zoky = {
    'can_manage': true,
    'owed': 40,
    'owed_orders': 2,
    'campaigns': [
      {
        'id': 'c1',
        'name': 'ลดฉ่ำ',
        'campaign_type': 'percentage',
        'discount_value': 20,
        'max_discount': 50,
        'min_subtotal': 100,
        'platform_share_percent': 60,
        'join_open': true,
        'joined': false,
      },
    ],
  };
  @override
  Future<Json> ads(String storeId) async => account;
  @override
  Future<bool> pickAdSlip(String storeId, num amount) async {
    topups.add(amount);
    return slipPicked;
  }

  @override
  Future<void> setAdActive(String storeId, bool value) async {
    active.add(value);
    account['status'] = value ? 'active' : 'paused';
  }

  @override
  Future<Json> platformCampaigns(String storeId) async => zoky;
  @override
  Future<void> joinPlatformCampaign(
    String storeId,
    String campaignId,
    bool join,
  ) async {
    joins.add([campaignId, join]);
    ((zoky['campaigns'] as List).first as Json)['joined'] = join;
  }
}

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  test('campaign terms read like the legacy page', () {
    expect(
      campaignTerms({
        'campaign_type': 'percentage',
        'discount_value': 20,
        'max_discount': 50,
        'min_subtotal': 100,
      }),
      'ลด 20% สูงสุด ฿50.00 · ขั้นต่ำ ฿100.00',
    );
    expect(campaignTerms({'campaign_type': 'free_delivery'}), 'ส่งฟรี');
  });

  testWidgets(
    'ad top-up checks the minimum and a cancelled slip changes nothing',
    (tester) async {
      final repo = GrowthRepository();
      await tester.pumpWidget(
        host(AdsPanel(repository: repo, storeId: 'store-1')),
      );
      await tester.pumpAndSettle();
      expect(find.text('฿50.00'), findsOneWidget);
      expect(find.textContaining('ประมาณ 25 คลิก'), findsOneWidget);
      expect(find.text('0812345678'), findsOneWidget);
      expect(find.text('รอตรวจ'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '50');
      await tester.tap(find.text('แนบสลิปและส่งให้ ZOKY ตรวจ'));
      await tester.pumpAndSettle();
      expect(repo.topups, isEmpty);
      expect(find.text('ยอดเติมขั้นต่ำ ฿100.00'), findsOneWidget);

      repo.slipPicked = false;
      await tester.enterText(find.byType(TextField), '150.50');
      await tester.tap(find.text('แนบสลิปและส่งให้ ZOKY ตรวจ'));
      await tester.pumpAndSettle();
      expect(repo.topups, [150.5]);
      expect(find.text('ส่งสลิปแล้ว รอทีม ZOKY ตรวจ'), findsNothing);

      repo.slipPicked = true;
      await tester.tap(find.text('แนบสลิปและส่งให้ ZOKY ตรวจ'));
      await tester.pumpAndSettle();
      expect(find.text('ส่งสลิปแล้ว รอทีม ZOKY ตรวจ'), findsOneWidget);

      await tester.tap(find.text('เริ่มแสดงโฆษณา'));
      await tester.pumpAndSettle();
      expect(repo.active, [true]);
      expect(find.text('หยุดโฆษณาชั่วคราว'), findsOneWidget);
    },
  );

  testWidgets('joining a ZOKY campaign shows the cost split first', (
    tester,
  ) async {
    final repo = GrowthRepository();
    await tester.pumpWidget(
      host(PlatformCampaignsPanel(repository: repo, storeId: 'store-1')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('ZOKY ค้างโอนให้ร้าน ฿40.00'), findsOneWidget);
    await tester.tap(find.text('เข้าร่วมแคมเปญ'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ZOKY ออกส่วนลดให้ 60% ร้านออก 40%'),
      findsOneWidget,
    );
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(repo.joins, isEmpty);
    await tester.tap(find.text('เข้าร่วมแคมเปญ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'เข้าร่วม'));
    await tester.pumpAndSettle();
    expect(repo.joins, [
      ['c1', true],
    ]);
    expect(find.text('ออกจากแคมเปญ'), findsOneWidget);
  });

  testWidgets('only managers can change campaigns', (tester) async {
    final repo = GrowthRepository()..zoky['can_manage'] = false;
    await tester.pumpWidget(
      host(PlatformCampaignsPanel(repository: repo, storeId: 'store-1')),
    );
    await tester.pumpAndSettle();
    final join = find.widgetWithText(FilledButton, 'เข้าร่วมแคมเปญ');
    expect(tester.widget<FilledButton>(join).onPressed, isNull);
  });

  testWidgets('ads re-read the account on a page refresh', (tester) async {
    final repo = GrowthRepository();
    Widget build(DateTime at) =>
        host(AdsPanel(repository: repo, storeId: 'store-1', refreshedAt: at));
    await tester.pumpWidget(build(DateTime(2026, 10, 27, 10)));
    await tester.pumpAndSettle();
    expect(find.text('฿50.00'), findsOneWidget);
    repo.account['balance'] = 80;
    await tester.pumpWidget(build(DateTime(2026, 10, 27, 10, 0, 20)));
    await tester.pumpAndSettle();
    expect(find.text('฿80.00'), findsOneWidget);
  });
}
