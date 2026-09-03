import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/presentation/club_page.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for ClubPage's 3-state Join button and role-gated
/// More menu, per .wyn/docs/design/wyn-014-club-core.md, Screen 3.
void main() {
  final club = Club(
    id: 'club-1',
    name: 'Test Club',
    privacy: ClubPrivacy.public,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 4,
  );

  ClubMember membership({required ClubMemberRole role, required ClubMemberStatus status}) =>
      ClubMember(
        clubId: club.id,
        userId: 'viewer',
        username: 'viewer',
        role: role,
        status: status,
        createdAt: DateTime.now(),
      );

  // Built in setUp(), never inline inside testWidgets -- see
  // .wyn/learning/PATTERNS.md.
  late RecordingClubRepository notJoinedRepo;
  late RecordingClubRepository pendingRepo;
  late RecordingClubRepository approvedMemberRepo;
  late RecordingClubRepository ownerRepo;
  late RecordingClubPostRepository clubPostRepo;
  // Beta3 -- built in setUp() with every other repo, never inline in a
  // testWidgets body: a fresh RecordingClubRepository constructs a
  // SupabaseClient whose GoTrue auto-refresh timer would otherwise be
  // attributed to that one test's FakeAsync zone (.wyn/learning/
  // PATTERNS.md).
  late RecordingClubRepository withCoverRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    notJoinedRepo = RecordingClubRepository(club: club, myMembership: null);
    pendingRepo = RecordingClubRepository(
      club: club,
      myMembership: membership(role: ClubMemberRole.member, status: ClubMemberStatus.pending),
    );
    approvedMemberRepo = RecordingClubRepository(
      club: club,
      myMembership: membership(role: ClubMemberRole.member, status: ClubMemberStatus.approved),
    );
    ownerRepo = RecordingClubRepository(
      club: club,
      myMembership: membership(role: ClubMemberRole.owner, status: ClubMemberStatus.approved),
    );
    clubPostRepo = RecordingClubPostRepository();
    withCoverRepo = RecordingClubRepository(
      club: Club(
        id: 'club-cover',
        name: 'Cover Club',
        privacy: ClubPrivacy.public,
        ownerId: 'owner-1',
        createdAt: DateTime.now(),
        memberCount: 4,
        coverUrl: 'https://example.supabase.co/clubs/cover.jpg',
      ),
      myMembership: null,
    );
  });

  Future<void> pumpPage(WidgetTester tester, RecordingClubRepository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClubPage(
          clubRepository: repo,
          clubPostRepository: clubPostRepo,
          clubId: club.id,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows "เข้าร่วม" as a filled (primary-weight) button when not a member, and joining '
      'calls joinClub', (tester) async {
    await pumpPage(tester, notJoinedRepo);

    final joinButton = find.byKey(const Key('club-header-join-button'));
    expect(find.descendant(of: joinButton, matching: find.text('เข้าร่วม')), findsOneWidget);
    // WYN-058: "เข้าร่วม" is the page's primary action, elevated to
    // FilledButton (not the same OutlinedButton as every other
    // secondary action) -- see
    // .wyn/docs/design/wyn-057-058-club-create-and-page-visual-polish.md.
    expect(tester.widget(joinButton), isA<FilledButton>());
    await tester.tap(joinButton);
    await tester.pumpAndSettle();

    expect(notJoinedRepo.joinClubCalls, 1);
  });

  testWidgets('shows a disabled "รออนุมัติ" while a join request is pending', (tester) async {
    await pumpPage(tester, pendingRepo);

    expect(find.text('รออนุมัติ'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(
      find.ancestor(of: find.text('รออนุมัติ'), matching: find.byType(OutlinedButton)),
    );
    expect(button.onPressed, isNull);
    // WYN-058: a disabled/non-actionable state shouldn't use the brand
    // (primary/cyan) color -- "รออนุมัติ" now matches "เข้าร่วมแล้ว"'s
    // neutral `outline` color instead of the `primary` it used before.
    final expectedColor = Theme.of(tester.element(find.text('รออนุมัติ'))).colorScheme.outline;
    expect(button.style?.foregroundColor?.resolve(<WidgetState>{}), expectedColor);
  });

  testWidgets('shows "เข้าร่วมแล้ว" for an approved member (still OutlinedButton), and '
      'confirming Leave calls leaveClub', (tester) async {
    await pumpPage(tester, approvedMemberRepo);

    expect(find.text('เข้าร่วมแล้ว'), findsOneWidget);
    final joinButton = find.byKey(const Key('club-header-join-button'));
    expect(tester.widget(joinButton), isA<OutlinedButton>());
    await tester.tap(find.text('เข้าร่วมแล้ว'));
    await tester.pumpAndSettle();

    // Confirmation dialog appears -- confirm leaving.
    expect(find.text('ออกจาก Club?'), findsOneWidget);
    await tester.tap(find.text('ออกจาก Club'));
    await tester.pumpAndSettle();

    expect(approvedMemberRepo.leaveClubCalls, 1);
  });

  testWidgets('More menu offers Edit Info/Change Privacy/Manage Members for the Owner',
      (tester) async {
    await pumpPage(tester, ownerRepo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขข้อมูล Club'), findsOneWidget);
    expect(find.text('เปลี่ยนความเป็นส่วนตัว'), findsOneWidget);
    expect(find.text('จัดการสิทธิ์สมาชิก'), findsOneWidget);
    expect(find.text('ออกจาก Club'), findsNothing);
  });

  testWidgets('More menu offers only Leave/Report for a plain approved member', (tester) async {
    await pumpPage(tester, approvedMemberRepo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('ออกจาก Club'), findsOneWidget);
    expect(find.text('รายงาน Club'), findsOneWidget);
    expect(find.text('แก้ไขข้อมูล Club'), findsNothing);
    expect(find.text('เปลี่ยนความเป็นส่วนตัว'), findsNothing);
    expect(find.text('จัดการสิทธิ์สมาชิก'), findsNothing);
  });

  testWidgets('More menu offers only Report for a non-member', (tester) async {
    await pumpPage(tester, notJoinedRepo);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('รายงาน Club'), findsOneWidget);
    expect(find.text('ออกจาก Club'), findsNothing);
    expect(find.text('แก้ไขข้อมูล Club'), findsNothing);
  });
  group('Beta4 §8.3 -- the Club banner carries the identity image', () {
    // History, because this is a reversal and the reason matters.
    //
    // Beta3 (Founder, 2026-09-03) removed the uploaded image from this
    // strip. The reason was a real defect: the banner *swapped* between
    // two unrelated designs depending on whether the owner happened to
    // have picked a photo, and the Club's own name disappeared in the
    // case where they had -- the name was drawn only on the generated
    // variant.
    //
    // Beta4 §8.3 asks for the identity image back on this page. So it is
    // back with that defect fixed rather than reintroduced: the image is
    // a background layer under the same eyebrow and name the generated
    // variant draws, over a scrim. There is one banner design now, not
    // two. The tests below pin both halves -- the image appears, and the
    // name never stops appearing.
    testWidgets(
        'a Club with an image shows it, and still shows the eyebrow and '
        'the Club name over it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClubPage(
            clubRepository: withCoverRepo,
            clubPostRepository: clubPostRepo,
            clubId: 'club-cover',
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byKey(const Key('club_banner_image')), findsOneWidget);
      // The exact thing Beta3 removed the photo over: with the photo
      // showing, the Club still says which Club it is.
      expect(find.text('CLUB'), findsOneWidget);
      expect(find.text('Cover Club'), findsWidgets);
    });

    testWidgets(
        'a Club with no image still gets the generated background, with '
        'the same eyebrow and name -- one design, not two', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ClubPage(
            clubRepository: notJoinedRepo,
            clubPostRepository: clubPostRepo,
            clubId: 'club-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byKey(const Key('club_banner_image')), findsNothing);
      expect(find.text('CLUB'), findsOneWidget);
      expect(find.text('Test Club'), findsWidgets);
    });

    testWidgets(
        'a pre-Beta4 Club, whose one image lives in cover_url, still shows '
        'it (Beta4 §8.1)', (tester) async {
      // withCoverRepo's Club has coverUrl set and iconUrl null -- the
      // exact shape of every Club created before Beta4, since the old
      // create form only ever wrote cover_url. Without
      // identityImageUrl's fallback these would all have gone
      // image-less the day Beta4 shipped.
      await tester.pumpWidget(
        MaterialApp(
          home: ClubPage(
            clubRepository: withCoverRepo,
            clubPostRepository: clubPostRepo,
            clubId: 'club-cover',
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byKey(const Key('club_banner_image')), findsOneWidget);
    });
  });

}
