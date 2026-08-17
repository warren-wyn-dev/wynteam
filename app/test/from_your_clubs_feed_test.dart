import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/presentation/explore_clubs_screen.dart';
import 'package:wyn/features/home/presentation/widgets/from_your_clubs_feed.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// Regression tests for WYN-023's R3: the "จาก Club ของคุณ" empty state
/// gains a "สำรวจ Club" button, matching the original intent of
/// .wyn/docs/design/wyn-015-club-discovery-integration.md (Screen 5) that
/// was never wired up -- WYN-015 QA round 1 flagged the gap as a
/// non-blocking Minor because ClubSection's own "สำรวจ Club" button above
/// the toggle was always still reachable, but the empty state itself
/// stayed a dead end until now.
void main() {
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'viewer');
  });

  late RecordingClubPostRepository emptyClubPostRepository;
  late RecordingClubRepository clubRepository;

  setUp(() {
    // A fresh repository set per test -- see .wyn/learning/PATTERNS.md.
    emptyClubPostRepository = RecordingClubPostRepository(fromJoinedClubs: []);
    clubRepository = RecordingClubRepository();
  });

  Future<void> pumpFeed(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FromYourClubsFeed(
          clubRepository: clubRepository,
          clubPostRepository: emptyClubPostRepository,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'empty state shows the join-prompt text and a "สำรวจ Club" button',
      (tester) async {
    await pumpFeed(tester);

    expect(find.text('เข้าร่วม Club เพื่อดูโพสต์ที่นี่'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'สำรวจ Club'), findsOneWidget);
    // Same icon config as ClubSection's own button -- see the Design spec.
    expect(
      find.descendant(
        of: find.widgetWithText(OutlinedButton, 'สำรวจ Club'),
        matching: find.byIcon(Icons.explore_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
      'tapping "สำรวจ Club" opens ExploreClubsScreen and reloads the feed '
      'on return, mirroring ClubSection._openExploreClubs()', (tester) async {
    await pumpFeed(tester);
    // One fetch already happened from initState -- see _loadInitial().
    expect(emptyClubPostRepository.fetchFromJoinedClubsCalls, 1);

    await tester.tap(find.widgetWithText(OutlinedButton, 'สำรวจ Club'));
    await tester.pumpAndSettle();

    expect(find.byType(ExploreClubsScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(ExploreClubsScreen))).pop();
    await tester.pumpAndSettle();

    expect(find.byType(ExploreClubsScreen), findsNothing);
    // _loadInitial() ran again after returning -- without this, a Club
    // joined while on the Explore screen wouldn't show up here without a
    // manual pull-to-refresh.
    expect(emptyClubPostRepository.fetchFromJoinedClubsCalls, 2);
  });
}
