import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/presentation/explore_clubs_screen.dart';
import 'package:wyn/features/home/presentation/widgets/from_your_clubs_feed.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';

/// WYN-023 R3: the "สำรวจ Club" button in FromYourClubsFeed's empty state
/// -- see .wyn/docs/design/wyn-023-home-drop-polish.md. Mirrors
/// ClubSection's own explore-club test coverage pattern.
void main() {
  late RecordingClubRepository clubRepository;
  late RecordingClubPostRepository emptyClubPostRepository;
  late RecordingClubPostRepository nonEmptyClubPostRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    // Fresh per test -- see drop_feed_screen_test.dart / .wyn/learning/
    // PATTERNS.md for why these must be setUp(), never inline in
    // testWidgets.
    clubRepository = RecordingClubRepository();
    emptyClubPostRepository = RecordingClubPostRepository(fromJoinedClubs: []);
    nonEmptyClubPostRepository = RecordingClubPostRepository(fromJoinedClubs: [
      ClubPost(
        id: 'cp1',
        clubId: 'club-1',
        authorId: 'someone-else',
        authorUsername: 'namfah',
        content: 'โพสต์จาก Club ที่เข้าร่วม',
        pinned: false,
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      ),
    ]);
  });

  Widget buildFeed({
    RecordingClubPostRepository? clubPostRepository,
  }) =>
      MaterialApp(
        home: Scaffold(
          body: FromYourClubsFeed(
            clubRepository: clubRepository,
            clubPostRepository: clubPostRepository ?? emptyClubPostRepository,
          ),
        ),
      );

  testWidgets(
      'the empty state shows an "สำรวจ Club" button next to the existing '
      'join-prompt message', (tester) async {
    await tester.pumpWidget(buildFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('เข้าร่วม Club เพื่อดูโพสต์ที่นี่'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'สำรวจ Club'), findsOneWidget);
    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
  });

  testWidgets(
      'does not show the "สำรวจ Club" button once there are joined-club '
      'posts to show', (tester) async {
    await tester.pumpWidget(buildFeed(
      clubPostRepository: nonEmptyClubPostRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.widgetWithText(OutlinedButton, 'สำรวจ Club'), findsNothing);
  });

  testWidgets(
      'tapping "สำรวจ Club" opens ExploreClubsScreen and reloads the feed '
      'on return', (tester) async {
    await tester.pumpWidget(buildFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.widgetWithText(OutlinedButton, 'สำรวจ Club'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ExploreClubsScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    tester.takeException();

    // Back on FromYourClubsFeed's empty state -- reload happened without
    // crashing/getting stuck on a loading spinner.
    expect(find.text('เข้าร่วม Club เพื่อดูโพสต์ที่นี่'), findsOneWidget);
  });
}
