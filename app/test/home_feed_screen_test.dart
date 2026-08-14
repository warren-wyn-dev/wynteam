import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/home_feed_screen.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/home/presentation/search_placeholder_screen.dart';
import 'package:wyn/features/home/presentation/widgets/home_pop_card.dart';

import 'support/fake_supabase_session.dart';
import 'support/fake_video_player_platform.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_home_repository.dart';
import 'support/recording_pop_repository.dart';

HomeFeedItem _dropItem({
  String id = 'd1',
  int likeCount = 0,
  bool likedByMe = false,
}) =>
    HomeFeedItem(
      id: id,
      contentType: HomeContentType.drop,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      createdAt: DateTime.now(),
      caption: 'แคปชัน Drop',
      imageUrl: 'https://example.supabase.co/drops/$id.jpg',
      likeCount: likeCount,
      commentCount: 0,
      likedByMe: likedByMe,
      savedByMe: false,
    );

HomeFeedItem _popItem({
  String id = 'p1',
  int likeCount = 0,
  bool likedByMe = false,
}) =>
    HomeFeedItem(
      id: id,
      contentType: HomeContentType.pop,
      authorId: 'someone-else',
      authorUsername: 'ploy',
      createdAt: DateTime.now(),
      caption: 'แคปชัน Pop',
      videoUrl: 'https://example.supabase.co/pops/$id.mp4',
      durationSeconds: 42,
      viewCount: 7,
      likeCount: likeCount,
      commentCount: 0,
      likedByMe: likedByMe,
      savedByMe: false,
    );

void main() {
  // See drop_comment_like_test.dart (WYN-005) for why every repo (and its
  // underlying SupabaseClient auto-refresh Timer) is built once in
  // setUpAll rather than inside individual testWidgets callbacks -- this
  // applies to RecordingHomeRepository too, not just Drop/Pop's. Each
  // scenario gets its own repository set so call-count assertions can't
  // leak between tests or depend on execution order.
  late RecordingDropRepository sharedDropRepository;
  late RecordingPopRepository sharedPopRepository;
  late RecordingHomeRepository mixedFeedHomeRepository;
  late RecordingHomeRepository emptyHomeRepository;
  late RecordingHomeRepository searchTestHomeRepository;

  late RecordingDropRepository dropLikeTestDropRepository;
  late RecordingPopRepository dropLikeTestPopRepository;
  late RecordingHomeRepository dropLikeTestHomeRepository;

  late RecordingDropRepository popLikeTestDropRepository;
  late RecordingPopRepository popLikeTestPopRepository;
  late RecordingHomeRepository popLikeTestHomeRepository;

  late RecordingDropRepository dropCommentTestDropRepository;
  late RecordingPopRepository dropCommentTestPopRepository;
  late RecordingHomeRepository dropCommentTestHomeRepository;

  late RecordingDropRepository popCommentTestDropRepository;
  late RecordingPopRepository popCommentTestPopRepository;
  late RecordingHomeRepository popCommentTestHomeRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    SharedPreferences.setMockInitialValues({});
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();

    sharedDropRepository = RecordingDropRepository();
    sharedPopRepository = RecordingPopRepository();
    mixedFeedHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd1'), _popItem(id: 'p1')],
    );
    emptyHomeRepository = RecordingHomeRepository(feedItems: []);
    searchTestHomeRepository = RecordingHomeRepository(feedItems: []);

    dropLikeTestDropRepository = RecordingDropRepository();
    dropLikeTestPopRepository = RecordingPopRepository();
    dropLikeTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd2', likeCount: 0, likedByMe: false)],
    );

    popLikeTestDropRepository = RecordingDropRepository();
    popLikeTestPopRepository = RecordingPopRepository();
    popLikeTestHomeRepository = RecordingHomeRepository(
      feedItems: [_popItem(id: 'p2', likeCount: 0, likedByMe: false)],
    );

    dropCommentTestDropRepository = RecordingDropRepository();
    dropCommentTestPopRepository = RecordingPopRepository();
    dropCommentTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd3')],
    );

    popCommentTestDropRepository = RecordingDropRepository();
    popCommentTestPopRepository = RecordingPopRepository();
    popCommentTestHomeRepository = RecordingHomeRepository(
      feedItems: [_popItem(id: 'p3')],
    );
  });

  Widget buildHome(
    RecordingHomeRepository homeRepository, {
    required RecordingDropRepository dropRepository,
    required RecordingPopRepository popRepository,
  }) =>
      MaterialApp(
        home: HomeFeedScreen(
          homeRepository: homeRepository,
          dropRepository: dropRepository,
          popRepository: popRepository,
        ),
      );

  testWidgets('renders a mix of Drop and Pop cards with type-specific UI',
      (tester) async {
    await tester.pumpWidget(buildHome(
      mixedFeedHomeRepository,
      dropRepository: sharedDropRepository,
      popRepository: sharedPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('แคปชัน Drop'), findsOneWidget);
    // Regression for WYN-007 QA round 1: the Drop card's interaction row
    // must have a working Share button and a tappable Comment icon, not
    // just Like/Save. See .wyn/tasks/approved/WYN-007-home-feed.md.
    expect(find.widgetWithIcon(IconButton, Icons.share_outlined), findsOneWidget);
    expect(
      find.widgetWithIcon(IconButton, Icons.mode_comment_outlined),
      findsOneWidget,
    );

    // The Drop card's 1:1 image (800px wide in this 800x600 test
    // viewport) pushes the Pop card below the fold -- ListView only
    // mounts elements near the viewport, so scroll to it first. See
    // .wyn/learning/PATTERNS.md.
    await tester.scrollUntilVisible(
      find.text('แคปชัน Pop'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    tester.takeException();

    expect(find.text('แคปชัน Pop'), findsOneWidget);
    // Only the Pop card has a play icon and a duration badge.
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);
    // Only the Pop card shows a view count icon/number.
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    // Same Share/Comment regression check, scoped to the Pop card
    // specifically -- the Drop card above may still be in the element
    // tree (ListView cacheExtent) at this scroll position, so an
    // unscoped findsOneWidget would over-count.
    final popCardShare = find.descendant(
      of: find.byType(HomePopCard),
      matching: find.widgetWithIcon(IconButton, Icons.share_outlined),
    );
    expect(popCardShare, findsOneWidget);
    final popCardComment = find.descendant(
      of: find.byType(HomePopCard),
      matching: find.widgetWithIcon(IconButton, Icons.mode_comment_outlined),
    );
    expect(popCardComment, findsOneWidget);
  });

  testWidgets('shows the empty state when there is no content',
      (tester) async {
    await tester.pumpWidget(buildHome(
      emptyHomeRepository,
      dropRepository: sharedDropRepository,
      popRepository: sharedPopRepository,
    ));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!'), findsOneWidget);
  });

  testWidgets(
      'rapid double-tap on a Drop card\'s Like routes through '
      'DropRepository with a fresh currentlyLiked value each time',
      (tester) async {
    await tester.pumpWidget(buildHome(
      dropLikeTestHomeRepository,
      dropRepository: dropLikeTestDropRepository,
      popRepository: dropLikeTestPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final likeButton = find.widgetWithIcon(IconButton, Icons.favorite_border);
    expect(likeButton, findsOneWidget);

    final onPressed = tester.widget<IconButton>(likeButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(dropLikeTestDropRepository.toggleLikeCalls, 2);
    expect(dropLikeTestDropRepository.toggleLikeCurrentlyLikedArgs, [false, true]);
    expect(dropLikeTestPopRepository.toggleLikeCalls, 0);
  });

  testWidgets(
      'rapid double-tap on a Pop card\'s Like routes through '
      'PopRepository with a fresh currentlyLiked value each time',
      (tester) async {
    await tester.pumpWidget(buildHome(
      popLikeTestHomeRepository,
      dropRepository: popLikeTestDropRepository,
      popRepository: popLikeTestPopRepository,
    ));
    await tester.pumpAndSettle();

    final likeButton = find.widgetWithIcon(IconButton, Icons.favorite_border);
    expect(likeButton, findsOneWidget);

    final onPressed = tester.widget<IconButton>(likeButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(popLikeTestPopRepository.toggleLikeCalls, 2);
    expect(popLikeTestPopRepository.toggleLikeCurrentlyLikedArgs, [false, true]);
    expect(popLikeTestDropRepository.toggleLikeCalls, 0);
  });

  testWidgets(
      'tapping the Comment icon on a Drop card opens DropDetailScreen, '
      'same as tapping the card itself', (tester) async {
    await tester.pumpWidget(buildHome(
      dropCommentTestHomeRepository,
      dropRepository: dropCommentTestDropRepository,
      popRepository: dropCommentTestPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final commentButton =
        find.widgetWithIcon(IconButton, Icons.mode_comment_outlined);
    expect(commentButton, findsOneWidget);

    // Invoke onPressed directly rather than tester.tap(): the card's
    // 1:1 image pushes the interaction row below the 600px test
    // viewport, same as the scroll-to-find issue above -- calling the
    // callback exercises the exact same wiring without needing to
    // scroll it into hit-testable range first.
    final onPressed = tester.widget<IconButton>(commentButton).onPressed;
    expect(onPressed, isNotNull);
    onPressed!();
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets(
      'tapping the Comment icon on a Pop card opens PopSingleClipScreen, '
      'same as tapping the card itself', (tester) async {
    await tester.pumpWidget(buildHome(
      popCommentTestHomeRepository,
      dropRepository: popCommentTestDropRepository,
      popRepository: popCommentTestPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final commentButton =
        find.widgetWithIcon(IconButton, Icons.mode_comment_outlined);
    expect(commentButton, findsOneWidget);

    final onPressed = tester.widget<IconButton>(commentButton).onPressed;
    expect(onPressed, isNotNull);
    onPressed!();
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(PopSingleClipScreen), findsOneWidget);
  });

  testWidgets('tapping the Search bar opens the "coming soon" placeholder',
      (tester) async {
    await tester.pumpWidget(buildHome(
      searchTestHomeRepository,
      dropRepository: sharedDropRepository,
      popRepository: sharedPopRepository,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ค้นหา (เร็ว ๆ นี้)'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchPlaceholderScreen), findsOneWidget);
    expect(find.text('ฟีเจอร์ค้นหากำลังจะมาเร็ว ๆ นี้'), findsOneWidget);
  });
}
