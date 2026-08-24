import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/block/presentation/blocked_list_screen.dart';
import 'package:wyn/features/drop/presentation/recently_deleted_drops_screen.dart';
import 'package:wyn/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:wyn/features/mute/presentation/muted_list_screen.dart';
import 'package:wyn/features/notification/presentation/notification_settings_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/settings/presentation/settings_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_profile_repository.dart';

void main() {
  // Constructed in setUpAll (not inline in a test body) so the
  // SupabaseClient each RecordingProfileRepository wraps -- and the
  // GoTrue auto-refresh timer that starts with it -- isn't attributed to
  // a single test's FakeAsync zone and flagged as a leaked timer at
  // teardown. Mirrors every other RecordingXRepository across this
  // project's test suite (e.g. create_drop_screen_test.dart).
  late RecordingProfileRepository recordingProfileRepository;
  late _ThrowingProfileRepository throwingProfileRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    recordingProfileRepository = RecordingProfileRepository();
    throwingProfileRepository = _ThrowingProfileRepository();
  });

  testWidgets('ความปลอดภัย section shows both Blocked List and Muted List rows',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ความปลอดภัย'), findsOneWidget);
    expect(find.text('บัญชีที่ถูกบล็อก'), findsOneWidget);
    expect(find.text('บัญชีที่ปิดเสียง'), findsOneWidget);
  });

  testWidgets('tapping บัญชีที่ถูกบล็อก opens BlockedListScreen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บัญชีที่ถูกบล็อก'));
    await tester.pumpAndSettle();

    expect(find.byType(BlockedListScreen), findsOneWidget);
  });

  testWidgets('tapping บัญชีที่ปิดเสียง opens MutedListScreen', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('บัญชีที่ปิดเสียง'));
    await tester.pumpAndSettle();

    expect(find.byType(MutedListScreen), findsOneWidget);
  });

  // WYN-044, Screen 1.
  testWidgets(
      'การแจ้งเตือน section shows the entry, tapping opens NotificationSettingsScreen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('การแจ้งเตือน'), findsOneWidget);
    expect(find.text('ตั้งค่าการแจ้งเตือน'), findsOneWidget);

    await tester.tap(find.text('ตั้งค่าการแจ้งเตือน'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });

  testWidgets('tapping รายการที่ลบ opens RecentlyDeletedDropsScreen (WYN-037)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('รายการที่ลบ'), findsOneWidget);

    await tester.tap(find.text('รายการที่ลบ'));
    await tester.pumpAndSettle();

    expect(find.byType(RecentlyDeletedDropsScreen), findsOneWidget);
  });

  // WYN-029, Screen 1 -- an ordinary user must not see even an empty
  // "เครื่องมือผู้ดูแล" heading, per the Product spec's "ไม่ปรากฏในเมนูของ
  // ผู้ใช้ทั่วไป".
  testWidgets(
      'platformRole == user never shows the "เครื่องมือผู้ดูแล" section at all',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('เครื่องมือผู้ดูแล'), findsNothing);
    expect(find.text('คิวตรวจสอบรายงาน'), findsNothing);
  });

  testWidgets(
      'platformRole == moderator shows the section and opens ModerationQueueScreen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(
          platformRole: PlatformRole.moderator, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('เครื่องมือผู้ดูแล'), findsOneWidget);
    expect(find.text('คิวตรวจสอบรายงาน'), findsOneWidget);

    await tester.tap(find.text('คิวตรวจสอบรายงาน'));
    await tester.pumpAndSettle();

    expect(find.byType(ModerationQueueScreen), findsOneWidget);
  });

  testWidgets(
      'platformRole == admin also shows the section (admin sees everything '
      'moderator does)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.admin, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('เครื่องมือผู้ดูแล'), findsOneWidget);
  });

  // WYN-039, Screen 1.
  group('ความเป็นส่วนตัว section (WYN-039)', () {
    testWidgets('shows the Private Account toggle, initialized from isPrivate',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ความเป็นส่วนตัว'), findsOneWidget);
      expect(find.text('บัญชีส่วนตัว (Private Account)'), findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
    });

    testWidgets('flipping the toggle calls updateIsPrivate with the new value',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          profileRepository: recordingProfileRepository,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(recordingProfileRepository.updateIsPrivateArgs, [true]);
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
    });

    testWidgets('a failed update reverts the toggle and shows an error',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          profileRepository: throwingProfileRepository,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isFalse);
      expect(find.text('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    });
  });
}

class _ThrowingProfileRepository extends RecordingProfileRepository {
  @override
  Future<void> updateIsPrivate({
    required String userId,
    required bool isPrivate,
  }) async {
    throw Exception('network error');
  }
}
