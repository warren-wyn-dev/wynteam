import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/drop/presentation/drop_feed_screen.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

Drop _drop({required String id, required String caption}) => Drop(
      id: id,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/$id.jpg',
      caption: caption,
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

void main() {
  late RecordingDropRepository dropRepo;
  late RecordingDropRepository emptyFollowingRepo;
  late RecordingDropRepository emptyRepo;
  late RecordingFollowRepository followRepo;
  late RecordingPopRepository popRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    // A fresh repository set per test -- see search_screen_test.dart for
    // why this must be setUp(), never constructed inline in testWidgets.
    dropRepo = RecordingDropRepository(
      feedDrops: [_drop(id: 'd1', caption: 'For You/Latest')],
      followingFeedDrops: [_drop(id: 'd2', caption: 'Following เท่านั้น')],
    );
    emptyFollowingRepo = RecordingDropRepository(
      feedDrops: [_drop(id: 'd1', caption: 'For You/Latest')],
      followingFeedDrops: [],
    );
    emptyRepo = RecordingDropRepository(feedDrops: [], followingFeedDrops: []);
    followRepo = RecordingFollowRepository();
    popRepo = RecordingPopRepository();
    profileRepo = RecordingProfileRepository();
    savedRepo = RecordingSavedRepository();
  });

  Widget buildDropFeed({RecordingDropRepository? dropRepository}) => MaterialApp(
        home: DropFeedScreen(
          dropRepository: dropRepository ?? dropRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
        ),
      );

  testWidgets('defaults to the For You tab, rendering with HomeDropCard',
      (tester) async {
    await tester.pumpWidget(buildDropFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('For You/Latest'), findsOneWidget);
    expect(find.byType(HomeDropCard), findsOneWidget);
  });

  testWidgets(
      'shows a relative timestamp under the author name on the For You tab '
      '(WYN-023) -- proves fixing HomeDropCard once fixed the Drop feed too',
      (tester) async {
    await tester.pumpWidget(buildDropFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    // _drop() defaults createdAt to DateTime.now(), so relativeTimeLabel()
    // renders "เมื่อสักครู่" (diff < 60s).
    expect(find.text('เมื่อสักครู่'), findsOneWidget);
  });

  testWidgets('switching to the Following tab shows only followed-users\' Drops',
      (tester) async {
    await tester.pumpWidget(buildDropFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('Following เท่านั้น'), findsOneWidget);
    expect(find.text('For You/Latest'), findsNothing);
    // WYN-023: all 3 tabs reuse the same HomeDropCard, so all 3 show it.
    expect(find.text('เมื่อสักครู่'), findsOneWidget);
  });

  testWidgets('shows a distinct empty message on Following, not the generic one',
      (tester) async {
    await tester.pumpWidget(buildDropFeed(dropRepository: emptyFollowingRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(
      find.text('ยังไม่ได้ follow ใครเลย ลองดู For You เพื่อค้นหาคนน่าสนใจ'),
      findsOneWidget,
    );
  });

  testWidgets('switching to the Latest tab shows the chronological feed',
      (tester) async {
    await tester.pumpWidget(buildDropFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('Latest'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('For You/Latest'), findsOneWidget);
    // WYN-023: same HomeDropCard, same fix -- the Latest tab shows the
    // relative timestamp too, not just For You.
    expect(find.text('เมื่อสักครู่'), findsOneWidget);
  });

  testWidgets('shows the empty state with the generic message on For You/Latest',
      (tester) async {
    await tester.pumpWidget(buildDropFeed(dropRepository: emptyRepo));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีใครแชร์รูปเลย เป็นคนแรกสิ!'), findsOneWidget);
  });

  testWidgets('tapping a card opens DropDetailScreen', (tester) async {
    await tester.pumpWidget(buildDropFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byType(HomeDropCard));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets(
      'rapid double-tap on a card\'s Like routes through DropRepository '
      'with a fresh currentlyLiked value each time', (tester) async {
    await tester.pumpWidget(buildDropFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    final likeButton = find.widgetWithIcon(IconButton, Icons.favorite_border);
    expect(likeButton, findsOneWidget);

    final onPressed = tester.widget<IconButton>(likeButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(dropRepo.toggleLikeCalls, 2);
    expect(dropRepo.toggleLikeCurrentlyLikedArgs, [false, true]);
  });

  testWidgets('Following tab keeps its own scroll/data separate from For You',
      (tester) async {
    await tester.pumpWidget(buildDropFeed());
    await tester.pumpAndSettle();
    tester.takeException();

    // Switch to Following, then back to For You -- AutomaticKeepAlive
    // should mean neither tab re-fetches/loses its already-loaded data.
    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(find.text('Following เท่านั้น'), findsOneWidget);

    await tester.tap(find.text('For You'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('For You/Latest'), findsOneWidget);
  });

  group('For You ranking (WYN-018 follow-up)', () {
    late RecordingDropRepository rankingRepo;

    setUp(() {
      // Constructed here, not inline in testWidgets -- see
      // search_screen_test.dart / .wyn/learning/PATTERNS.md for why: each
      // RecordingDropRepository wraps a real throwaway SupabaseClient
      // whose GoTrue client starts a Timer.periodic, which leaks past the
      // test's fake-async zone if built outside setUp().
      rankingRepo = RecordingDropRepository(
        feedDrops: [_drop(id: 'd1', caption: 'Chronological only')],
        rankedFeedDrops: [_drop(id: 'd2', caption: 'Ranked only')],
      );
    });

    testWidgets('For You renders from fetchRankedFeed, not the chronological feed',
        (tester) async {
      await tester.pumpWidget(buildDropFeed(dropRepository: rankingRepo));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(rankingRepo.fetchRankedFeedCalls, greaterThan(0));
      expect(find.text('Ranked only'), findsOneWidget);
      expect(find.text('Chronological only'), findsNothing);
    });

    testWidgets('Latest still renders from the chronological feed, unaffected',
        (tester) async {
      await tester.pumpWidget(buildDropFeed(dropRepository: rankingRepo));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('Latest'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('Chronological only'), findsOneWidget);
      expect(find.text('Ranked only'), findsNothing);
    });
  });
}
