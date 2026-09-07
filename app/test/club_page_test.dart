import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_insights.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/presentation/club_invite_links_screen.dart';
import 'package:wyn/features/club/presentation/club_page.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_channel_chat_repository.dart';
import 'support/recording_club_event_repository.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_developer_access_service.dart';

/// Regression tests for ClubPage's 3-state Join button, role-gated More
/// menu, and its 3-tab structure (โพสต์/แชท/เกี่ยวกับ) per the Founder's
/// tab-restructuring decision, 2026-09-07 -- see
/// .wyn/docs/design/wyn-014-club-core.md, Screen 3, and
/// widgets/club_about_tab.dart's own doc comment for what merged into
/// "เกี่ยวกับ" (Members/Events/Insights, reached via an internal
/// segmented switcher rather than more top-level tabs).
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
  late RecordingClubEventRepository clubEventRepo;
  // Every ClubPage test must inject this -- ClubChatTab (built eagerly as
  // a TabBarView child whenever `showChat` is true, regardless of which
  // tab is selected) subscribes to it for the unread badge, and a real
  // ClubChannelChatRepository's subscribe() attempts a genuine WebSocket
  // connection that leaves a pending Timer behind (.wyn/learning/
  // PATTERNS.md).
  late RecordingClubChannelChatRepository clubChannelChatRepo;
  // Beta3 -- built in setUp() with every other repo, never inline in a
  // testWidgets body: a fresh RecordingClubRepository constructs a
  // SupabaseClient whose GoTrue auto-refresh timer would otherwise be
  // attributed to that one test's FakeAsync zone (.wyn/learning/
  // PATTERNS.md).
  late RecordingClubRepository withCoverRepo;
  // Same reasoning as withCoverRepo above -- built in setUp(), not inline
  // inside a WYN-116 testWidgets body.
  late RecordingClubRepository mutedMemberRepo;
  // ClubPage's own `_load()` now calls `.isDeveloperAccount()` directly
  // (to decide `showChat`), on top of ClubPostsTab/ClubAboutTab's
  // "สมาชิก" segment doing the same for their own badge gating -- always
  // inject the Recording double, or all 3 would attempt a genuine RPC
  // call against this suite's fake Supabase project. Defaults to `true`
  // so every pre-existing test below still sees exactly what it did
  // before "แชท" became a top-level tab; the dedicated "Chat tab
  // (staged rollout)" group below overrides it per-test.
  late RecordingDeveloperAccessService developerAccessService;

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
    clubEventRepo = RecordingClubEventRepository();
    clubChannelChatRepo = RecordingClubChannelChatRepository();
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
    mutedMemberRepo = RecordingClubRepository(
      club: club,
      myMembership: membership(role: ClubMemberRole.member, status: ClubMemberStatus.approved),
      isMutedResult: true,
    );
    developerAccessService = RecordingDeveloperAccessService(isDeveloperResult: true);
  });

  Future<void> pumpPage(
    WidgetTester tester,
    RecordingClubRepository repo, {
    RecordingClubEventRepository? clubEventRepository,
    RecordingDeveloperAccessService? developerAccessServiceOverride,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClubPage(
          clubRepository: repo,
          clubPostRepository: clubPostRepo,
          clubId: club.id,
          clubEventRepository: clubEventRepository,
          clubChannelChatRepository: clubChannelChatRepo,
          developerAccessService: developerAccessServiceOverride ?? developerAccessService,
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
    // WYN-136 -- developerAccessService defaults to isDeveloperResult:
    // true across this whole file (see setUp), so the gated row is
    // visible here.
    expect(find.text('ลิงก์เชิญ'), findsOneWidget);
  });

  group('WYN-136: "ลิงก์เชิญ" More menu row (Staged Rollout gated)', () {
    testWidgets('non-developer account: the Owner never sees the row at all',
        (tester) async {
      developerAccessService = RecordingDeveloperAccessService(isDeveloperResult: false);
      await pumpPage(tester, ownerRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('ลิงก์เชิญ'), findsNothing);
      // The rest of the Owner's menu is otherwise unchanged.
      expect(find.text('แก้ไขข้อมูล Club'), findsOneWidget);
    });

    testWidgets('tapping it opens ClubInviteLinksScreen', (tester) async {
      await pumpPage(tester, ownerRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลิงก์เชิญ'));
      await tester.pumpAndSettle();

      expect(find.byType(ClubInviteLinksScreen), findsOneWidget);
    });

    testWidgets('a plain approved member never sees the row (not '
        'canManageClub)', (tester) async {
      await pumpPage(tester, approvedMemberRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('ลิงก์เชิญ'), findsNothing);
    });
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

  group('Chat tab (staged rollout)', () {
    testWidgets('a developer account sees a top-level "แชท" tab', (tester) async {
      await pumpPage(
        tester,
        approvedMemberRepo,
        developerAccessServiceOverride: RecordingDeveloperAccessService(isDeveloperResult: true),
      );

      expect(find.text('แชท'), findsOneWidget);
    });

    testWidgets(
        'a non-developer account never sees "แชท" -- just "โพสต์"/"เกี่ยวกับ", '
        'exactly the pre-restructuring 2-tab shape it would fall back to',
        (tester) async {
      await pumpPage(
        tester,
        approvedMemberRepo,
        developerAccessServiceOverride: RecordingDeveloperAccessService(isDeveloperResult: false),
      );

      expect(find.text('โพสต์'), findsOneWidget);
      expect(find.text('เกี่ยวกับ'), findsOneWidget);
      expect(find.text('แชท'), findsNothing);
    });
  });

  group('About tab sections -- Members/Events/Insights merged (2026-09-07 restructuring)', () {
    testWidgets('a non-member sees only "รายละเอียด"/"สมาชิก" segments, no '
        '"กิจกรรม"/"Insights"', (tester) async {
      await pumpPage(tester, notJoinedRepo, clubEventRepository: clubEventRepo);

      await tester.tap(find.text('เกี่ยวกับ'));
      await tester.pumpAndSettle();

      expect(find.text('รายละเอียด'), findsOneWidget);
      expect(find.text('สมาชิก'), findsOneWidget);
      expect(find.text('กิจกรรม'), findsNothing);
      expect(find.text('Insights'), findsNothing);
    });

    testWidgets('a pending member sees no "กิจกรรม" segment either', (tester) async {
      await pumpPage(tester, pendingRepo, clubEventRepository: clubEventRepo);

      await tester.tap(find.text('เกี่ยวกับ'));
      await tester.pumpAndSettle();

      expect(find.text('กิจกรรม'), findsNothing);
    });

    testWidgets('an approved member (any role) sees a "กิจกรรม" segment, but not '
        '"Insights"', (tester) async {
      await pumpPage(tester, approvedMemberRepo, clubEventRepository: clubEventRepo);

      await tester.tap(find.text('เกี่ยวกับ'));
      await tester.pumpAndSettle();

      expect(find.text('กิจกรรม'), findsOneWidget);
      expect(find.text('Insights'), findsNothing);
    });

    testWidgets('the Owner sees both "กิจกรรม" and "Insights" segments',
        (tester) async {
      await pumpPage(tester, ownerRepo, clubEventRepository: clubEventRepo);

      await tester.tap(find.text('เกี่ยวกับ'));
      await tester.pumpAndSettle();

      expect(find.text('กิจกรรม'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
    });

    testWidgets('tapping the Insights segment shows stats from fetchClubInsights',
        (tester) async {
      ownerRepo.clubInsightsResult = const ClubInsights(
        newMembers: 2,
        newPosts: 4,
        likesAndComments: 9,
        activeMembers: 3,
      );
      await pumpPage(tester, ownerRepo);

      await tester.tap(find.text('เกี่ยวกับ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('9'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets(
        'jumping to the Members segment from the More menu still works when '
        'the Owner has extra ("กิจกรรม"/"Insights") segments', (tester) async {
      await pumpPage(tester, ownerRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('จัดการสิทธิ์สมาชิก'));
      await tester.pumpAndSettle();

      // "เชิญเพื่อน" is ClubMembersTab's own button, not shared with any
      // other section -- proves the jump landed on "เกี่ยวกับ" with its
      // "สมาชิก" segment selected, not just "เกี่ยวกับ" defaulting to
      // "รายละเอียด".
      expect(find.text('เชิญเพื่อน'), findsOneWidget);
    });
  });

  group('Per-Club notification mute (WYN-116)', () {
    testWidgets('a non-member never sees the mute row', (tester) async {
      await pumpPage(tester, notJoinedRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('ปิดการแจ้งเตือน Club นี้'), findsNothing);
      expect(find.text('เปิดการแจ้งเตือน Club นี้'), findsNothing);
    });

    testWidgets(
        'an approved member not yet muted sees "ปิดการแจ้งเตือน Club นี้", and '
        'tapping it calls muteClubNotifications', (tester) async {
      await pumpPage(tester, approvedMemberRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('ปิดการแจ้งเตือน Club นี้'), findsOneWidget);
      await tester.tap(find.text('ปิดการแจ้งเตือน Club นี้'));
      await tester.pumpAndSettle();

      expect(approvedMemberRepo.muteClubNotificationsCalls, 1);
      expect(approvedMemberRepo.muteClubNotificationsClubIdArgs, [club.id]);
    });

    testWidgets(
        'an already-muted approved member sees "เปิดการแจ้งเตือน Club นี้", and '
        'tapping it calls unmuteClubNotifications', (tester) async {
      await pumpPage(tester, mutedMemberRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('เปิดการแจ้งเตือน Club นี้'), findsOneWidget);
      expect(find.text('ปิดการแจ้งเตือน Club นี้'), findsNothing);
      await tester.tap(find.text('เปิดการแจ้งเตือน Club นี้'));
      await tester.pumpAndSettle();

      expect(mutedMemberRepo.unmuteClubNotificationsCalls, 1);
      expect(mutedMemberRepo.unmuteClubNotificationsClubIdArgs, [club.id]);
    });

    testWidgets('the Owner (role-gated menu branch) also sees the mute row',
        (tester) async {
      await pumpPage(tester, ownerRepo);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('ปิดการแจ้งเตือน Club นี้'), findsOneWidget);
    });
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
            clubChannelChatRepository: clubChannelChatRepo,
            developerAccessService: developerAccessService,
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
            clubChannelChatRepository: clubChannelChatRepo,
            developerAccessService: developerAccessService,
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
            clubChannelChatRepository: clubChannelChatRepo,
            developerAccessService: developerAccessService,
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byKey(const Key('club_banner_image')), findsOneWidget);
    });
  });

}
