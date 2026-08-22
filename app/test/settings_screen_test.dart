import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/block/presentation/blocked_list_screen.dart';
import 'package:wyn/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:wyn/features/mute/presentation/muted_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/settings/presentation/settings_screen.dart';

import 'support/fake_supabase_session.dart';

void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  testWidgets('ความปลอดภัย section shows both Blocked List and Muted List rows',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ความปลอดภัย'), findsOneWidget);
    expect(find.text('บัญชีที่ถูกบล็อก'), findsOneWidget);
    expect(find.text('บัญชีที่ปิดเสียง'), findsOneWidget);
  });

  testWidgets('tapping บัญชีที่ถูกบล็อก opens BlockedListScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บัญชีที่ถูกบล็อก'));
    await tester.pumpAndSettle();

    expect(find.byType(BlockedListScreen), findsOneWidget);
  });

  testWidgets('tapping บัญชีที่ปิดเสียง opens MutedListScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บัญชีที่ปิดเสียง'));
    await tester.pumpAndSettle();

    expect(find.byType(MutedListScreen), findsOneWidget);
  });

  // WYN-029, Screen 1 -- an ordinary user must not see even an empty
  // "เครื่องมือผู้ดูแล" heading, per the Product spec's "ไม่ปรากฏในเมนูของ
  // ผู้ใช้ทั่วไป".
  testWidgets('platformRole == user never shows the "เครื่องมือผู้ดูแล" section at all',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user),
    ));
    await tester.pumpAndSettle();

    expect(find.text('เครื่องมือผู้ดูแล'), findsNothing);
    expect(find.text('คิวตรวจสอบรายงาน'), findsNothing);
  });

  testWidgets('platformRole == moderator shows the section and opens ModerationQueueScreen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.moderator),
    ));
    await tester.pumpAndSettle();

    expect(find.text('เครื่องมือผู้ดูแล'), findsOneWidget);
    expect(find.text('คิวตรวจสอบรายงาน'), findsOneWidget);

    await tester.tap(find.text('คิวตรวจสอบรายงาน'));
    await tester.pumpAndSettle();

    expect(find.byType(ModerationQueueScreen), findsOneWidget);
  });

  testWidgets('platformRole == admin also shows the section (admin sees everything '
      'moderator does)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.admin),
    ));
    await tester.pumpAndSettle();

    expect(find.text('เครื่องมือผู้ดูแล'), findsOneWidget);
  });
}
