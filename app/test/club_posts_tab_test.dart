import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_channel.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/data/club_member_badge.dart';
import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/presentation/widgets/club_posts_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_badge_repository.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_developer_access_service.dart';

/// Regression tests for WYN-014's post-visibility gating -- the Product
/// spec is explicit that Club posts are visible *only* to approved
/// members regardless of whether the Club is Public or Private (see
/// .wyn/tasks/backlog/WYN-014-club-core.md, Requirements: "โพสต์จะแสดง
/// เฉพาะสมาชิก Club ตามสิทธิ์ของ Club ... ไม่ใช่เรื่องมองเห็นโพสต์ได้ก่อน
/// เข้าร่วม"). RLS enforces this server-side (club_posts select policy,
/// supabase/schema.sql), and this test proves the UI enforces the same
/// rule as defense-in-depth -- a non-member must never see post content
/// even if a repository bug somehow returned it.
///
/// Channel-switcher/chat-toggle coverage moved to club_chat_tab_test.dart
/// once the Founder's tab-restructuring decision (2026-09-07) split Chat
/// out into its own top-level tab and made this tab a plain club-wide
/// feed -- see this file's own class doc comment.
void main() {
  final club = Club(
    id: 'club-1',
    name: 'Test Club',
    privacy: ClubPrivacy.public,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 4,
  );

  ClubPost post({
    required String id,
    bool pinned = false,
    String content = 'สวัสดีชาว Club',
  }) =>
      ClubPost(
        id: id,
        clubId: club.id,
        authorId: 'someone-else',
        authorUsername: 'someone-else',
        content: content,
        pinned: pinned,
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      );

  // WYN-115: a Poll Club Post fixture -- results already visible (voter
  // is the current user), mirroring what get_club_poll_results() would
  // return after ClubPostRepository's batch fetch.
  ClubPost pollPost({required String id}) => ClubPost(
        id: id,
        clubId: club.id,
        authorId: 'someone-else',
        authorUsername: 'someone-else',
        content: 'อาหารเที่ยงนี้กินอะไรดี?',
        pinned: false,
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
        pollId: 'poll-1',
        pollOptions: const ['ข้าวมันไก่', 'ส้มตำ'],
        pollExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
        pollMyVoteIndex: null,
        pollTotalVotes: 2,
        pollOptionCounts: const [1, 1],
      );

  // Built in setUp(), never inline inside testWidgets -- see
  // .wyn/learning/PATTERNS.md.
  late RecordingClubPostRepository postsRepo;
  late RecordingClubPostRepository pinnedFirstRepo;
  late RecordingClubPostRepository emptyRepo;
  late RecordingClubPostRepository pollRepo;
  late RecordingClubRepository defaultClubRepo;
  late RecordingClubRepository twoChannelsRepo;
  late RecordingClubBadgeRepository someoneElseVipBadgeRepo;
  late RecordingClubBadgeRepository emptyBadgeRepo;
  late RecordingDeveloperAccessService defaultDeveloperAccessService;

  ClubChannel channel({required String id, required String name}) => ClubChannel(
        id: id,
        clubId: club.id,
        name: name,
        createdBy: 'owner-1',
        createdAt: DateTime.now(),
      );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    postsRepo = RecordingClubPostRepository(posts: [post(id: 'p1')]);
    pinnedFirstRepo = RecordingClubPostRepository(posts: [
      post(id: 'p-pinned', pinned: true, content: 'ประกาศสำคัญ'),
      post(id: 'p-normal', content: 'โพสต์ธรรมดา'),
    ]);
    emptyRepo = RecordingClubPostRepository(posts: []);
    pollRepo = RecordingClubPostRepository(posts: [pollPost(id: 'p-poll')]);
    // Built here, not inline as pumpTab's default (or inline inside a
    // testWidgets body below) -- see .wyn/learning/PATTERNS.md:
    // RecordingClubRepository's constructor creates a real SupabaseClient
    // with its own GoTrue auto-refresh Timer.
    defaultClubRepo = RecordingClubRepository(club: club);
    // Multiple channels still resolves fine -- this tab always posts
    // into channels.first (oldest) regardless of how many exist, since
    // channel choice is a Chat-only concept now (ClubChatTab).
    twoChannelsRepo = RecordingClubRepository(
      club: club,
      channels: [
        channel(id: 'c-general', name: 'ทั่วไป'),
        channel(id: 'c-announce', name: 'ประกาศ'),
      ],
    );
    someoneElseVipBadgeRepo = RecordingClubBadgeRepository(badges: {
      'someone-else': ClubMemberBadge(
        clubId: club.id,
        userId: 'someone-else',
        label: 'VIP',
        colorKey: ClubBadgeColor.gold,
        createdBy: 'owner-1',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    });
    emptyBadgeRepo = RecordingClubBadgeRepository();
    defaultDeveloperAccessService = RecordingDeveloperAccessService(isDeveloperResult: true);
  });

  Future<void> pumpTab(
    WidgetTester tester,
    RecordingClubPostRepository repo, {
    required ClubMemberRole? myRole,
    VoidCallback? onJoinTapped,
    RecordingClubRepository? clubRepository,
    RecordingClubBadgeRepository? clubBadgeRepository,
    RecordingDeveloperAccessService? developerAccessService,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClubPostsTab(
          clubPostRepository: repo,
          clubRepository: clubRepository ?? defaultClubRepo,
          clubBadgeRepository: clubBadgeRepository,
          developerAccessService: developerAccessService ?? defaultDeveloperAccessService,
          club: club,
          myRole: myRole,
          onJoinTapped: onJoinTapped ?? () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a non-member sees a join prompt, never the post content, even though the '
    'repository has posts',
    (tester) async {
      await pumpTab(tester, postsRepo, myRole: null);

      expect(find.text('เข้าร่วม Club เพื่อดูโพสต์'), findsOneWidget);
      expect(find.text('สวัสดีชาว Club'), findsNothing);
    },
  );

  testWidgets('tapping the join prompt button calls onJoinTapped', (tester) async {
    var tapped = false;
    await pumpTab(tester, postsRepo, myRole: null, onJoinTapped: () => tapped = true);

    await tester.tap(find.text('เข้าร่วม'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('an approved member sees the post list and the create-post FAB',
      (tester) async {
    await pumpTab(tester, postsRepo, myRole: ClubMemberRole.member);

    expect(find.text('สวัสดีชาว Club'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('the feed is club-wide, not scoped to a channel: fetchPosts is '
      'called with only the club id', (tester) async {
    await pumpTab(
      tester,
      postsRepo,
      myRole: ClubMemberRole.member,
      clubRepository: twoChannelsRepo,
    );

    expect(postsRepo.fetchPostsClubIdArgs, [club.id]);
  });

  testWidgets('shows an empty-state message for a member when there are no posts yet',
      (tester) async {
    await pumpTab(tester, emptyRepo, myRole: ClubMemberRole.member);

    expect(find.text('ยังไม่มีโพสต์ใน Club นี้ เป็นคนแรกสิ!'), findsOneWidget);
  });

  // Regression: the empty-state used to be a bare Center() with no
  // scrollable ancestor at all, so RefreshIndicator wasn't even in the
  // tree -- pull-to-refresh silently did nothing on a Club with 0 posts
  // (Founder's own screenshot). Same off-screen-hit-test-avoidance as
  // explore_clubs_screen_test.dart's identical pattern -- invoke
  // RefreshIndicator.onRefresh directly rather than simulating a
  // physical drag gesture.
  testWidgets('the empty state still has a working pull-to-refresh',
      (tester) async {
    await pumpTab(tester, emptyRepo, myRole: ClubMemberRole.member);

    expect(find.byType(RefreshIndicator), findsOneWidget);
    final callsBefore = emptyRepo.fetchPostsClubIdArgs.length;

    final indicator = tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect(emptyRepo.fetchPostsClubIdArgs.length, greaterThan(callsBefore));
  });

  // AC: "Owner/Admin/Moderator ปักหมุดโพสต์ → โพสต์นั้นอยู่บนสุดของ Posts
  // tab เสมอ" -- ClubPostRepository.fetchPosts already sorts
  // pinned-first server-side; this test covers the UI's own "ปักหมุด"
  // divider label, which only makes sense if the first item actually is
  // pinned.
  // Regression: pagination used to be scroll-triggered (a private
  // ScrollController watching for "near the bottom"), which is exactly
  // what stops a scrollable from being "primary" -- required for
  // ClubPage's staged-rollout collapsing-header layout to coordinate
  // scroll position across tabs. Switched to a manual "load more"
  // button (same UI as club_members_tab.dart's own "ดูสมาชิกเพิ่มเติม"),
  // needing no ScrollController at all. This proves the button actually
  // fetches page 1, not just that it renders.
  testWidgets('a full page of posts shows a "ดูโพสต์เพิ่มเติม" button that loads the next page',
      (tester) async {
    final fullPageRepo = RecordingClubPostRepository(
      posts: List.generate(20, (i) => post(id: 'p$i')),
    );
    await pumpTab(tester, fullPageRepo, myRole: ClubMemberRole.member);

    expect(find.text('ดูโพสต์เพิ่มเติม'), findsOneWidget);
    expect(fullPageRepo.fetchPostsClubIdArgs, [club.id]);

    await tester.tap(find.text('ดูโพสต์เพิ่มเติม'));
    await tester.pumpAndSettle();

    expect(fullPageRepo.fetchPostsClubIdArgs, [club.id, club.id]);
    // fullPageRepo returns [] for any page beyond 0 (RecordingClubPostRepository's
    // own "page == 0 ? posts : []" shape), so the button disappears once
    // that empty page 1 result sets _hasMore to false.
    expect(find.text('ดูโพสต์เพิ่มเติม'), findsNothing);
  });

  testWidgets('shows a "ปักหมุด" label above the pinned post at the top of the list',
      (tester) async {
    await pumpTab(tester, pinnedFirstRepo, myRole: ClubMemberRole.member);

    expect(find.text('ปักหมุด'), findsOneWidget);
    expect(find.text('ประกาศสำคัญ'), findsOneWidget);
    expect(find.text('โพสต์ธรรมดา'), findsOneWidget);

    final pinnedLabelTop = tester.getTopLeft(find.text('ปักหมุด')).dy;
    final pinnedPostTop = tester.getTopLeft(find.text('ประกาศสำคัญ')).dy;
    final normalPostTop = tester.getTopLeft(find.text('โพสต์ธรรมดา')).dy;
    expect(pinnedLabelTop, lessThan(pinnedPostTop));
    expect(pinnedPostTop, lessThan(normalPostTop));
  });

  testWidgets(
      'DS-005: shows exactly one hairline divider between the 2 posts, '
      'same pattern as Home Feed (DS-003)', (tester) async {
    await pumpTab(tester, pinnedFirstRepo, myRole: ClubMemberRole.member);

    expect(find.byType(Divider), findsOneWidget);
  });

  group('Poll voting (WYN-115)', () {
    testWidgets(
        'shows ClubPollCard instead of images for a Poll Club Post, and '
        'tapping an option optimistically updates then calls votePoll',
        (tester) async {
      await pumpTab(tester, pollRepo, myRole: ClubMemberRole.member);

      expect(find.text('ข้าวมันไก่'), findsOneWidget);
      expect(find.text('ส้มตำ'), findsOneWidget);
      expect(find.text('50%'), findsNWidgets(2));

      await tester.tap(find.text('ข้าวมันไก่'));
      await tester.pump();

      // Optimistic: 2 existing votes + this one = 3 total, 2/3 for the
      // tapped option.
      expect(find.text('67%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.pumpAndSettle();
      expect(pollRepo.votePollArgs, [('poll-1', 0)]);
    });

    testWidgets('a failed vote reverts the optimistic update', (tester) async {
      pollRepo.votePollError = Exception('network error');
      await pumpTab(tester, pollRepo, myRole: ClubMemberRole.member);

      await tester.tap(find.text('ข้าวมันไก่'));
      await tester.pumpAndSettle();

      // Reverted back to the original (no vote) state.
      expect(find.text('50%'), findsNWidgets(2));
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });

  group('Role Badge (WYN-129)', () {
    testWidgets("shows the post author's badge pill next to their name",
        (tester) async {
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubBadgeRepository: someoneElseVipBadgeRepo,
      );

      expect(find.text('VIP'), findsOneWidget);
    });

    testWidgets('shows no badge pill for an author with none', (tester) async {
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubBadgeRepository: emptyBadgeRepo,
      );

      expect(find.text('VIP'), findsNothing);
    });
  });

  group('Staged rollout gate (WYN-127-128-129-missing-staged-rollout-gate.md)', () {
    testWidgets(
        'a non-developer account sees no badge pill, but the feed itself is '
        'unaffected', (tester) async {
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubBadgeRepository: someoneElseVipBadgeRepo,
        developerAccessService: RecordingDeveloperAccessService(isDeveloperResult: false),
      );

      expect(find.text('VIP'), findsNothing);
      expect(find.text('สวัสดีชาว Club'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('a developer account sees the badge pill (regression -- proves '
        'the gate is not just "always hidden")', (tester) async {
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubBadgeRepository: someoneElseVipBadgeRepo,
        developerAccessService: RecordingDeveloperAccessService(isDeveloperResult: true),
      );

      expect(find.text('VIP'), findsOneWidget);
    });
  });

  testWidgets(
      'the create-post composer never mentions a channel name -- posting '
      'is club-wide now, not per-channel', (tester) async {
    await pumpTab(
      tester,
      postsRepo,
      myRole: ClubMemberRole.member,
      clubRepository: twoChannelsRepo,
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('โพสต์ใน Test Club'), findsOneWidget);
    expect(find.textContaining('#ทั่วไป'), findsNothing);
    expect(find.textContaining('#ประกาศ'), findsNothing);
  });
}
