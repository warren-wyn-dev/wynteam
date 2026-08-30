import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/presentation/club_post_detail_screen.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/hashtag/presentation/hashtag_feed_screen.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/club/presentation/widgets/club_post_card.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

Drop _drop({
  required String id,
  required String caption,
  DateTime? createdAt,
  int likeCount = 0,
  int commentCount = 0,
}) =>
    Drop(
      id: id,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/$id.jpg',
      caption: caption,
      createdAt: createdAt ?? DateTime.now(),
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: false,
      savedByMe: false,
    );

ClubPost _clubPost({
  required String id,
  required String content,
  DateTime? createdAt,
  int likeCount = 0,
  int commentCount = 0,
}) =>
    ClubPost(
      id: id,
      clubId: 'club-1',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      content: content,
      pinned: false,
      createdAt: createdAt ?? DateTime.now(),
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: false,
      savedByMe: false,
    );

void main() {
  late RecordingClubRepository clubRepo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  // One RecordingDropRepository/RecordingClubPostRepository per scenario,
  // all built here in setUp() rather than inline inside testWidgets --
  // each wraps a real throwaway SupabaseClient whose GoTrue client
  // starts a Timer.periodic at construction time, so building one inside
  // a testWidgets callback leaks it. See .wyn/learning/PATTERNS.md.
  late RecordingDropRepository emptyDropRepo;
  late RecordingClubPostRepository emptyClubPostRepo;
  late RecordingDropRepository nearMissDropRepo;
  late RecordingDropRepository singleMatchDropRepo;
  late RecordingClubPostRepository singleMatchClubPostRepo;
  late RecordingDropRepository latestOrderDropRepo;
  late RecordingDropRepository trendingOrderDropRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    clubRepo = RecordingClubRepository();
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();

    emptyDropRepo = RecordingDropRepository();
    emptyClubPostRepo = RecordingClubPostRepository();
    nearMissDropRepo = RecordingDropRepository(
      feedDrops: [_drop(id: 'd1', caption: '#WYNfamily มารวมตัวกัน')],
    );
    singleMatchDropRepo =
        RecordingDropRepository(feedDrops: [_drop(id: 'd1', caption: '#WYN สวัสดี')]);
    singleMatchClubPostRepo = RecordingClubPostRepository(
      searchResults: [_clubPost(id: 'cp1', content: '#WYN ยินดีต้อนรับ')],
    );
    latestOrderDropRepo = RecordingDropRepository(feedDrops: [
      _drop(id: 'old', caption: '#WYN เก่า', createdAt: DateTime(2020, 1, 1)),
      _drop(id: 'new', caption: '#WYN ใหม่', createdAt: DateTime(2026, 1, 1)),
    ]);
    trendingOrderDropRepo = RecordingDropRepository(feedDrops: [
      _drop(id: 'low', caption: '#WYN น้อยคนสนใจ', likeCount: 1, commentCount: 0),
      _drop(id: 'high', caption: '#WYN ดังมาก', likeCount: 50, commentCount: 10),
    ]);
  });

  Widget buildScreen({
    required String tag,
    RecordingDropRepository? dropRepository,
    RecordingClubPostRepository? clubPostRepository,
  }) =>
      MaterialApp(
        home: HashtagFeedScreen(
          tag: tag,
          dropRepository: dropRepository ?? emptyDropRepo,
          clubPostRepository: clubPostRepository ?? emptyClubPostRepo,
          clubRepository: clubRepo,
          followRepository: followRepo,
          profileRepository: profileRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
        ),
      );

  testWidgets('shows the empty message when nothing matches', (tester) async {
    await tester.pumpWidget(buildScreen(tag: 'WYN'));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีโพสต์ที่ใช้ #WYN'), findsOneWidget);
  });

  testWidgets(
      'excludes a broad ILIKE match that is not actually the exact tag '
      '(#WYNfamily must not count as #WYN)', (tester) async {
    await tester.pumpWidget(buildScreen(tag: 'WYN', dropRepository: nearMissDropRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(HomeDropCard), findsNothing);
    expect(find.text('ยังไม่มีโพสต์ที่ใช้ #WYN'), findsOneWidget);
  });

  testWidgets('merges Drop and Club post results that exactly match the tag',
      (tester) async {
    // Both a Drop card and a Club post card need to be simultaneously
    // mounted to assert on -- the default 800x600 viewport is too short
    // for that with a 1:1 Drop image above it. See
    // home_feed_screen_test.dart's identical tall-viewport pattern.
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildScreen(
      tag: 'WYN',
      dropRepository: singleMatchDropRepo,
      clubPostRepository: singleMatchClubPostRepo,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(HomeDropCard), findsOneWidget);
    expect(find.byType(ClubPostCard), findsOneWidget);
  });

  testWidgets('Latest tab (default) sorts newest first', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildScreen(tag: 'WYN', dropRepository: latestOrderDropRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    final captions =
        tester.widgetList<HomeDropCard>(find.byType(HomeDropCard)).map((c) => c.item.caption);
    expect(captions, ['#WYN ใหม่', '#WYN เก่า']);
  });

  testWidgets('Trending tab sorts by like+comment count', (tester) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildScreen(tag: 'WYN', dropRepository: trendingOrderDropRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('Trending'));
    await tester.pumpAndSettle();
    tester.takeException();

    final captions =
        tester.widgetList<HomeDropCard>(find.byType(HomeDropCard)).map((c) => c.item.caption);
    expect(captions, ['#WYN ดังมาก', '#WYN น้อยคนสนใจ']);
  });

  testWidgets('tapping a Drop result opens DropDetailScreen', (tester) async {
    await tester.pumpWidget(buildScreen(tag: 'WYN', dropRepository: singleMatchDropRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    // Same off-screen-hit-test-avoidance as HomeFeedScreen's own tests --
    // the card's growth (verified badge, top-reply preview, the "..."
    // menu row) can push tester.tap()'s geometric center onto a nested
    // tappable (e.g. an ActionMetric) instead of the outer card, so this
    // invokes the callback directly rather than relying on hit-testing.
    tester.widget<HomeDropCard>(find.byType(HomeDropCard)).onTap();
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets('tapping a Club post result opens ClubPostDetailScreen', (tester) async {
    await tester
        .pumpWidget(buildScreen(tag: 'WYN', clubPostRepository: singleMatchClubPostRepo));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byType(ClubPostCard));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ClubPostDetailScreen), findsOneWidget);
  });
}
