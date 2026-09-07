import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_invite_link.dart';
import 'package:wyn/features/club/presentation/club_invite_preview_screen.dart';
import 'package:wyn/features/club/presentation/club_page.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// WYN-136 -- `ClubInvitePreviewScreen`, opened from a `/club-invite/:code`
/// deep link. See .wyn/docs/design/wyn-136-club-invite-link.md.
void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  late RecordingClubRepository clubRepo;
  // A second repository, its own `club` set at construction time (that
  // field is `final`) -- needed only by the "tapping เข้าร่วม..." test
  // below, whose ClubPage destination needs somewhere real to load.
  // Built here in setUp() (not inline inside that testWidgets body) so
  // the SupabaseClient it wraps -- and the GoTrue auto-refresh Timer
  // that starts with it -- isn't attributed to that one test's own
  // FakeAsync zone and flagged as a leaked timer at teardown. Mirrors
  // every other RecordingXRepository across this project's test suite
  // (e.g. root_shell_test.dart's own identical comment).
  late RecordingClubRepository joinedClubRepo;
  late RecordingClubPostRepository clubPostRepo;

  setUp(() {
    clubRepo = RecordingClubRepository();
    joinedClubRepo = RecordingClubRepository(
      club: Club(
        id: 'club-1',
        name: 'Test Club',
        privacy: ClubPrivacy.public,
        ownerId: 'owner-1',
        createdAt: DateTime.now(),
        memberCount: 4,
      ),
    );
    clubPostRepo = RecordingClubPostRepository();
  });

  Widget buildScreen({String code = 'AbCd12EfGh'}) => MaterialApp(
        home: ClubInvitePreviewScreen(
          code: code,
          clubRepository: clubRepo,
          clubPostRepository: clubPostRepo,
        ),
      );

  testWidgets('valid link: shows the club preview card + "เข้าร่วม" button',
      (tester) async {
    clubRepo.previewInviteLinkResult = const ClubInvitePreview(
      status: ClubInviteLinkStatus.valid,
      clubId: 'club-1',
      clubName: 'Test Club',
      clubPrivacy: 'public',
    );
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(clubRepo.lastPreviewInviteLinkCode, 'AbCd12EfGh');
    expect(find.text('Test Club'), findsOneWidget);
    expect(find.text('Public Club'), findsOneWidget);
    expect(find.text('เข้าร่วม'), findsOneWidget);
  });

  testWidgets('valid link for a Private Club shows the Private badge',
      (tester) async {
    clubRepo.previewInviteLinkResult = const ClubInvitePreview(
      status: ClubInviteLinkStatus.valid,
      clubId: 'club-1',
      clubName: 'Secret Club',
      clubPrivacy: 'private',
    );
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Private Club'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets(
      'tapping เข้าร่วม calls redeemInviteLink then replaces this screen '
      'with ClubPage', (tester) async {
    joinedClubRepo.previewInviteLinkResult = const ClubInvitePreview(
      status: ClubInviteLinkStatus.valid,
      clubId: 'club-1',
      clubName: 'Test Club',
      clubPrivacy: 'public',
    );
    joinedClubRepo.redeemInviteLinkResult = 'club-1';
    await tester.pumpWidget(MaterialApp(
      home: ClubInvitePreviewScreen(
        code: 'AbCd12EfGh',
        clubRepository: joinedClubRepo,
        clubPostRepository: clubPostRepo,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('เข้าร่วม'));
    await tester.pumpAndSettle();

    expect(joinedClubRepo.lastRedeemInviteLinkCode, 'AbCd12EfGh');
    expect(find.byType(ClubPage), findsOneWidget);
    expect(find.byType(ClubInvitePreviewScreen), findsNothing);
  });

  testWidgets('a failed redeem keeps this screen and shows an inline error',
      (tester) async {
    clubRepo.previewInviteLinkResult = const ClubInvitePreview(
      status: ClubInviteLinkStatus.valid,
      clubId: 'club-1',
      clubName: 'Test Club',
      clubPrivacy: 'public',
    );
    clubRepo.redeemInviteLinkError = Exception('You have been banned from this club');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('เข้าร่วม'));
    await tester.pumpAndSettle();

    expect(find.text('เข้าร่วมไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.byType(ClubInvitePreviewScreen), findsOneWidget);
    expect(find.byType(ClubPage), findsNothing);
  });

  for (final entry in {
    ClubInviteLinkStatus.expired: 'ลิงก์เชิญนี้หมดอายุแล้ว',
    ClubInviteLinkStatus.revoked: 'ลิงก์เชิญนี้ถูกเพิกถอนแล้ว',
    ClubInviteLinkStatus.exhausted: 'ลิงก์เชิญนี้ถูกใช้งานครบจำนวนแล้ว',
    ClubInviteLinkStatus.notFound: 'ไม่พบลิงก์เชิญนี้',
  }.entries) {
    testWidgets(
        '${entry.key} shows "${entry.value}" with no "เข้าร่วม" button, '
        'and a way back to WYN', (tester) async {
      clubRepo.previewInviteLinkResult = ClubInvitePreview(status: entry.key);
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      expect(find.text(entry.value), findsOneWidget);
      expect(find.text('เข้าร่วม'), findsNothing);
      expect(find.text('ไปที่ WYN'), findsOneWidget);
    });
  }

  testWidgets('a preview fetch failure falls back to the "not_found" '
      'treatment, not a crash', (tester) async {
    clubRepo.fetchInviteLinksError = null; // unrelated -- documenting intent
    clubRepo.previewInviteLinkError = Exception('network error');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบลิงก์เชิญนี้'), findsOneWidget);
    expect(find.text('เข้าร่วม'), findsNothing);
  });
}
