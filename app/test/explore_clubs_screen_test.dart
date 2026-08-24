import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/presentation/explore_clubs_screen.dart';
import 'package:wyn/features/club/presentation/widgets/club_discovery_card.dart';
import 'package:wyn/features/club/presentation/widgets/club_ranked_row.dart';
import 'package:wyn/features/club/presentation/widgets/club_recommended_card.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for WYN-056's ExploreClubsScreen redesign (hero +
/// "Club แนะนำสำหรับคุณ" row + "กำลังนิยม" ranked row + 2-column grid),
/// per .wyn/docs/design/wyn-056-club-discovery-visual-refresh.md.
void main() {
  Club club(String id, {String? category, int memberCount = 1}) => Club(
        id: id,
        name: 'Club $id',
        category: category,
        privacy: ClubPrivacy.public,
        ownerId: 'owner',
        createdAt: DateTime.now(),
        memberCount: memberCount,
      );

  late RecordingClubRepository clubRepository;
  late RecordingClubPostRepository clubPostRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    clubPostRepository = RecordingClubPostRepository();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExploreClubsScreen(
          clubRepository: clubRepository,
          clubPostRepository: clubPostRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the recommended row and a 2-column grid of the discoverable clubs',
      (tester) async {
    clubRepository = RecordingClubRepository(
      discoverableClubs: [club('a', memberCount: 10), club('b', memberCount: 5)],
    );

    await pumpScreen(tester);

    expect(find.text('Club แนะนำสำหรับคุณ'), findsOneWidget);
    expect(find.byType(ClubRecommendedCard), findsWidgets);
    expect(find.byType(ClubRankedRow), findsWidgets);
    // Both "กำลังนิยม" (ranked list backing data) and the grid section
    // below render Club A/B -- grid tiles specifically use the `grid`
    // layout.
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ClubDiscoveryCard && widget.layout == ClubDiscoveryCardLayout.grid,
      ),
      findsWidgets,
    );
  });

  testWidgets('hides the recommended/ranked rows when there are no discoverable clubs',
      (tester) async {
    clubRepository = RecordingClubRepository(discoverableClubs: []);

    await pumpScreen(tester);

    expect(find.text('Club แนะนำสำหรับคุณ'), findsNothing);
    expect(find.byType(ClubRankedRow), findsNothing);
    expect(find.byType(ClubRecommendedCard), findsNothing);
    expect(find.text('ยังไม่มี Club ในหมวดนี้'), findsWidgets);
  });

  testWidgets('category chip re-filters the grid sections (not the recommended row)',
      (tester) async {
    clubRepository = RecordingClubRepository(
      discoverableClubs: [
        club('tech', category: 'Technology'),
        club('game', category: 'Gaming'),
      ],
    );

    Finder gridCards() => find.byWidgetPredicate(
          (widget) =>
              widget is ClubDiscoveryCard && widget.layout == ClubDiscoveryCardLayout.grid,
        );

    await pumpScreen(tester);
    // 2 clubs x 2 sections (กำลังนิยม + ใหม่ล่าสุด) = 4 grid tiles.
    expect(gridCards(), findsNWidgets(4));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Gaming'));
    await tester.pumpAndSettle();

    // Filtered to 1 club x 2 sections = 2 grid tiles -- the recommended
    // row is intentionally unaffected by the Category filter (WYN-056
    // Design spec), so it isn't asserted on here.
    expect(gridCards(), findsNWidgets(2));
  });

  testWidgets('search bar filters the grid sections by name, client-side', (tester) async {
    clubRepository = RecordingClubRepository(
      discoverableClubs: [club('alpha'), club('beta')],
    );

    Finder gridCards() => find.byWidgetPredicate(
          (widget) =>
              widget is ClubDiscoveryCard && widget.layout == ClubDiscoveryCardLayout.grid,
        );

    await pumpScreen(tester);
    // 2 clubs x 2 sections = 4 grid tiles before searching.
    expect(gridCards(), findsNWidgets(4));

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();

    // 1 matching club x 2 sections = 2 grid tiles.
    expect(gridCards(), findsNWidgets(2));
    expect(find.text('ไม่พบ Club ที่ตรงกับ "alpha"'), findsNothing);
  });

  testWidgets('tapping Join on a recommended card calls joinClub exactly once (no double-submit)',
      (tester) async {
    clubRepository = RecordingClubRepository(
      discoverableClubs: [club('a')],
    );

    await pumpScreen(tester);

    final joinButton = find.descendant(
      of: find.byType(ClubRecommendedCard).first,
      matching: find.text('เข้าร่วม'),
    );
    expect(joinButton, findsOneWidget);

    await tester.tap(joinButton);
    await tester.tap(joinButton);
    await tester.pumpAndSettle();

    expect(clubRepository.joinClubCalls, 1);
  });

  testWidgets('a pending join request shows "รออนุมัติ" on the recommended card', (tester) async {
    clubRepository = RecordingClubRepository(
      discoverableClubs: [club('a')],
      pendingClubIds: {'a'},
    );

    await pumpScreen(tester);

    expect(
      find.descendant(of: find.byType(ClubRecommendedCard).first, matching: find.text('รออนุมัติ')),
      findsOneWidget,
    );
  });
}
