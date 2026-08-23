import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/block/presentation/blocked_list_screen.dart';
import 'package:wyn/features/drop/presentation/recently_deleted_drops_screen.dart';
import 'package:wyn/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:wyn/features/mute/presentation/muted_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/settings/presentation/notification_settings_screen.dart';
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

    // WYN-045's 3 new rows push "ความปลอดภัย" below the 600px test
    // viewport -- scroll it into the built extent, then ensure it's
    // actually within the visible/tappable area (not just mounted at
    // the edge of the cache extent), before tapping. See
    // .wyn/learning/PATTERNS.md.
    final mutedListRow = find.text('บัญชีที่ปิดเสียง');
    await tester.scrollUntilVisible(
      mutedListRow,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(mutedListRow);
    await tester.pumpAndSettle();
    await tester.tap(mutedListRow);
    await tester.pumpAndSettle();

    expect(find.byType(MutedListScreen), findsOneWidget);
  });

  testWidgets('tapping รายการที่ลบ opens RecentlyDeletedDropsScreen (WYN-037)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    // See the scroll comment above -- WYN-045's 3 new rows push this
    // row below the test viewport too.
    await tester.scrollUntilVisible(
      find.text('รายการที่ลบ'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
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

    // See the scroll comment above (tapping บัญชีที่ปิดเสียง) -- WYN-045's 3
    // new rows push "เครื่องมือผู้ดูแล" beyond the test viewport's built
    // extent, so find.text() would find nothing at all without this.
    await tester.scrollUntilVisible(
      find.text('เครื่องมือผู้ดูแล'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('เครื่องมือผู้ดูแล'), findsOneWidget);

    final moderationQueueRow = find.text('คิวตรวจสอบรายงาน');
    await tester.scrollUntilVisible(
      moderationQueueRow,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(moderationQueueRow);
    await tester.pumpAndSettle();
    expect(moderationQueueRow, findsOneWidget);

    await tester.tap(moderationQueueRow);
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

    // See the scroll comment above.
    await tester.scrollUntilVisible(
      find.text('เครื่องมือผู้ดูแล'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
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

  // WYN-044. The section heading and the row's own title share the
  // exact same Thai text ("การแจ้งเตือน"), unlike every other section in
  // this file (e.g. "ความปลอดภัย" heading vs. "บัญชีที่ถูกบล็อก" row) --
  // so `find.text('การแจ้งเตือน')` matches 2 widgets here, and the row
  // itself must be targeted via `find.widgetWithText(ListTile, ...)`
  // rather than a bare text finder.
  group('การแจ้งเตือน section (WYN-044)', () {
    testWidgets(
        'shows both the heading and the row for every platformRole '
        '(unconditional)', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
      ));
      await tester.pumpAndSettle();

      expect(find.text('การแจ้งเตือน'), findsNWidgets(2));
      expect(find.widgetWithText(ListTile, 'การแจ้งเตือน'), findsOneWidget);
    });

    testWidgets('tapping the row opens NotificationSettingsScreen',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'การแจ้งเตือน'));
      await tester.pumpAndSettle();

      expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    });
  });

  // WYN-045, still inside "ความเป็นส่วนตัว" -- 3 new rows right after the
  // Private Account toggle.
  group('Interaction Privacy Controls rows (WYN-045)', () {
    testWidgets('default rendering: all 3 rows summarize to "ทุกคน"',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ใครทักข้อความคุณได้'), findsOneWidget);
      expect(find.text('ใครกล่าวถึงคุณได้'), findsOneWidget);
      expect(find.text('ใครคอมเมนต์โพสต์ของคุณได้'), findsOneWidget);
      expect(find.text('ทุกคน'), findsNWidgets(3));
    });

    testWidgets(
        'opening the picker shows a checkmark on the current value only',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          dmPermission: InteractionPermission.peopleIFollow,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ใครทักข้อความคุณได้'));
      await tester.pumpAndSettle();

      // Exactly one of the 3 options is checked -- the other 2 are not.
      expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
      expect(find.byIcon(Icons.radio_button_unchecked), findsNWidgets(2));

      final checkedTile = find.ancestor(
        of: find.byIcon(Icons.radio_button_checked),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: checkedTile, matching: find.text('คนที่ฉันติดตาม')),
        findsOneWidget,
      );
    });

    testWidgets(
        'selecting a new DM option closes the sheet, updates the row, and '
        'calls updateDmPermission with the new value', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          profileRepository: recordingProfileRepository,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ใครทักข้อความคุณได้'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ไม่มีใครเลย'));
      await tester.pumpAndSettle();

      expect(recordingProfileRepository.updateDmPermissionArgs,
          [InteractionPermission.noOne]);
      // Sheet is closed -- its close icon no longer exists anywhere.
      expect(find.byIcon(Icons.close), findsNothing);
      // The row's own trailing summary now reflects the new value.
      expect(find.text('ไม่มีใครเลย'), findsOneWidget);
    });

    testWidgets(
        'a failed permission update reverts the row and shows an error',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          profileRepository: throwingProfileRepository,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ใครทักข้อความคุณได้'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ไม่มีใครเลย'));
      await tester.pumpAndSettle();

      // Reverted -- all 3 rows (this one included) are back to "ทุกคน".
      expect(find.text('ทุกคน'), findsNWidgets(3));
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

  @override
  Future<void> updateDmPermission({
    required String userId,
    required InteractionPermission value,
  }) async {
    throw Exception('network error');
  }
}
