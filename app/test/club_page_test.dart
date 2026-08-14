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

  testWidgets('shows "เข้าร่วม" when not a member, and joining calls joinClub',
      (tester) async {
    await pumpPage(tester, notJoinedRepo);

    final joinButton = find.byKey(const Key('club-header-join-button'));
    expect(find.descendant(of: joinButton, matching: find.text('เข้าร่วม')), findsOneWidget);
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
  });

  testWidgets('shows "เข้าร่วมแล้ว" for an approved member, and confirming Leave calls leaveClub',
      (tester) async {
    await pumpPage(tester, approvedMemberRepo);

    expect(find.text('เข้าร่วมแล้ว'), findsOneWidget);
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
}
