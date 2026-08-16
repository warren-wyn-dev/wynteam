import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/presentation/widgets/club_posts_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';

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

  // Built in setUp(), never inline inside testWidgets -- see
  // .wyn/learning/PATTERNS.md.
  late RecordingClubPostRepository postsRepo;
  late RecordingClubPostRepository pinnedFirstRepo;
  late RecordingClubPostRepository emptyRepo;

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
  });

  Future<void> pumpTab(
    WidgetTester tester,
    RecordingClubPostRepository repo, {
    required ClubMemberRole? myRole,
    VoidCallback? onJoinTapped,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ClubPostsTab(
          clubPostRepository: repo,
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
}
