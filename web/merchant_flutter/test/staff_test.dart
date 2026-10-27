import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zoky_merchant/data/merchant_repository.dart';
import 'package:zoky_merchant/screens/staff_panel.dart';
import 'support/fake_repository.dart';

class StaffRepository extends FakeRepository {
  StaffRepository({this.canManageTeam = true});
  final bool canManageTeam;
  final added = <List<String>>[];
  final updates = <List<Object>>[];
  String? failAdd;
  List<Json> team = [
    {'user_id': 'u-owner', 'username': 'boss', 'role': 'owner', 'active': true},
    {
      'user_id': 'u-me',
      'username': 'me',
      'role': 'admin',
      'active': true,
      'self': true,
    },
    {'user_id': 'u-cook', 'username': 'cook', 'role': 'orders', 'active': true},
  ];
  @override
  Future<Json> staff(String storeId) async => {
    'canManage': canManageTeam,
    'members': team,
  };
  @override
  Future<void> addStaff(String storeId, String username, String role) async {
    if (failAdd != null) throw MerchantException(failAdd!);
    added.add([username, role]);
  }

  @override
  Future<void> updateStaff(
    String storeId,
    String userId,
    String role,
    bool active,
  ) async {
    updates.add([userId, role, active]);
    final m = team.firstWhere((m) => m['user_id'] == userId);
    m['role'] = role;
    m['active'] = active;
  }
}

Widget host(MerchantRepository repo) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: StaffPanel(repository: repo, storeId: 'store-1'),
    ),
  ),
);

void main() {
  testWidgets('owner and yourself are read-only; others can be changed', (
    tester,
  ) async {
    final repo = StaffRepository();
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();
    expect(find.text('3 คนที่ใช้งานอยู่'), findsOneWidget);
    expect(find.text('me (คุณ)'), findsOneWidget);
    expect(find.byTooltip('เปลี่ยนสิทธิ์ cook'), findsOneWidget);
    expect(find.byTooltip('เปลี่ยนสิทธิ์ boss'), findsNothing);
    expect(find.byTooltip('เปลี่ยนสิทธิ์ me'), findsNothing);

    await tester.tap(find.byTooltip('เปลี่ยนสิทธิ์ cook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ผู้จัดการ').last);
    await tester.pumpAndSettle();
    expect(repo.updates.last, ['u-cook', 'manager', true]);
    expect(find.text('อัปเดตสิทธิ์ทีมงานแล้ว'), findsOneWidget);

    // Disabling asks first; cancelling changes nothing.
    await tester.tap(find.text('ปิดสิทธิ์'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();
    expect(repo.updates.length, 1);
    await tester.tap(find.text('ปิดสิทธิ์'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ปิดสิทธิ์'));
    await tester.pumpAndSettle();
    expect(repo.updates.last, ['u-cook', 'manager', false]);
    expect(find.text('2 คนที่ใช้งานอยู่'), findsOneWidget);
    expect(find.text('เปิดสิทธิ์'), findsOneWidget);
  });

  testWidgets('adding validates the username and shows server errors', (
    tester,
  ) async {
    final repo = StaffRepository()..failAdd = 'ไม่พบบัญชีนี้';
    await tester.pumpWidget(host(repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'a b');
    await tester.tap(find.text('เพิ่มทีมงาน'));
    await tester.pumpAndSettle();
    expect(repo.added, isEmpty);
    expect(find.text('กรุณาใส่ @username ของบัญชี WYNOS'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '@new_cook');
    await tester.tap(find.text('เพิ่มทีมงาน'));
    await tester.pumpAndSettle();
    expect(find.text('ไม่พบบัญชีนี้'), findsOneWidget);
    expect(find.text('@new_cook'), findsOneWidget);
    repo.failAdd = null;
    await tester.tap(find.text('เพิ่มทีมงาน'));
    await tester.pumpAndSettle();
    expect(repo.added.last, ['@new_cook', 'orders']);
    expect(find.text('เพิ่มทีมงานแล้ว'), findsOneWidget);
  });

  testWidgets('staff without owner/admin rights only see the team', (
    tester,
  ) async {
    await tester.pumpWidget(host(StaffRepository(canManageTeam: false)));
    await tester.pumpAndSettle();
    expect(find.text('เพิ่มทีมงาน'), findsNothing);
    expect(find.text('ปิดสิทธิ์'), findsNothing);
    expect(
      find.text('เฉพาะเจ้าของร้านและแอดมินที่เพิ่มหรือแก้ไขทีมงานได้'),
      findsOneWidget,
    );
  });
}
