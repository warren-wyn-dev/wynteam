import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/chat/data/shared_content_type.dart';
import 'package:wyn/features/chat/presentation/share_sheet.dart';
import 'package:wyn/features/club/presentation/invite_to_club_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_chat_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_profile_repository.dart';

/// WYN-115: `showShareSheet`'s pre-existing 3 options (แชร์เข้า Chat /
/// แชร์ผ่านระบบมือถือ / คัดลอกลิงก์, WYN-033) must stay unchanged for
/// Drop/Profile -- the new "เชิญจากผู้ติดตาม" row only shows for Club,
/// and only once its two new optional params are actually supplied.
void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  Future<void> openSheet(
    WidgetTester tester, {
    required SharedContentType type,
    bool withFollowerParams = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showShareSheet(
                context,
                chatRepository: RecordingChatRepository(),
                profileRepository: RecordingProfileRepository(),
                sharedContentType: type,
                sharedContentId: 'content-1',
                previewLabel: 'แชร์ทดสอบ',
                nativeShareText: 'https://wynos.online/x/content-1',
                followRepository: withFollowerParams ? RecordingFollowRepository() : null,
                clubName: withFollowerParams ? 'ชมรมทดสอบ' : null,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'club share sheet with followRepository+clubName shows เชิญจากผู้ติดตาม first',
      (tester) async {
    await openSheet(tester, type: SharedContentType.club, withFollowerParams: true);

    expect(find.text('เชิญจากผู้ติดตาม'), findsOneWidget);
    expect(find.text('แชร์เข้า Chat'), findsOneWidget);
    expect(find.text('แชร์ผ่านระบบมือถือ'), findsOneWidget);
    expect(find.text('คัดลอกลิงก์'), findsOneWidget);
  });

  testWidgets('club share sheet without followRepository/clubName falls back '
      'to the original 3 options (regression guard)', (tester) async {
    await openSheet(tester, type: SharedContentType.club, withFollowerParams: false);

    expect(find.text('เชิญจากผู้ติดตาม'), findsNothing);
    expect(find.text('แชร์เข้า Chat'), findsOneWidget);
  });

  testWidgets('drop share sheet never shows เชิญจากผู้ติดตาม, even if the '
      'params were somehow passed', (tester) async {
    await openSheet(tester, type: SharedContentType.drop, withFollowerParams: true);

    expect(find.text('เชิญจากผู้ติดตาม'), findsNothing);
    expect(find.text('แชร์เข้า Chat'), findsOneWidget);
  });

  testWidgets('profile share sheet never shows เชิญจากผู้ติดตาม (WYN-033 regression guard)',
      (tester) async {
    await openSheet(tester, type: SharedContentType.profile, withFollowerParams: true);

    expect(find.text('เชิญจากผู้ติดตาม'), findsNothing);
  });

  testWidgets('tapping เชิญจากผู้ติดตาม opens InviteToClubScreen', (tester) async {
    await openSheet(tester, type: SharedContentType.club, withFollowerParams: true);

    await tester.tap(find.text('เชิญจากผู้ติดตาม'));
    await tester.pumpAndSettle();

    expect(find.byType(InviteToClubScreen), findsOneWidget);
  });
}
