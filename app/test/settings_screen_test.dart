import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/block/presentation/blocked_list_screen.dart';
import 'package:wyn/features/drop/presentation/recently_deleted_drops_screen.dart';
import 'package:wyn/features/follow/presentation/close_friends_screen.dart';
import 'package:wyn/features/legal/presentation/document_viewer_screen.dart';
import 'package:wyn/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:wyn/features/mute/presentation/muted_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/settings/presentation/delete_account_screen.dart';
import 'package:wyn/features/settings/presentation/notification_settings_screen.dart';
import 'package:wyn/features/settings/presentation/settings_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_data_rights_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_profile_repository.dart';

/// Restyled to 11-settings.tsx's exact 7-row list (see settings_screen.dart's
/// own doc comment): the top-level SettingsScreen now only shows บัญชี /
/// ความเป็นส่วนตัว / การแจ้งเตือน / ธีมเข้ม (disabled) / ช่วยเหลือ (disabled)
/// / ข้อกำหนดและความเป็นส่วนตัว / ออกจากระบบ, with all the pre-existing real
/// functionality (Blocked/Muted/Recently Deleted, admin tools, data
/// export/delete account, the Private Account toggle + 3 permission rows,
/// the 6 legal documents) relocated one level deeper behind "บัญชี" /
/// "ความเป็นส่วนตัว" / "ข้อกำหนดและความเป็นส่วนตัว" -- these tests drill
/// into that sub-screen first, then assert what settings_screen_test.dart
/// used to assert directly on SettingsScreen itself.
void main() {
  // Constructed in setUpAll (not inline in a test body) so the
  // SupabaseClient each RecordingProfileRepository wraps -- and the
  // GoTrue auto-refresh timer that starts with it -- isn't attributed to
  // a single test's FakeAsync zone and flagged as a leaked timer at
  // teardown. Mirrors every other RecordingXRepository across this
  // project's test suite (e.g. create_drop_screen_test.dart).
  late RecordingProfileRepository recordingProfileRepository;
  late _ThrowingProfileRepository throwingProfileRepository;
  late RecordingDataRightsRepository recordingDataRightsRepository;
  // WYN-097 -- same setUpAll discipline as every repo above.
  late RecordingFollowRepository recordingFollowRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    recordingProfileRepository = RecordingProfileRepository();
    throwingProfileRepository = _ThrowingProfileRepository();
    recordingDataRightsRepository = RecordingDataRightsRepository();
    recordingFollowRepository = RecordingFollowRepository();
  });

  setUp(() {
    recordingDataRightsRepository.exportMyDataCalls = 0;
    recordingDataRightsRepository.exportError = null;
    recordingDataRightsRepository.exportOverride = null;
  });

  testWidgets('shows the 7-row mockup structure: 3 groups + a separated '
      'logout row, nothing else', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    // "บัญชี" and "ช่วยเหลือ" each appear twice -- once as the GroupLabel
    // heading, once as the Row label directly under it (11-settings.tsx's
    // own mockup content: `<GroupLabel>บัญชี</GroupLabel>` sits directly
    // above `{ label: "บัญชี" }`, same for "ช่วยเหลือ").
    expect(find.text('บัญชี'), findsNWidgets(2));
    expect(find.text('ความเป็นส่วนตัว'), findsOneWidget);
    expect(find.text('การแจ้งเตือน'), findsOneWidget);
    expect(find.text('ธีมเข้ม'), findsOneWidget);
    expect(find.text('ช่วยเหลือ'), findsNWidgets(2));
    expect(find.text('ข้อกำหนดและความเป็นส่วนตัว'), findsOneWidget);
    expect(find.text('ออกจากระบบ'), findsOneWidget);
    // None of the relocated sub-screen content leaks onto the top-level
    // page itself.
    expect(find.text('บัญชีที่ถูกบล็อก'), findsNothing);
    expect(find.text('บัญชีส่วนตัว (Private Account)'), findsNothing);
    expect(find.text('ข้อกำหนดการใช้งาน'), findsNothing);
  });

  testWidgets('"ธีมเข้ม" and "ช่วยเหลือ" are disabled -- no chevron, no tap '
      'target', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ธีมเข้ม'));
    await tester.pumpAndSettle();
    // No navigation happened -- still on SettingsScreen.
    expect(find.byType(SettingsScreen), findsOneWidget);

    // "ช่วยเหลือ" is ambiguous (GroupLabel + Row share the same text) --
    // only the Row is wrapped in an InkWell.
    await tester.tap(find.widgetWithText(InkWell, 'ช่วยเหลือ'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('tapping "การแจ้งเตือน" opens NotificationSettingsScreen '
      'directly (unchanged, not nested)', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('การแจ้งเตือน'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });

  testWidgets('shows "ออกจากระบบ" as the very last row on the page',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ออกจากระบบ'), findsOneWidget);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final children =
        (listView.childrenDelegate as SliverChildListDelegate).children;
    // The last child is the separated logout section (a Padding wrapping
    // a Divider + the logout row), not a bare row like the others.
    expect(
      find.descendant(
        of: find.byWidget(children.last),
        matching: find.text('ออกจากระบบ'),
      ),
      findsOneWidget,
    );
  });

  group('WYN-082: logout confirmation', () {
    testWidgets(
        'tapping "ออกจากระบบ" shows a confirm dialog with Founder\'s exact '
        'copy, instead of signing out immediately', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ออกจากระบบ'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('ออกจากระบบบัญชีของคุณใช่ไหม'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'ยกเลิก'), findsOneWidget);
      // 'ออกจากระบบ' now finds 2: the row underneath (dimmed by the
      // dialog barrier, still in the tree) and the dialog's own action.
      expect(find.text('ออกจากระบบ'), findsNWidgets(2));
      // Still on SettingsScreen -- confirming didn't happen, so no
      // sign-out/navigation occurred yet.
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('tapping "ยกเลิก" dismisses the dialog and stays signed in',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ออกจากระบบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('ออกจากระบบ'), findsOneWidget,
          reason: 'back to just the one row, dialog gone');
    });
  });

  Future<void> openAccountManagement(
    WidgetTester tester, {
    PlatformRole platformRole = PlatformRole.user,
    RecordingDataRightsRepository? dataRightsRepository,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        platformRole: platformRole,
        isPrivate: false,
        dataRightsRepository: dataRightsRepository,
      ),
    ));
    await tester.pumpAndSettle();
    // "บัญชี" is ambiguous (GroupLabel + Row share the same text) -- only
    // the Row is wrapped in an InkWell.
    await tester.tap(find.widgetWithText(InkWell, 'บัญชี'));
    await tester.pumpAndSettle();
  }

  group('"บัญชี" sub-screen', () {
    testWidgets('ความปลอดภัย section shows Blocked List, Muted List, and '
        'รายการที่ลบ rows', (tester) async {
      await openAccountManagement(tester);

      expect(find.text('ความปลอดภัย'), findsOneWidget);
      expect(find.text('บัญชีที่ถูกบล็อก'), findsOneWidget);
      expect(find.text('บัญชีที่ปิดเสียง'), findsOneWidget);
      expect(find.text('รายการที่ลบ'), findsOneWidget);
    });

    testWidgets('tapping บัญชีที่ถูกบล็อก opens BlockedListScreen',
        (tester) async {
      await openAccountManagement(tester);

      await tester.tap(find.text('บัญชีที่ถูกบล็อก'));
      await tester.pumpAndSettle();

      expect(find.byType(BlockedListScreen), findsOneWidget);
    });

    testWidgets('tapping บัญชีที่ปิดเสียง opens MutedListScreen',
        (tester) async {
      await openAccountManagement(tester);

      await tester.tap(find.text('บัญชีที่ปิดเสียง'));
      await tester.pumpAndSettle();

      expect(find.byType(MutedListScreen), findsOneWidget);
    });

    testWidgets('tapping รายการที่ลบ opens RecentlyDeletedDropsScreen '
        '(WYN-037)', (tester) async {
      await openAccountManagement(tester);

      await tester.tap(find.text('รายการที่ลบ'));
      await tester.pumpAndSettle();

      expect(find.byType(RecentlyDeletedDropsScreen), findsOneWidget);
    });

    // WYN-029, Screen 1 -- an ordinary user must not see even an empty
    // "เครื่องมือผู้ดูแล" heading, per the Product spec's "ไม่ปรากฏในเมนูของ
    // ผู้ใช้ทั่วไป".
    testWidgets(
        'platformRole == user never shows the "เครื่องมือผู้ดูแล" section at '
        'all', (tester) async {
      await openAccountManagement(tester, platformRole: PlatformRole.user);

      expect(find.text('เครื่องมือผู้ดูแล'), findsNothing);
      expect(find.text('คิวตรวจสอบรายงาน'), findsNothing);
    });

    testWidgets(
        'platformRole == moderator shows the section and opens '
        'ModerationQueueScreen', (tester) async {
      await openAccountManagement(tester,
          platformRole: PlatformRole.moderator);

      expect(find.text('เครื่องมือผู้ดูแล'), findsOneWidget);
      final moderationQueueRow = find.text('คิวตรวจสอบรายงาน');
      expect(moderationQueueRow, findsOneWidget);

      await tester.tap(moderationQueueRow);
      await tester.pumpAndSettle();

      expect(find.byType(ModerationQueueScreen), findsOneWidget);
    });

    testWidgets(
        'platformRole == admin also shows the section (admin sees '
        'everything moderator does)', (tester) async {
      await openAccountManagement(tester, platformRole: PlatformRole.admin);

      expect(find.text('เครื่องมือผู้ดูแล'), findsOneWidget);
    });

    group('ข้อมูลของฉัน section (WYN-047)', () {
      testWidgets('shows the heading and both rows', (tester) async {
        await openAccountManagement(tester,
            dataRightsRepository: recordingDataRightsRepository);

        expect(find.text('ข้อมูลของฉัน'), findsOneWidget);
        expect(find.text('ดาวน์โหลดข้อมูลของฉัน'), findsOneWidget);
        expect(find.text('ลบบัญชี'), findsOneWidget);
      });

      // Deliberately never resolves [completer] -- once exportMyData()
      // resolves, _exportData() goes on to call the real
      // SharePlus.instance.share() to actually open the OS share sheet,
      // which isn't mockable/testable in a plain widget test (no
      // platform channel handler registered here) and, empirically,
      // does not reject/settle within a bounded handful of pump()s
      // either -- so this test only proves the loading state appears
      // and the repository call happened, leaving the export
      // permanently "in flight" rather than ever reaching the
      // share-sheet call. The complementary "hides again" half of this
      // behavior is proven by the failed-export test below instead,
      // whose failure path returns from _exportData() before ever
      // calling SharePlus.
      testWidgets(
          'tapping ดาวน์โหลดข้อมูลของฉัน shows a loading indicator while in '
          'flight and calls exportMyData', (tester) async {
        final completer = Completer<void>();
        recordingDataRightsRepository.exportOverride = () => completer.future;
        // Never completed -- see this testWidgets' own doc comment above.

        await openAccountManagement(tester,
            dataRightsRepository: recordingDataRightsRepository);

        final exportRow = find.text('ดาวน์โหลดข้อมูลของฉัน');
        expect(find.byType(CircularProgressIndicator), findsNothing);
        await tester.tap(exportRow);
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(recordingDataRightsRepository.exportMyDataCalls, 1);
      });

      testWidgets(
          'a failed export hides the loading indicator and shows an error '
          'SnackBar', (tester) async {
        recordingDataRightsRepository.exportError = Exception('network error');

        await openAccountManagement(tester,
            dataRightsRepository: recordingDataRightsRepository);

        final exportRow = find.text('ดาวน์โหลดข้อมูลของฉัน');
        await tester.tap(exportRow);
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text('ดาวน์โหลดข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง'),
            findsOneWidget);
      });

      testWidgets('tapping ลบบัญชี opens DeleteAccountScreen', (tester) async {
        await openAccountManagement(tester,
            dataRightsRepository: recordingDataRightsRepository);

        await tester.tap(find.text('ลบบัญชี'));
        await tester.pumpAndSettle();

        expect(find.byType(DeleteAccountScreen), findsOneWidget);
      });
    });
  });

  Future<void> openPrivacyScreen(
    WidgetTester tester, {
    bool isPrivate = false,
    InteractionPermission dmPermission = InteractionPermission.everyone,
    LikesVisibility likesVisibility = LikesVisibility.everyone,
    RecordingProfileRepository? profileRepository,
    RecordingFollowRepository? followRepository,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        platformRole: PlatformRole.user,
        isPrivate: isPrivate,
        dmPermission: dmPermission,
        likesVisibility: likesVisibility,
        profileRepository: profileRepository,
        followRepository: followRepository,
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ความเป็นส่วนตัว'));
    await tester.pumpAndSettle();
  }

  // WYN-039, Screen 1.
  group('"ความเป็นส่วนตัว" sub-screen', () {
    testWidgets('shows the Private Account toggle, initialized from '
        'isPrivate', (tester) async {
      await openPrivacyScreen(tester, isPrivate: true);

      expect(find.text('บัญชีส่วนตัว (Private Account)'), findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
    });

    testWidgets('flipping the toggle calls updateIsPrivate with the new '
        'value', (tester) async {
      await openPrivacyScreen(tester,
          profileRepository: recordingProfileRepository);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(recordingProfileRepository.updateIsPrivateArgs, [true]);
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue);
    });

    testWidgets('a failed update reverts the toggle and shows an error',
        (tester) async {
      await openPrivacyScreen(tester,
          profileRepository: throwingProfileRepository);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isFalse);
      expect(find.text('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    });

    // WYN-045 -- 3 rows right after the Private Account toggle.
    group('Interaction Privacy Controls rows (WYN-045)', () {
      testWidgets('default rendering: all 3 rows summarize to "ทุกคน"',
          (tester) async {
        await openPrivacyScreen(tester);

        expect(find.text('ใครทักข้อความคุณได้'), findsOneWidget);
        expect(find.text('ใครกล่าวถึงคุณได้'), findsOneWidget);
        expect(find.text('ใครคอมเมนต์โพสต์ของคุณได้'), findsOneWidget);
        // 4, not 3 -- WYN-099's "ใครเห็นสิ่งที่คุณถูกใจได้" row (below
        // these 3) also defaults to "ทุกคน".
        expect(find.text('ทุกคน'), findsNWidgets(4));
      });

      testWidgets(
          'opening the picker shows a checkmark on the current value only',
          (tester) async {
        await openPrivacyScreen(tester,
            dmPermission: InteractionPermission.peopleIFollow);

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
        await openPrivacyScreen(tester,
            profileRepository: recordingProfileRepository);

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
        await openPrivacyScreen(tester,
            profileRepository: throwingProfileRepository);

        await tester.tap(find.text('ใครทักข้อความคุณได้'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('ไม่มีใครเลย'));
        await tester.pumpAndSettle();

        // Reverted -- all 3 rows (this one included), plus WYN-099's
        // likes-visibility row, are back to/still "ทุกคน".
        expect(find.text('ทุกคน'), findsNWidgets(4));
        expect(find.text('เปลี่ยนไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
      });
    });

    // WYN-097 -- entry point to CloseFriendsScreen, right after Private
    // Account.
    group('"เพื่อนที่สนิท" row (WYN-097)', () {
      testWidgets('shows the row with its subtitle', (tester) async {
        await openPrivacyScreen(tester);

        expect(find.text('เพื่อนที่สนิท'), findsOneWidget);
        expect(find.text('จัดการรายชื่อเพื่อนที่สนิทของคุณ'), findsOneWidget);
      });

      testWidgets('tapping it opens CloseFriendsScreen without the '
          'welcome banner (this entry point is deliberate, unlike the '
          'first-time-from-audience-picker one)', (tester) async {
        await openPrivacyScreen(tester,
            followRepository: recordingFollowRepository);

        await tester.tap(find.text('เพื่อนที่สนิท'));
        await tester.pumpAndSettle();

        expect(find.byType(CloseFriendsScreen), findsOneWidget);
        expect(
          find.text('คุณยังไม่มีเพื่อนที่สนิท เลือกจากรายชื่อเพื่อนของคุณได้เลย'),
          findsNothing,
        );
      });
    });

    // WYN-099 -- 4th row, own picker (ทุกคน/เพื่อน/เฉพาะฉัน).
    group('"ใครเห็นสิ่งที่คุณถูกใจได้" row (WYN-099)', () {
      testWidgets('default rendering summarizes to "ทุกคน"', (tester) async {
        await openPrivacyScreen(tester);

        expect(find.text('ใครเห็นสิ่งที่คุณถูกใจได้'), findsOneWidget);
        // 4 "ทุกคน" now: the 3 InteractionPermission rows + this one.
        expect(find.text('ทุกคน'), findsNWidgets(4));
      });

      testWidgets(
          'selecting "เฉพาะฉัน" closes the sheet, updates the row, and '
          'calls updateLikesVisibility', (tester) async {
        await openPrivacyScreen(tester,
            profileRepository: recordingProfileRepository);

        await tester.tap(find.text('ใครเห็นสิ่งที่คุณถูกใจได้'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('เฉพาะฉัน').last);
        await tester.pumpAndSettle();

        expect(recordingProfileRepository.updateLikesVisibilityArgs,
            [LikesVisibility.onlyMe]);
        expect(find.text('เฉพาะฉัน'), findsOneWidget);
      });

      testWidgets('opening the picker with likesVisibility == friends '
          'shows a checked radio on "เพื่อน" only', (tester) async {
        await openPrivacyScreen(tester,
            likesVisibility: LikesVisibility.friends);

        await tester.tap(find.text('ใครเห็นสิ่งที่คุณถูกใจได้'));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
        final checkedTile = find.ancestor(
          of: find.byIcon(Icons.radio_button_checked),
          matching: find.byType(ListTile),
        );
        expect(find.descendant(of: checkedTile, matching: find.text('เพื่อน')),
            findsOneWidget);
      });
    });
  });

  // WYN-046 -- 6 legal documents, now behind "ข้อกำหนดและความเป็นส่วนตัว".
  group('"ข้อกำหนดและความเป็นส่วนตัว" sub-screen', () {
    const rowTitles = [
      'ข้อกำหนดการใช้งาน',
      'นโยบายความเป็นส่วนตัว',
      'แนวทางชุมชน',
      'นโยบายลิขสิทธิ์',
      'นโยบายการรายงาน',
      'นโยบายการอุทธรณ์',
    ];

    Future<void> openLegalScreen(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home:
            SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ข้อกำหนดและความเป็นส่วนตัว'));
      await tester.pumpAndSettle();
    }

    testWidgets('shows all 6 document rows', (tester) async {
      await openLegalScreen(tester);

      for (final title in rowTitles) {
        expect(find.text(title), findsOneWidget, reason: '$title should be shown');
      }
    });

    for (final title in rowTitles) {
      testWidgets('tapping "$title" opens DocumentViewerScreen',
          (tester) async {
        await openLegalScreen(tester);

        await tester.tap(find.text(title));
        await tester.pumpAndSettle();

        expect(find.byType(DocumentViewerScreen), findsOneWidget);
      });
    }
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
