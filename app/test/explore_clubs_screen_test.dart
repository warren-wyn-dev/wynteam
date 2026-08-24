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

/// A RecordingClubRepository whose [joinClub] takes a real (short) delay
/// before resolving, instead of resolving on the next microtask -- so a
/// widget test can observe ExploreClubsScreen's `_joinInFlightClubId`
/// guard actually blocking a second tap while the first request is
/// still in flight (a plain RecordingClubRepository resolves too fast
/// for two sequential `await tester.tap(...)` calls to ever overlap).
class _DelayedJoinClubRepository extends RecordingClubRepository {
  _DelayedJoinClubRepository({super.discoverableClubs});

  @override
  Future<void> joinClub(Club club) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await super.joinClub(club);
  }
}

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

  // Built in setUp(), never inline inside testWidgets -- each
  // RecordingClubRepository constructs a real (if inert) SupabaseClient,
  // whose GoTrueClient starts a periodic auto-refresh Timer. Building it
  // inside a testWidgets callback registers that Timer inside the
  // FakeAsync zone testWidgets wraps around the test body, which then
  // trips flutter_test's "no pending timers" check at test end; setUp()
  // runs outside that zone, so it doesn't. Mirrors club_page_test.dart's
  // existing pattern exactly.
  late RecordingClubRepository twoClubsRepo;
  late RecordingClubRepository emptyRepo;
  late RecordingClubRepository categoryRepo;
  late RecordingClubRepository searchRepo;
  late _DelayedJoinClubRepository delayedJoinRepo;
  late RecordingClubRepository pendingRepo;
  late RecordingClubPostRepository clubPostRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  setUp(() {
    twoClubsRepo = RecordingClubRepository(
      discoverableClubs: [club('a', memberCount: 10), club('b', memberCount: 5)],
    );
    emptyRepo = RecordingClubRepository(discoverableClubs: []);
    categoryRepo = RecordingClubRepository(
      discoverableClubs: [
        club('tech', category: 'Technology'),
        club('game', category: 'Gaming'),
      ],
    );
    searchRepo = RecordingClubRepository(
      discoverableClubs: [club('alpha'), club('beta')],
    );
    delayedJoinRepo = _DelayedJoinClubRepository(discoverableClubs: [club('a')]);
    pendingRepo = RecordingClubRepository(
      discoverableClubs: [club('a')],
      pendingClubIds: {'a'},
    );
    clubPostRepository = RecordingClubPostRepository();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    RecordingClubRepository repo, {
    double textScale = 1.0,
  }) async {
    // Tall viewport so the hero/recommended/ranked rows *and* the grid
    // sections below them are all mounted without needing a real scroll
    // gesture -- mirrors home_feed_screen_test.dart's/
    // store_screen_test.dart's tester.view.physicalSize + textScaler
    // pattern.
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ExploreClubsScreen(
          clubRepository: repo,
          clubPostRepository: clubPostRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder gridCards() => find.byWidgetPredicate(
        (widget) => widget is ClubDiscoveryCard && widget.layout == ClubDiscoveryCardLayout.grid,
      );

  testWidgets('shows the recommended row and a 2-column grid of the discoverable clubs',
      (tester) async {
    await pumpScreen(tester, twoClubsRepo);

    expect(find.text('Club แนะนำสำหรับคุณ'), findsOneWidget);
    expect(find.byType(ClubRecommendedCard), findsWidgets);
    expect(find.byType(ClubRankedRow), findsWidgets);
    // Both "กำลังนิยม" (ranked list backing data) and the grid section
    // below render Club A/B -- grid tiles specifically use the `grid`
    // layout.
    expect(gridCards(), findsWidgets);
  });

  testWidgets('hides the recommended/ranked rows when there are no discoverable clubs',
      (tester) async {
    await pumpScreen(tester, emptyRepo);

    expect(find.text('Club แนะนำสำหรับคุณ'), findsNothing);
    expect(find.byType(ClubRankedRow), findsNothing);
    expect(find.byType(ClubRecommendedCard), findsNothing);
    expect(find.text('ยังไม่มี Club ในหมวดนี้'), findsWidgets);
  });

  testWidgets('category chip re-filters the grid sections (not the recommended row)',
      (tester) async {
    await pumpScreen(tester, categoryRepo);
    // 2 clubs x 2 sections (กำลังนิยม + ใหม่ล่าสุด) = 4 grid tiles.
    expect(gridCards(), findsNWidgets(4));

    final gamingChip = find.widgetWithText(ChoiceChip, 'Gaming');
    await tester.ensureVisible(gamingChip);
    await tester.pumpAndSettle();
    await tester.tap(gamingChip);
    await tester.pumpAndSettle();

    // Filtered to 1 club x 2 sections = 2 grid tiles -- the recommended
    // row is intentionally unaffected by the Category filter (WYN-056
    // Design spec), so it isn't asserted on here.
    expect(gridCards(), findsNWidgets(2));
  });

  testWidgets('search bar filters the grid sections by name, client-side', (tester) async {
    await pumpScreen(tester, searchRepo);
    // 2 clubs x 2 sections = 4 grid tiles before searching.
    expect(gridCards(), findsNWidgets(4));

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();

    // 1 matching club x 2 sections = 2 grid tiles.
    expect(gridCards(), findsNWidgets(2));
    expect(find.text('ไม่พบ Club ที่ตรงกับ "alpha"'), findsNothing);
  });

  testWidgets(
      'double-tapping Join on a recommended card before the first request resolves '
      'only calls joinClub once', (tester) async {
    // RecordingClubRepository's joinClub resolves on the very next
    // microtask (no real delay), which would make two back-to-back
    // `await tester.tap(...)` calls resolve sequentially rather than
    // overlapping -- not an actual test of the in-flight guard.
    // delayedJoinRepo takes a real (if short) delay so the first
    // request stays "in flight" long enough for the second tap to land
    // while it's still pending, actually exercising
    // ExploreClubsScreen's `_joinInFlightClubId` guard (mirrors
    // ClubPage's same pattern).
    await pumpScreen(tester, delayedJoinRepo);

    final joinButton = find.descendant(
      of: find.byType(ClubRecommendedCard).first,
      matching: find.text('เข้าร่วม'),
    );
    expect(joinButton, findsOneWidget);

    await tester.tap(joinButton);
    await tester.tap(joinButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(delayedJoinRepo.joinClubCalls, 1);
  });

  testWidgets('a pending join request shows "รออนุมัติ" on the recommended card', (tester) async {
    await pumpScreen(tester, pendingRepo);

    expect(
      find.descendant(of: find.byType(ClubRecommendedCard).first, matching: find.text('รออนุมัติ')),
      findsOneWidget,
    );
  });

  testWidgets(
      'the ranked row and recommended card do not overflow at textScaler 1.3 '
      '(DS-008 accessibility), even for the longer "รออนุมัติ" label', (tester) async {
    await pumpScreen(tester, pendingRepo, textScale: 1.3);

    // pumpAndSettle would already have surfaced a FlutterError for any
    // RenderFlex overflow during layout -- reaching this line at all is
    // itself the assertion. Also check the specific widgets exist so a
    // future regression that silently drops them wouldn't slip through
    // as a false pass.
    expect(find.byType(ClubRankedRow), findsWidgets);
    expect(find.byType(ClubRecommendedCard), findsWidgets);
  });
}
