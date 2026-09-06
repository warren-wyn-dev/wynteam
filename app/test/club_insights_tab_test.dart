import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_insights.dart';
import 'package:wyn/features/club/presentation/widgets/club_insights_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for WYN-117's Insights tab -- the RPC-backed
/// aggregate stats widget shown only to a Club's Owner/Admin (see
/// club_page_test.dart for the role-gating tests on the tab itself;
/// this file only covers the tab's own rendering/interaction).
void main() {
  final club = Club(
    id: 'club-1',
    name: 'Test Club',
    privacy: ClubPrivacy.public,
    ownerId: 'owner-1',
    createdAt: DateTime.now(),
    memberCount: 10,
  );

  // Built in setUp(), never inline inside testWidgets -- see
  // .wyn/learning/PATTERNS.md.
  late RecordingClubRepository repo;
  late RecordingClubRepository errorRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'owner-1');
  });

  setUp(() {
    repo = RecordingClubRepository(
      club: club,
      clubInsightsResult: const ClubInsights(
        newMembers: 3,
        newPosts: 5,
        likesAndComments: 12,
        activeMembers: 4,
      ),
    );
    errorRepo = RecordingClubRepository(club: club)
      ..fetchClubInsightsResultError = Exception('network error');
  });

  Future<void> pumpTab(WidgetTester tester, RecordingClubRepository r) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClubInsightsTab(clubRepository: r, club: club),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to the 7-day window and shows all 4 stats',
      (tester) async {
    await pumpTab(tester, repo);

    expect(repo.fetchClubInsightsDaysArgs, [7]);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('สมาชิกใหม่'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('โพสต์ใหม่'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Like/Comment รวม'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('สมาชิก Active'), findsOneWidget);
  });

  testWidgets('switching to 30 วัน re-fetches with days: 30', (tester) async {
    await pumpTab(tester, repo);

    await tester.tap(find.text('30 วัน'));
    await tester.pumpAndSettle();

    expect(repo.fetchClubInsightsCalls, 2);
    expect(repo.fetchClubInsightsDaysArgs, [7, 30]);
  });

  testWidgets('a failed fetch shows an error state with a retry button',
      (tester) async {
    await pumpTab(tester, errorRepo);

    expect(find.text('โหลดข้อมูลไม่สำเร็จ'), findsOneWidget);
    expect(find.text('ลองใหม่'), findsOneWidget);
  });
}
