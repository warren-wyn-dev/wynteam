import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/presentation/explore_clubs_screen.dart';

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

/// Regression tests for ExploreClubsScreen restyled to 09-club-explore.tsx
/// -- hero + search bar + 2 plain list sections ("กำลังนิยม"/"ใหม่ล่าสุด"),
/// no personalized recommended carousel, no ranked row, no category
/// chips/grid (Founder decision, 2026-08-29 -- see the screen's own doc
/// comment).
void main() {
  Club club(String id, {int memberCount = 1}) => Club(
        id: id,
        name: 'Club $id',
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
  // existing pattern.
  late RecordingClubRepository twoClubsRepo;
  late RecordingClubRepository emptyRepo;
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
    // Tall viewport so both list sections are mounted without needing a
    // real scroll gesture -- mirrors club_page_test.dart's / other
    // screens' tester.view.physicalSize pattern.
    tester.view.physicalSize = const Size(390, 1600);
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

  testWidgets(
      'shows both Club rows in "กำลังนิยม" and "ใหม่ล่าสุด" (same clubs, '
      'since discoverableClubs backs both)', (tester) async {
    await pumpScreen(tester, twoClubsRepo);

    expect(find.text('กำลังนิยม'), findsOneWidget);
    expect(find.text('ใหม่ล่าสุด'), findsOneWidget);
    // "Club a"/"Club b" each appear twice -- once per section.
    expect(find.text('Club a'), findsNWidgets(2));
    expect(find.text('Club b'), findsNWidgets(2));
    expect(find.text('10 สมาชิก'), findsNWidgets(2));
    expect(find.text('5 สมาชิก'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'เข้าร่วม'), findsNWidgets(4));
  });

  testWidgets(
      'WYN-081: pulling to refresh re-fetches and shows a newly added '
      'club', (tester) async {
    await pumpScreen(tester, twoClubsRepo);
    expect(find.text('Club c'), findsNothing);

    twoClubsRepo.discoverableClubs.add(club('c', memberCount: 3));

    // Same off-screen-hit-test-avoidance as elsewhere in this suite --
    // invoke RefreshIndicator.onRefresh directly rather than simulating
    // a physical drag gesture.
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect(find.text('Club c'), findsNWidgets(2));
  });

  testWidgets('shows the empty-state message for each section when there '
      'are no discoverable clubs', (tester) async {
    await pumpScreen(tester, emptyRepo);

    expect(find.text('ยังไม่มี Club กำลังนิยมตอนนี้'), findsOneWidget);
    expect(find.text('ยังไม่มี Club ใหม่ตอนนี้'), findsOneWidget);
  });

  testWidgets('search bar filters both sections by name, client-side',
      (tester) async {
    await pumpScreen(tester, searchRepo);
    // 2 clubs x 2 sections = 4 rows before searching.
    expect(find.widgetWithText(OutlinedButton, 'เข้าร่วม'), findsNWidgets(4));

    await tester.enterText(find.byType(TextField), 'alpha');
    await tester.pumpAndSettle();

    // 1 matching club x 2 sections = 2 rows.
    expect(find.widgetWithText(OutlinedButton, 'เข้าร่วม'), findsNWidgets(2));
    expect(find.text('Club alpha'), findsNWidgets(2));
    expect(find.text('Club beta'), findsNothing);
  });

  testWidgets(
      'a search with no matches shows the "ไม่พบ" message instead of the '
      'empty-catalog message', (tester) async {
    await pumpScreen(tester, searchRepo);

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.pumpAndSettle();

    expect(find.text('ไม่พบ Club ที่ตรงกับ "nope"'), findsNWidgets(2));
    expect(find.text('ยังไม่มี Club กำลังนิยมตอนนี้'), findsNothing);
  });

  testWidgets(
      'double-tapping Join on a row before the first request resolves '
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

    final joinButton = find.widgetWithText(OutlinedButton, 'เข้าร่วม').first;

    await tester.tap(joinButton);
    await tester.tap(joinButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(delayedJoinRepo.joinClubCalls, 1);
  });

  testWidgets('a pending join request shows "รออนุมัติ" instead of "เข้าร่วม"',
      (tester) async {
    await pumpScreen(tester, pendingRepo);

    expect(find.text('รออนุมัติ'), findsNWidgets(2));
    expect(find.widgetWithText(OutlinedButton, 'เข้าร่วม'), findsNothing);
  });

  testWidgets(
      'the Club rows do not overflow at textScaler 1.3 (DS-008 '
      'accessibility), even for the longer "รออนุมัติ" label', (tester) async {
    await pumpScreen(tester, pendingRepo, textScale: 1.3);

    // pumpAndSettle would already have surfaced a FlutterError for any
    // RenderFlex overflow during layout -- reaching this line at all is
    // itself the assertion.
    expect(find.text('รออนุมัติ'), findsNWidgets(2));
  });
}
