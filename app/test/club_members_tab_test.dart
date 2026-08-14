import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/presentation/widgets/club_members_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for WYN-014's role-permission boundary logic in
/// ClubMembersTab -- the project's first role-based (not just boolean)
/// permission system. Every scenario mirrors an Acceptance Criterion or
/// Risks-section boundary from .wyn/tasks/backlog/WYN-014-club-core.md,
/// and matches the same permission boundaries enforced server-side by
/// the RPC functions in supabase/schema.sql (approve/reject/
/// set_club_member_role/remove_club_member/ban_club_member) -- the UI
/// menu must never *offer* an action the RPC would reject.
void main() {
  final club = Club(
    id: 'club-1',
    name: 'Test Club',
    privacy: ClubPrivacy.public,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 4,
  );

  ClubMember member({
    required String userId,
    required ClubMemberRole role,
    ClubMemberStatus status = ClubMemberStatus.approved,
  }) =>
      ClubMember(
        clubId: club.id,
        userId: userId,
        username: userId,
        role: role,
        status: status,
        createdAt: DateTime.now(),
      );

  // Every RecordingClubRepository is built once per test in setUp() (not
  // inline inside a testWidgets callback) -- its constructor creates a
  // real SupabaseClient with its own GoTrue auto-refresh Timer, and
  // building one mid-test leaves that Timer pending outside the
  // fake-async zone flutter_test expects it in. See
  // .wyn/learning/PATTERNS.md.
  late RecordingClubRepository ownerViewingMemberRepo;
  late RecordingClubRepository ownerViewingAdminRepo;
  late RecordingClubRepository ownerOnlyRepo;
  late RecordingClubRepository adminViewingMemberRepo;
  late RecordingClubRepository adminViewingAdmin2Repo;
  late RecordingClubRepository adminViewingOwnerRepo;
  late RecordingClubRepository moderatorViewingMemberRepo;
  late RecordingClubRepository moderatorViewingAdminAndModRepo;
  late RecordingClubRepository memberViewingMemberRepo;
  late RecordingClubRepository pendingVisibleRepo;
  late RecordingClubRepository pendingHiddenForModeratorRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    ownerViewingMemberRepo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.owner),
      member(userId: 'u-member', role: ClubMemberRole.member),
    ]);
    ownerViewingAdminRepo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.owner),
      member(userId: 'u-admin', role: ClubMemberRole.admin),
    ]);
    ownerOnlyRepo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.owner),
    ]);
    adminViewingMemberRepo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.admin),
      member(userId: 'u-member', role: ClubMemberRole.member),
    ]);
    adminViewingAdmin2Repo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.admin),
      member(userId: 'u-admin-2', role: ClubMemberRole.admin),
    ]);
    adminViewingOwnerRepo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.admin),
      member(userId: 'owner-1', role: ClubMemberRole.owner),
    ]);
    moderatorViewingMemberRepo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.moderator),
      member(userId: 'u-member', role: ClubMemberRole.member),
    ]);
    moderatorViewingAdminAndModRepo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.moderator),
      member(userId: 'u-admin', role: ClubMemberRole.admin),
      member(userId: 'u-mod-2', role: ClubMemberRole.moderator),
    ]);
    memberViewingMemberRepo = RecordingClubRepository(approvedMembers: [
      member(userId: 'viewer', role: ClubMemberRole.member),
      member(userId: 'u-member-2', role: ClubMemberRole.member),
    ]);
    pendingVisibleRepo = RecordingClubRepository(
      approvedMembers: [member(userId: 'viewer', role: ClubMemberRole.owner)],
      pendingMembers: [
        member(userId: 'u-pending', role: ClubMemberRole.member, status: ClubMemberStatus.pending),
      ],
    );
    pendingHiddenForModeratorRepo = RecordingClubRepository(
      approvedMembers: [member(userId: 'viewer', role: ClubMemberRole.moderator)],
      pendingMembers: [
        member(userId: 'u-pending', role: ClubMemberRole.member, status: ClubMemberStatus.pending),
      ],
    );
  });

  Future<void> pumpTab(
    WidgetTester tester,
    RecordingClubRepository repo, {
    required ClubMemberRole? myRole,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClubMembersTab(
            clubRepository: repo,
            club: club,
            myRole: myRole,
            onChanged: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // PopupMenuButton<_MemberAction>/PopupMenuItem<_MemberAction> carry a
  // private generic type argument, so find.byType can't target them
  // directly (a bare `PopupMenuItem` type token means
  // `PopupMenuItem<dynamic>`, which doesn't runtimeType-match a
  // `PopupMenuItem<_MemberAction>` instance) -- checking each expected/
  // unexpected label with find.text after opening the menu sidesteps
  // that entirely.
  Future<void> openMenu(WidgetTester tester, String targetUserId) async {
    await tester.tap(find.byKey(ValueKey('member-menu-$targetUserId')));
    await tester.pumpAndSettle();
  }

  Future<void> closeMenu(WidgetTester tester) async {
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
  }

  group('Owner viewing others', () {
    testWidgets('sees promote-to-Admin/Moderator, remove, and ban on a Member row',
        (tester) async {
      await pumpTab(tester, ownerViewingMemberRepo, myRole: ClubMemberRole.owner);

      await openMenu(tester, 'u-member');
      expect(find.text('ตั้งเป็น Admin'), findsOneWidget);
      expect(find.text('ตั้งเป็น Moderator'), findsOneWidget);
      expect(find.text('ลบออกจาก Club'), findsOneWidget);
      expect(find.text('แบน'), findsOneWidget);
      expect(find.text('ตั้งเป็นสมาชิกทั่วไป'), findsNothing);
      await closeMenu(tester);
    });

    testWidgets('sees demote-to-Moderator/Member (not re-promote-to-Admin) on an Admin row',
        (tester) async {
      await pumpTab(tester, ownerViewingAdminRepo, myRole: ClubMemberRole.owner);

      await openMenu(tester, 'u-admin');
      expect(find.text('ตั้งเป็น Moderator'), findsOneWidget);
      expect(find.text('ตั้งเป็นสมาชิกทั่วไป'), findsOneWidget);
      expect(find.text('ลบออกจาก Club'), findsOneWidget);
      expect(find.text('แบน'), findsOneWidget);
      expect(find.text('ตั้งเป็น Admin'), findsNothing);
      await closeMenu(tester);
    });

    testWidgets('has no menu at all on their own row', (tester) async {
      await pumpTab(tester, ownerOnlyRepo, myRole: ClubMemberRole.owner);

      expect(find.byKey(const ValueKey('member-menu-viewer')), findsNothing);
    });
  });

  group('Admin viewing others', () {
    // AC: "Admin แต่งตั้งได้แค่ Moderator (แต่งตั้ง Admin ใหม่ไม่ได้)" --
    // this is the single most safety-critical boundary in the whole
    // feature (an Admin escalating a Member straight to Admin, or
    // creating a second power center via another Admin, would defeat
    // the entire Owner-is-singular design). See Product spec Risks.
    testWidgets('never sees "ตั้งเป็น Admin" anywhere, on a Member row', (tester) async {
      await pumpTab(tester, adminViewingMemberRepo, myRole: ClubMemberRole.admin);

      await openMenu(tester, 'u-member');
      expect(find.text('ตั้งเป็น Moderator'), findsOneWidget);
      expect(find.text('ลบออกจาก Club'), findsOneWidget);
      expect(find.text('แบน'), findsOneWidget);
      expect(find.text('ตั้งเป็น Admin'), findsNothing);
      await closeMenu(tester);
    });

    testWidgets('has no menu at all on another Admin row', (tester) async {
      await pumpTab(tester, adminViewingAdmin2Repo, myRole: ClubMemberRole.admin);

      expect(find.byKey(const ValueKey('member-menu-u-admin-2')), findsNothing);
    });

    testWidgets('has no menu at all on the Owner row', (tester) async {
      await pumpTab(tester, adminViewingOwnerRepo, myRole: ClubMemberRole.admin);

      expect(find.byKey(const ValueKey('member-menu-owner-1')), findsNothing);
    });
  });

  group('Moderator viewing others', () {
    testWidgets('sees only remove/ban (no role options) on a Member row', (tester) async {
      await pumpTab(tester, moderatorViewingMemberRepo, myRole: ClubMemberRole.moderator);

      await openMenu(tester, 'u-member');
      expect(find.text('ลบออกจาก Club'), findsOneWidget);
      expect(find.text('แบน'), findsOneWidget);
      expect(find.text('ตั้งเป็น Admin'), findsNothing);
      expect(find.text('ตั้งเป็น Moderator'), findsNothing);
      expect(find.text('ตั้งเป็นสมาชิกทั่วไป'), findsNothing);
      await closeMenu(tester);
    });

    testWidgets('has no menu at all on an Admin or Moderator row', (tester) async {
      await pumpTab(tester, moderatorViewingAdminAndModRepo, myRole: ClubMemberRole.moderator);

      expect(find.byKey(const ValueKey('member-menu-u-admin')), findsNothing);
      expect(find.byKey(const ValueKey('member-menu-u-mod-2')), findsNothing);
    });
  });

  testWidgets('a plain Member sees no management menu on anyone', (tester) async {
    await pumpTab(tester, memberViewingMemberRepo, myRole: ClubMemberRole.member);

    expect(find.byKey(const ValueKey('member-menu-viewer')), findsNothing);
    expect(find.byKey(const ValueKey('member-menu-u-member-2')), findsNothing);
  });

  group('Pending-requests section', () {
    testWidgets('is visible with Approve/Reject buttons for Owner/Admin', (tester) async {
      await pumpTab(tester, pendingVisibleRepo, myRole: ClubMemberRole.owner);

      expect(find.text('คำขอเข้าร่วม (1)'), findsOneWidget);
      expect(find.text('อนุมัติ'), findsOneWidget);
      expect(find.text('ปฏิเสธ'), findsOneWidget);
    });

    // AC: Moderator ไม่มีสิทธิ์ Approve คำขอเข้าร่วม -- ClubMembersTab
    // only fetches pending members at all when the viewer canManageClub,
    // so this also proves the UI doesn't leak pending requests through
    // to a Moderator even when the (canned) repository has some to give.
    testWidgets('never shows for a Moderator, even if pending requests exist', (tester) async {
      await pumpTab(tester, pendingHiddenForModeratorRepo, myRole: ClubMemberRole.moderator);

      expect(find.textContaining('คำขอเข้าร่วม'), findsNothing);
    });
  });
}
