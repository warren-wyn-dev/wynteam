import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_insights.dart';
import 'package:wyn/features/club/data/club_member.dart';
import 'package:wyn/features/club/presentation/widgets/club_about_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_event_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_developer_access_service.dart';

/// Regression tests for the composite "เกี่ยวกับ" tab -- the Founder's
/// tab-restructuring decision (2026-09-07) merged what used to be 3
/// separate top-level Club tabs (สมาชิก/เกี่ยวกับ/Insights) plus กิจกรรม
/// into this one, reached via an internal segmented switcher. See this
/// widget's own class doc comment. Segment-visibility-through-ClubPage
/// coverage (role gating end to end) lives in club_page_test.dart; this
/// file covers the widget directly, plus [ClubAboutTab.initialSection].
void main() {
  final club = Club(
    id: 'club-1',
    name: 'Test Club',
    description: 'ชมรมทดสอบ',
    category: 'Lifestyle',
    privacy: ClubPrivacy.public,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 4,
    rules: 'ห้ามสแปม',
  );

  late RecordingClubRepository clubRepo;
  late RecordingClubEventRepository clubEventRepo;
  late RecordingDeveloperAccessService developerAccessService;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    clubRepo = RecordingClubRepository(club: club);
    clubEventRepo = RecordingClubEventRepository();
    developerAccessService = RecordingDeveloperAccessService(isDeveloperResult: true);
  });

  Future<void> pumpTab(
    WidgetTester tester, {
    required ClubMemberRole? myRole,
    ClubAboutSection initialSection = ClubAboutSection.details,
    VoidCallback? onInvite,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClubAboutTab(
            clubRepository: clubRepo,
            clubEventRepository: clubEventRepo,
            developerAccessService: developerAccessService,
            club: club,
            myRole: myRole,
            onChanged: () {},
            onInvite: onInvite ?? () {},
            initialSection: initialSection,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to "รายละเอียด", showing the Club\'s own description/rules',
      (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member);

    expect(find.text('ชมรมทดสอบ'), findsOneWidget);
    expect(find.text('ห้ามสแปม'), findsOneWidget);
  });

  testWidgets('an Owner can edit the rules from "รายละเอียด"', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.owner);

    await tester.tap(find.text('แก้ไขกฎ'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'กฎใหม่');
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขกฎ'), findsOneWidget);
  });

  testWidgets('a plain Member cannot edit the rules', (tester) async {
    await pumpTab(tester, myRole: ClubMemberRole.member);

    expect(find.text('แก้ไขกฎ'), findsNothing);
  });

  group('Segment visibility', () {
    testWidgets('a non-member sees only "รายละเอียด"/"สมาชิก"', (tester) async {
      await pumpTab(tester, myRole: null);

      expect(find.text('รายละเอียด'), findsOneWidget);
      expect(find.text('สมาชิก'), findsOneWidget);
      expect(find.text('กิจกรรม'), findsNothing);
      expect(find.text('Insights'), findsNothing);
    });

    testWidgets('an approved member also sees "กิจกรรม", but not "Insights"',
        (tester) async {
      await pumpTab(tester, myRole: ClubMemberRole.member);

      expect(find.text('กิจกรรม'), findsOneWidget);
      expect(find.text('Insights'), findsNothing);
    });

    testWidgets('an Owner sees every segment', (tester) async {
      await pumpTab(tester, myRole: ClubMemberRole.owner);

      expect(find.text('รายละเอียด'), findsOneWidget);
      expect(find.text('สมาชิก'), findsOneWidget);
      expect(find.text('กิจกรรม'), findsOneWidget);
      expect(find.text('Insights'), findsOneWidget);
    });

    testWidgets('tapping "สมาชิก" shows ClubMembersTab\'s own "เชิญเพื่อน" button',
        (tester) async {
      await pumpTab(tester, myRole: ClubMemberRole.member);

      await tester.tap(find.text('สมาชิก'));
      await tester.pumpAndSettle();

      expect(find.text('เชิญเพื่อน'), findsOneWidget);
    });

    testWidgets('tapping "Insights" shows stats from fetchClubInsights', (tester) async {
      clubRepo.clubInsightsResult = const ClubInsights(
        newMembers: 1,
        newPosts: 2,
        likesAndComments: 3,
        activeMembers: 4,
      );
      await pumpTab(tester, myRole: ClubMemberRole.owner);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });
  });

  testWidgets('[initialSection.members] opens straight to "สมาชิก", not "รายละเอียด"',
      (tester) async {
    await pumpTab(
      tester,
      myRole: ClubMemberRole.member,
      initialSection: ClubAboutSection.members,
    );

    expect(find.text('เชิญเพื่อน'), findsOneWidget);
    expect(find.text('ชมรมทดสอบ'), findsNothing);
  });
}
