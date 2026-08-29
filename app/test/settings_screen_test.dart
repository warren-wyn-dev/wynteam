import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/block/presentation/blocked_list_screen.dart';
import 'package:wyn/features/drop/presentation/recently_deleted_drops_screen.dart';
import 'package:wyn/features/legal/presentation/document_viewer_screen.dart';
import 'package:wyn/features/moderation/presentation/moderation_queue_screen.dart';
import 'package:wyn/features/mute/presentation/muted_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/settings/presentation/delete_account_screen.dart';
import 'package:wyn/features/settings/presentation/notification_settings_screen.dart';
import 'package:wyn/features/settings/presentation/settings_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_auth_repository.dart';
import 'support/recording_data_rights_repository.dart';
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
  late RecordingDataRightsRepository recordingDataRightsRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    recordingProfileRepository = RecordingProfileRepository();
    throwingProfileRepository = _ThrowingProfileRepository();
    recordingDataRightsRepository = RecordingDataRightsRepository();
  });

  setUp(() {
    recordingDataRightsRepository.exportMyDataCalls = 0;
    recordingDataRightsRepository.exportError = null;
    recordingDataRightsRepository.exportOverride = null;
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

    testWidgets('a failed permission update reverts the row and shows an error',
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

  // WYN-047 -- "ข้อมูลของฉัน" sits right before "กฎหมาย" (still near the
  // bottom, but not the very last section -- see settings_screen.dart's
  // own comment).
  group('ข้อมูลของฉัน section (WYN-047)', () {
    testWidgets(
        'shows the heading and both rows, positioned right before '
        '"กฎหมาย"', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          dataRightsRepository: recordingDataRightsRepository,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('ข้อมูลของฉัน'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ข้อมูลของฉัน'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ดาวน์โหลดข้อมูลของฉัน'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ดาวน์โหลดข้อมูลของฉัน'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('ลบบัญชี'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('ลบบัญชี'), findsOneWidget);

      // Position check: "ข้อมูลของฉัน" section's own rows appear before
      // "กฎหมาย" in the ListView's child order.
      final listView = tester.widget<ListView>(find.byType(ListView));
      final children = listView.childrenDelegate as SliverChildListDelegate;
      int indexOfText(String text) {
        return children.children.indexWhere((widget) {
          if (widget is Padding && widget.child is Text) {
            return (widget.child as Text).data == text;
          }
          return false;
        });
      }

      final dataRightsHeadingIndex = indexOfText('ข้อมูลของฉัน');
      final legalHeadingIndex = indexOfText('กฎหมาย');
      expect(dataRightsHeadingIndex, greaterThanOrEqualTo(0));
      expect(legalHeadingIndex, greaterThanOrEqualTo(0));
      expect(dataRightsHeadingIndex, lessThan(legalHeadingIndex));
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

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          dataRightsRepository: recordingDataRightsRepository,
        ),
      ));
      await tester.pumpAndSettle();

      final exportRow = find.text('ดาวน์โหลดข้อมูลของฉัน');
      await tester.scrollUntilVisible(
        exportRow,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(exportRow);
      await tester.pumpAndSettle();

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

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          dataRightsRepository: recordingDataRightsRepository,
        ),
      ));
      await tester.pumpAndSettle();

      final exportRow = find.text('ดาวน์โหลดข้อมูลของฉัน');
      await tester.scrollUntilVisible(
        exportRow,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(exportRow);
      await tester.pumpAndSettle();
      await tester.tap(exportRow);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('ดาวน์โหลดข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง'),
          findsOneWidget);
    });

    testWidgets('tapping ลบบัญชี opens DeleteAccountScreen', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          dataRightsRepository: recordingDataRightsRepository,
        ),
      ));
      await tester.pumpAndSettle();

      final deleteRow = find.text('ลบบัญชี');
      await tester.scrollUntilVisible(
        deleteRow,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(deleteRow);
      await tester.pumpAndSettle();
      await tester.tap(deleteRow);
      await tester.pumpAndSettle();

      expect(find.byType(DeleteAccountScreen), findsOneWidget);
    });
  });

  // WYN-046 -- "กฎหมาย" is always the very last section, unconditional on
  // platformRole (unlike "เครื่องมือผู้ดูแล" above). Unlike "การแจ้งเตือน"
  // (WYN-044), none of these 6 row titles collide with the section
  // heading text ("กฎหมาย" itself never appears as a row title), so a
  // plain find.text() per row is unambiguous here.
  group('กฎหมาย section (WYN-046)', () {
    const rowTitles = [
      'ข้อกำหนดการใช้งาน',
      'นโยบายความเป็นส่วนตัว',
      'แนวทางชุมชน',
      'นโยบายลิขสิทธิ์',
      'นโยบายการรายงาน',
      'นโยบายการอุทธรณ์',
    ];

    testWidgets('shows the heading and all 6 document rows', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('กฎหมาย'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('กฎหมาย'), findsOneWidget);

      for (final title in rowTitles) {
        await tester.scrollUntilVisible(
          find.text(title),
          500,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(title), findsOneWidget,
            reason: '$title should be shown');
      }
    });

    for (final title in rowTitles) {
      testWidgets('tapping "$title" opens DocumentViewerScreen',
          (tester) async {
        await tester.pumpWidget(const MaterialApp(
          home:
              SettingsScreen(platformRole: PlatformRole.user, isPrivate: false),
        ));
        await tester.pumpAndSettle();

        final row = find.text(title);
        await tester.scrollUntilVisible(
          row,
          500,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();

        expect(find.byType(DocumentViewerScreen), findsOneWidget);
      });
    }
  });

  // WYN-073 -- moved here from ViewProfileScreen's own-profile header
  // (which used to have a standalone logout IconButton with equal
  // visual weight to the Settings gear itself, next to it). Always the
  // very last row on the page, separated from "กฎหมาย" above.
  group('ออกจากระบบ (WYN-073)', () {
    testWidgets('shows a logout row at the bottom, visually separated '
        'from "กฎหมาย" above it', (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          authRepository: authRepository,
        ),
      ));
      await tester.pumpAndSettle();

      final logoutRow = find.text('ออกจากระบบ');
      await tester.scrollUntilVisible(
        logoutRow,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(logoutRow, findsOneWidget);

      // Below (visually separated from) "กฎหมาย"'s own last row, not
      // interleaved with it -- compares vertical position rather than
      // ListView child-list index, since "กฎหมาย"'s rows are each
      // wrapped in their own `_LegalDocumentTile`, not a bare `ListTile`
      // directly in the list. Scrolling to `logoutRow` (the very last
      // item) already keeps the adjacent `lastLegalDocRow` (2nd-to-last)
      // in view too, so both are checked from this one scroll.
      final lastLegalDocRow = find.text('นโยบายการอุทธรณ์');
      expect(lastLegalDocRow, findsOneWidget);
      expect(
        tester.getTopLeft(logoutRow).dy,
        greaterThan(tester.getTopLeft(lastLegalDocRow).dy),
      );
      // A Divider sits between this row and everything above it.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('tapping it opens a confirmation dialog; canceling signs '
        'out no one', (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          authRepository: authRepository,
        ),
      ));
      await tester.pumpAndSettle();

      final logoutRow = find.text('ออกจากระบบ');
      await tester.scrollUntilVisible(
        logoutRow,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(logoutRow);
      await tester.pumpAndSettle();
      await tester.tap(logoutRow);
      await tester.pumpAndSettle();

      expect(find.text('ออกจากระบบ?'), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(authRepository.signOutCalls, 0);
    });

    testWidgets(
        'confirming calls signOut (best-effort push-token unregister '
        'never blocks it)', (tester) async {
      final authRepository = RecordingAuthRepository();
      addTearDown(authRepository.dispose);

      await tester.pumpWidget(MaterialApp(
        home: SettingsScreen(
          platformRole: PlatformRole.user,
          isPrivate: false,
          authRepository: authRepository,
        ),
      ));
      await tester.pumpAndSettle();

      final logoutRow = find.text('ออกจากระบบ');
      await tester.scrollUntilVisible(
        logoutRow,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(logoutRow);
      await tester.pumpAndSettle();
      await tester.tap(logoutRow);
      await tester.pumpAndSettle();

      // The confirm button shares its label with the row itself
      // ("ออกจากระบบ") -- the dialog's own title text ("ออกจากระบบ?")
      // disambiguates which of the two remaining "ออกจากระบบ" texts is
      // the button.
      await tester.tap(find.widgetWithText(TextButton, 'ออกจากระบบ'));
      // Not pumpAndSettle -- the success path deliberately leaves
      // _isSigningOut true (no success state to show -- AuthGate is
      // what navigates away once the session clears, same posture as
      // DeleteAccountScreen's own success path), so the row's
      // CircularProgressIndicator keeps its indeterminate animation
      // running and pumpAndSettle would never terminate. A handful of
      // plain pump()s is enough to flush the (real, non-Timer-based)
      // async chain: unregisterCurrentDevice() (a same-microtask no-op
      // since Firebase isn't initialized in tests) -> signOut().
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(authRepository.signOutCalls, 1);
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
