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
import 'support/recording_club_channel_chat_repository.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for WYN-014's post-visibility gating -- the Product
/// spec is explicit that Club posts are visible *only* to approved
/// members regardless of whether the Club is Public or Private (see
/// .wyn/tasks/backlog/WYN-014-club-core.md, Requirements: "โพสต์จะแสดง
/// เฉพาะสมาชิก Club ตามสิทธิ์ของ Club ... ไม่ใช่เรื่องมองเห็นโพสต์ได้ก่อน
/// เข้าร่วม"). RLS enforces this server-side (club_posts select policy,
/// supabase/schema.sql), and this test proves the UI enforces the same
/// rule as defense-in-depth -- a non-member must never see post content
/// even if a repository bug somehow returned it.
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
  late RecordingClubRepository singleGeneralChannelRepo;
  late RecordingClubRepository twoChannelsRepo;
  late RecordingClubRepository ownerSingleChannelRepo;
  late RecordingClubBadgeRepository someoneElseVipBadgeRepo;
  late RecordingClubBadgeRepository emptyBadgeRepo;
  late RecordingClubChannelChatRepository defaultChatRepo;

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
    // WYN-128: never let ClubPostsTab fall back to a real
    // ClubChannelChatRepository in a test -- its unread-badge
    // subscription would call the real Supabase Realtime client's
    // `.subscribe()`, which leaves a pending Timer flutter_test fails
    // the test over (see RecordingClubChannelChatRepository's own doc
    // comment).
    defaultChatRepo = RecordingClubChannelChatRepository();
    singleGeneralChannelRepo = RecordingClubRepository(
      club: club,
      channels: [channel(id: 'c-general', name: 'ทั่วไป')],
    );
    twoChannelsRepo = RecordingClubRepository(
      club: club,
      channels: [
        channel(id: 'c-general', name: 'ทั่วไป'),
        channel(id: 'c-announce', name: 'ประกาศ'),
      ],
    );
    ownerSingleChannelRepo = RecordingClubRepository(
      club: club,
      channels: [channel(id: 'c-general', name: 'ทั่วไป')],
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
  });

  Future<void> pumpTab(
    WidgetTester tester,
    RecordingClubPostRepository repo, {
    required ClubMemberRole? myRole,
    VoidCallback? onJoinTapped,
    RecordingClubRepository? clubRepository,
    RecordingClubBadgeRepository? clubBadgeRepository,
    RecordingClubChannelChatRepository? clubChannelChatRepository,
    VoidCallback? onBanned,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClubPostsTab(
          clubPostRepository: repo,
          clubRepository: clubRepository ?? defaultClubRepo,
          clubBadgeRepository: clubBadgeRepository,
          clubChannelChatRepository: clubChannelChatRepository ?? defaultChatRepo,
          club: club,
          myRole: myRole,
          onJoinTapped: onJoinTapped ?? () {},
          onBanned: onBanned,
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

  testWidgets('shows an empty-state message for a member when there are no posts yet',
      (tester) async {
    await pumpTab(tester, emptyRepo, myRole: ClubMemberRole.member);

    expect(find.text('ยังไม่มีโพสต์ใน Club นี้ เป็นคนแรกสิ!'), findsOneWidget);
  });

  // AC: "Owner/Admin/Moderator ปักหมุดโพสต์ → โพสต์นั้นอยู่บนสุดของ Posts
  // tab เสมอ" -- ClubPostRepository.fetchPosts already sorts
  // pinned-first server-side; this test covers the UI's own "ปักหมุด"
  // divider label, which only makes sense if the first item actually is
  // pinned.
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

  group('Channels (WYN-127)', () {
    testWidgets('starts on the "ทั่วไป" (oldest) channel and fetches its posts',
        (tester) async {
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubRepository: singleGeneralChannelRepo,
      );

      expect(find.text('#ทั่วไป'), findsOneWidget);
      expect(postsRepo.fetchPostsChannelIdArgs, contains('c-general'));
    });

    testWidgets('tapping another channel chip re-fetches posts scoped to it',
        (tester) async {
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubRepository: twoChannelsRepo,
      );
      postsRepo.fetchPostsChannelIdArgs.clear();

      await tester.tap(find.text('#ประกาศ'));
      await tester.pumpAndSettle();

      expect(postsRepo.fetchPostsChannelIdArgs, contains('c-announce'));
    });

    testWidgets('a plain Member never sees the "+ ห้องใหม่" chip', (tester) async {
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubRepository: singleGeneralChannelRepo,
      );

      expect(find.byKey(const Key('club_channel_new_chip')), findsNothing);
    });

    testWidgets('an Owner sees the "+ ห้องใหม่" chip and creating a channel selects it',
        (tester) async {
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.owner,
        clubRepository: ownerSingleChannelRepo,
      );

      expect(find.byKey(const Key('club_channel_new_chip')), findsOneWidget);

      await tester.tap(find.byKey(const Key('club_channel_new_chip')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ถามตอบ');
      await tester.pump();
      await tester.tap(find.widgetWithText(TextButton, 'บันทึก'));
      await tester.pumpAndSettle();

      expect(ownerSingleChannelRepo.createChannelCalls, 1);
      expect(find.text('#ถามตอบ'), findsOneWidget);
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

  group('Group Chat toggle (WYN-128)', () {
    testWidgets('defaults to the Posts view -- tapping "แชท" switches to the chat room',
        (tester) async {
      await pumpTab(tester, postsRepo, myRole: ClubMemberRole.member);

      expect(find.text('สวัสดีชาว Club'), findsOneWidget);
      expect(find.text('ยังไม่มีใครพิมพ์เลย'), findsNothing);

      await tester.tap(find.text('แชท'));
      await tester.pumpAndSettle();

      expect(find.text('สวัสดีชาว Club'), findsNothing);
      expect(find.text('ยังไม่มีใครพิมพ์เลย'), findsOneWidget);
    });

    testWidgets('shows the current channel\'s unread count as a badge on "แชท"',
        (tester) async {
      final chatRepo = RecordingClubChannelChatRepository()
        ..unreadCounts = {'default-channel': 2};
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubChannelChatRepository: chatRepo,
      );

      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('switching to chat marks the channel read, clearing the badge',
        (tester) async {
      final chatRepo = RecordingClubChannelChatRepository()
        ..unreadCounts = {'default-channel': 2};
      await pumpTab(
        tester,
        postsRepo,
        myRole: ClubMemberRole.member,
        clubChannelChatRepository: chatRepo,
      );
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('แชท'));
      await tester.pumpAndSettle();

      expect(chatRepo.markChannelReadCalls, 1);
      expect(find.text('2'), findsNothing);
    });
  });
}
