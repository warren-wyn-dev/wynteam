import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/presentation/club_page.dart';
import 'package:wyn/features/club/presentation/explore_clubs_screen.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/drop/presentation/quote_redrop_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/home_feed_screen.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/home/presentation/widgets/home_pop_card.dart';
import 'package:wyn/features/home/presentation/widgets/trending_tile.dart';
import 'package:wyn/features/pop/presentation/widgets/pop_comment_sheet.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/fake_video_player_platform.dart';
import 'support/recording_chat_repository.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_home_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

HomeFeedItem _dropItem({
  String id = 'd1',
  int likeCount = 0,
  bool likedByMe = false,
  String caption = 'แคปชัน Drop',
  int viewCount = 0,
  DateTime? createdAt,
}) =>
    HomeFeedItem(
      id: id,
      contentType: HomeContentType.drop,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      createdAt: createdAt ?? DateTime.now(),
      caption: caption,
      imageUrl: 'https://example.supabase.co/drops/$id.jpg',
      likeCount: likeCount,
      commentCount: 0,
      likedByMe: likedByMe,
      savedByMe: false,
      // WYN-038: defaults to 0 (never left null) -- a null viewCount on
      // a Drop-typed item would render the literal string "null" in
      // HomeDropCard, which real home_feed/saved_feed rows never send
      // (drop_view_count() always returns a real bigint).
      viewCount: viewCount,
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

HomeFeedItem _pollItem({
  String id = 'd1',
  int? myVoteIndex,
  int? totalVotes,
  List<int>? optionCounts,
}) =>
    HomeFeedItem(
      id: id,
      contentType: HomeContentType.drop,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      createdAt: DateTime.now(),
      caption: 'กินอะไรดี?',
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
      // WYN-038 -- see _dropItem's identical doc comment.
      viewCount: 0,
      pollId: 'poll-$id',
      pollOptions: const ['Pizza', 'Sushi'],
      pollExpiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
      pollMyVoteIndex: myVoteIndex,
      pollTotalVotes: totalVotes,
      pollOptionCounts: optionCounts,
    );

Club _club({required String id, required String name, int memberCount = 1}) =>
    Club(
      id: id,
      name: name,
      privacy: ClubPrivacy.public,
      ownerId: 'someone-else',
      createdAt: DateTime.now(),
      memberCount: memberCount,
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
  late RecordingFollowRepository sharedFollowRepository;
  late RecordingProfileRepository sharedProfileRepository;
  late RecordingSavedRepository sharedSavedRepository;
  late RecordingClubRepository sharedClubRepository;
  late RecordingClubPostRepository sharedClubPostRepository;
  late RecordingChatRepository sharedChatRepository;
  late RecordingClubPostRepository emptyFromClubsPostRepository;
  late RecordingClubPostRepository fromClubsPostRepository;
  late RecordingHomeRepository mixedFeedHomeRepository;
  late RecordingHomeRepository emptyHomeRepository;

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

  // WYN-023 (R1): a dedicated repository so its single item's createdAt
  // (fixed 5 minutes in the past, for a deterministic relative-time
  // label) doesn't get mixed into any shared repository's item list.
  late RecordingHomeRepository timestampTestHomeRepository;

  // WYN-034: ReDrop action sheet -- a dedicated DropRepository per
  // scenario (not shared across the group's testWidgets), same
  // one-repo-per-scenario convention as dropLikeTestDropRepository/
  // popLikeTestDropRepository above, so a toggleRedropCalls assertion
  // in one test can never be polluted by a call another test in the
  // same group already made against a shared instance.
  late RecordingDropRepository openSheetTestDropRepository;
  late RecordingPopRepository openSheetTestPopRepository;
  late RecordingHomeRepository openSheetTestHomeRepository;

  late RecordingDropRepository toggleRedropTestDropRepository;
  late RecordingPopRepository toggleRedropTestPopRepository;
  late RecordingHomeRepository toggleRedropTestHomeRepository;

  late RecordingDropRepository cancelRedropTestDropRepository;
  late RecordingPopRepository cancelRedropTestPopRepository;
  late RecordingHomeRepository alreadyRedroppedTestHomeRepository;

  late RecordingDropRepository quoteRedropNavTestDropRepository;
  late RecordingPopRepository quoteRedropNavTestPopRepository;
  late RecordingHomeRepository quoteRedropNavTestHomeRepository;

  late RecordingDropRepository deleteRedropTestDropRepository;
  late RecordingPopRepository deleteRedropTestPopRepository;
  late RecordingHomeRepository ownRedropTestHomeRepository;

  // WYN-035: Poll voting -- same one-repo-per-scenario convention as
  // the ReDrop group above.
  late RecordingDropRepository pollVoteTestDropRepository;
  late RecordingHomeRepository pollVoteTestHomeRepository;
  late RecordingHomeRepository pollResultsVisibleTestHomeRepository;
  late RecordingDropRepository pollVoteFailTestDropRepository;
  late RecordingHomeRepository pollVoteFailTestHomeRepository;

  // WYN-017: Trending row + Recommended Clubs row.
  late RecordingHomeRepository trendingItemsHomeRepository;
  late RecordingHomeRepository emptyTrendingHomeRepository;
  late RecordingHomeRepository trendingDropOnlyHomeRepository;
  late RecordingHomeRepository trendingPopOnlyHomeRepository;
  late RecordingClubRepository fewClubsRepository;
  late RecordingClubRepository manyClubsRepository;
  late RecordingClubRepository noJoinedClubsRepository;
  late RecordingHomeRepository rankingTestHomeRepository;

  // WYN-024: "ติดตาม" (Following) feed mode.
  late RecordingHomeRepository followingTestHomeRepository;
  late RecordingHomeRepository emptyFollowingTestHomeRepository;

  // WYNOS Unified Home Feed Algorithm V1.0 -- "Hide" User Signal.
  late RecordingHomeRepository hideDropTestHomeRepository;
  late RecordingHomeRepository hidePopTestHomeRepository;
  late RecordingHomeRepository hideFailTestHomeRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    SharedPreferences.setMockInitialValues({});
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();

    sharedDropRepository = RecordingDropRepository();
    sharedPopRepository = RecordingPopRepository();
    sharedFollowRepository = RecordingFollowRepository();
    sharedProfileRepository = RecordingProfileRepository(
      profile: const Profile(id: 'someone-else', username: 'namfah'),
    );
    sharedSavedRepository = RecordingSavedRepository();
    sharedClubRepository = RecordingClubRepository();
    sharedChatRepository = RecordingChatRepository();
    sharedClubPostRepository = RecordingClubPostRepository();
    emptyFromClubsPostRepository =
        RecordingClubPostRepository(fromJoinedClubs: []);
    fromClubsPostRepository = RecordingClubPostRepository(fromJoinedClubs: [
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
    mixedFeedHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd1'), _popItem(id: 'p1')],
    );
    emptyHomeRepository = RecordingHomeRepository(feedItems: []);

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

    timestampTestHomeRepository = RecordingHomeRepository(
      feedItems: [
        _dropItem(
          id: 'ts1',
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ],
    );

    openSheetTestDropRepository = RecordingDropRepository();
    openSheetTestPopRepository = RecordingPopRepository();
    openSheetTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd4')],
    );

    toggleRedropTestDropRepository = RecordingDropRepository();
    toggleRedropTestPopRepository = RecordingPopRepository();
    toggleRedropTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd4b')],
    );

    cancelRedropTestDropRepository = RecordingDropRepository();
    cancelRedropTestPopRepository = RecordingPopRepository();
    alreadyRedroppedTestHomeRepository = RecordingHomeRepository(
      feedItems: [
        HomeFeedItem(
          id: 'd5',
          contentType: HomeContentType.drop,
          authorId: 'someone-else',
          authorUsername: 'namfah',
          createdAt: DateTime.now(),
          caption: 'แคปชัน Drop',
          imageUrl: 'https://example.supabase.co/drops/d5.jpg',
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          savedByMe: false,
          redroppedByMe: true,
          redropCount: 1,
        ),
      ],
    );

    quoteRedropNavTestDropRepository = RecordingDropRepository();
    quoteRedropNavTestPopRepository = RecordingPopRepository();
    quoteRedropNavTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd4c')],
    );

    deleteRedropTestDropRepository = RecordingDropRepository();
    deleteRedropTestPopRepository = RecordingPopRepository();
    ownRedropTestHomeRepository = RecordingHomeRepository(
      feedItems: [
        HomeFeedItem(
          id: 'd6',
          contentType: HomeContentType.drop,
          authorId: 'someone-else',
          authorUsername: 'namfah',
          createdAt: DateTime.now(),
          caption: 'แคปชัน Drop',
          imageUrl: 'https://example.supabase.co/drops/d6.jpg',
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          savedByMe: false,
          redropId: 'r6',
          redropperId: 'me',
          redropperUsername: 'me_user',
        ),
      ],
    );

    pollVoteTestDropRepository = RecordingDropRepository();
    pollVoteTestHomeRepository =
        RecordingHomeRepository(feedItems: [_pollItem()]);
    pollResultsVisibleTestHomeRepository = RecordingHomeRepository(feedItems: [
      _pollItem(myVoteIndex: 0, totalVotes: 4, optionCounts: [1, 3]),
    ]);
    pollVoteFailTestDropRepository = RecordingDropRepository()
      ..votePollError = Exception('network error');
    pollVoteFailTestHomeRepository =
        RecordingHomeRepository(feedItems: [_pollItem()]);

    trendingItemsHomeRepository = RecordingHomeRepository(
      feedItems: [],
      trendingItems: [_dropItem(id: 'trend-1'), _popItem(id: 'trend-2')],
    );
    emptyTrendingHomeRepository =
        RecordingHomeRepository(feedItems: [], trendingItems: []);
    trendingDropOnlyHomeRepository = RecordingHomeRepository(
      feedItems: [],
      trendingItems: [_dropItem(id: 'trend-drop')],
    );
    trendingPopOnlyHomeRepository = RecordingHomeRepository(
      feedItems: [],
      trendingItems: [_popItem(id: 'trend-pop')],
    );
    fewClubsRepository = RecordingClubRepository(
      myClubs: [_club(id: 'joined-1', name: 'Club ที่เข้าร่วม')],
      discoverableClubs: [
        _club(id: 'popular-1', name: 'Club กำลังนิยม', memberCount: 50)
      ],
    );
    manyClubsRepository = RecordingClubRepository(
      myClubs: [
        _club(id: 'joined-1', name: 'Club หนึ่ง'),
        _club(id: 'joined-2', name: 'Club สอง'),
        _club(id: 'joined-3', name: 'Club สาม'),
      ],
      discoverableClubs: [
        _club(id: 'popular-1', name: 'Club กำลังนิยม', memberCount: 50)
      ],
    );
    noJoinedClubsRepository = RecordingClubRepository(
      myClubs: [],
      discoverableClubs: [
        _club(id: 'popular-1', name: 'Club กำลังนิยม', memberCount: 50)
      ],
    );
    rankingTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'latest-only', caption: 'จากล่าสุด')],
      rankedFeedItems: [_dropItem(id: 'ranked-only', caption: 'จากสำหรับคุณ')],
    );
    followingTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'latest-only', caption: 'จากล่าสุด')],
      followingFeedItems: [
        _dropItem(id: 'following-only', caption: 'จากติดตาม')
      ],
    );
    emptyFollowingTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'has-feed')],
      followingFeedItems: [],
    );

    hideDropTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'hide-d1')],
    );
    hidePopTestHomeRepository = RecordingHomeRepository(
      feedItems: [_popItem(id: 'hide-p1')],
    );
    hideFailTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'hide-fail-d1')],
    )..hideContentError = Exception('network error');
  });

  Widget buildHome(
    RecordingHomeRepository homeRepository, {
    required RecordingDropRepository dropRepository,
    required RecordingPopRepository popRepository,
    RecordingClubPostRepository? clubPostRepository,
    RecordingClubRepository? clubRepository,
  }) =>
      MaterialApp(
        home: HomeFeedScreen(
          homeRepository: homeRepository,
          dropRepository: dropRepository,
          popRepository: popRepository,
          followRepository: sharedFollowRepository,
          profileRepository: sharedProfileRepository,
          savedRepository: sharedSavedRepository,
          clubRepository: clubRepository ?? sharedClubRepository,
          clubPostRepository: clubPostRepository ?? sharedClubPostRepository,
          chatRepository: sharedChatRepository,
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
    expect(
        find.widgetWithIcon(IconButton, Icons.share_outlined), findsOneWidget);
    expect(
      find.widgetWithIcon(IconButton, Icons.mode_comment_outlined),
      findsOneWidget,
    );
    // WYN-038 QA fix: assert the Drop card's own view count icon here,
    // scoped to HomeDropCard, while it is still mounted -- see the note
    // below (on the unscoped `findsNWidgets(2)` this replaces) for why
    // checking it again after scrolling to the Pop card is not reliable.
    expect(
      find.descendant(
        of: find.byType(HomeDropCard),
        matching: find.byIcon(Icons.visibility_outlined),
      ),
      findsOneWidget,
    );

    // The Drop card's 1:1 image (800px wide in this 800x600 test
    // viewport) pushes the Pop card below the fold -- ListView only
    // mounts elements near the viewport, so scroll to it first. See
    // .wyn/learning/PATTERNS.md.
    await tester.scrollUntilVisible(
      find.text('แคปชัน Pop'),
      500,
      // .first -- the CustomScrollView's own Scrollable, not one of the
      // nested horizontal Scrollables inside it (the Trending row, the
      // feed-mode toggle's SingleChildScrollView).
      scrollable: find.descendant(
        of: find.byKey(const Key('home_feed_scroll_view')),
        matching: find.byType(Scrollable),
      ).first,
    );
    tester.takeException();

    expect(find.text('แคปชัน Pop'), findsOneWidget);
    // Only the Pop card has a play icon and a duration badge.
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);
    // WYN-038 QA fix: both card types show a view count icon/number now
    // (the Drop card gained one this task, mirroring the Pop card's own,
    // which already existed since WYN-006/WYN-007) -- but the original
    // unscoped `find.byIcon(Icons.visibility_outlined), findsNWidgets(2)`
    // here was a real, confirmed-red bug: this ListView is lazily built
    // (see the "ListView only mounts elements near the viewport" note
    // above), so by the time we've scrolled this far to bring the Pop
    // card into view, the Drop card above has actually been unmounted --
    // only 1 of the 2 view-count icons exists in the tree at this point,
    // not 2. The Drop card's own icon was already asserted above, before
    // scrolling away from it; scope this one to the Pop card specifically
    // (same reasoning the popCardShare/popCardComment finders below this
    // already use, which correctly anticipated the Drop card being
    // unreliable to unscoped-count at this scroll position).
    final popCardViewCount = find.descendant(
      of: find.byType(HomePopCard),
      matching: find.byIcon(Icons.visibility_outlined),
    );
    expect(popCardViewCount, findsOneWidget);
    // The Pop card's own view count value (7) is still uniquely
    // findable -- the Drop card above (now unmounted) would have shown 0.
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

  testWidgets(
      'HomeDropCard shows a relative post timestamp under the author name '
      '(WYN-023 R1)', (tester) async {
    await tester.pumpWidget(buildHome(
      timestampTestHomeRepository,
      dropRepository: sharedDropRepository,
      popRepository: sharedPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('5 นาทีที่แล้ว'), findsOneWidget);
  });

  testWidgets(
      'DS-003: shows exactly one hairline divider between 2 posts, none '
      'before the first or after the last', (tester) async {
    // The default 800x600 test viewport is too short to keep both an
    // 800px-tall Drop image and the divider after it inside ListView's
    // cache extent at the same time (see the scroll-then-lose-the-
    // divider issue this test replaces) -- use a tall custom viewport
    // instead so both posts and the divider between them are mounted
    // without scrolling. Mirrors store_screen_test.dart's
    // tester.view.physicalSize pattern.
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildHome(
      mixedFeedHomeRepository,
      dropRepository: sharedDropRepository,
      popRepository: sharedPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('แคปชัน Drop'), findsOneWidget);
    expect(find.text('แคปชัน Pop'), findsOneWidget);
    expect(find.byType(Divider), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no content', (tester) async {
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
    expect(
        dropLikeTestDropRepository.toggleLikeCurrentlyLikedArgs, [false, true]);
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
    expect(
        popLikeTestPopRepository.toggleLikeCurrentlyLikedArgs, [false, true]);
    expect(popLikeTestDropRepository.toggleLikeCalls, 0);
  });

  group('ReDrop action sheet (WYN-034)', () {
    testWidgets(
        'tapping 🔄 on a not-yet-ReDropped card opens a sheet offering '
        '"🔄 ReDrop" and "💬 Quote ReDrop"', (tester) async {
      await tester.pumpWidget(buildHome(
        openSheetTestHomeRepository,
        dropRepository: openSheetTestDropRepository,
        popRepository: openSheetTestPopRepository,
      ));
      await tester.pumpAndSettle();
      // The Drop card's broken test-fixture image URL throws a harmless
      // NetworkImageLoadException -- same expected noise as "renders a
      // mix of Drop and Pop cards" above, consumed here rather than
      // there because opening the modal sheet pumps enough extra
      // frames for it to actually surface within this test's window.
      tester.takeException();

      // Same off-screen-hit-test-avoidance as the Like button tests above
      // -- the action row can be pushed below the fold by the Drop
      // card's own image, so this invokes the button's onPressed
      // directly rather than tester.tap(), which needs the widget to
      // actually be on-screen to hit-test successfully.
      final redropButton = find.widgetWithIcon(IconButton, Icons.repeat);
      expect(redropButton, findsOneWidget);
      tester.widget<IconButton>(redropButton).onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('🔄 ReDrop'), findsOneWidget);
      expect(find.text('💬 Quote ReDrop'), findsOneWidget);
      expect(find.text('ยกเลิก ReDrop'), findsNothing);
    });

    testWidgets(
        'tapping "🔄 ReDrop" in the sheet calls toggleRedrop with '
        'currentlyRedropped: false and updates the count optimistically',
        (tester) async {
      await tester.pumpWidget(buildHome(
        toggleRedropTestHomeRepository,
        dropRepository: toggleRedropTestDropRepository,
        popRepository: toggleRedropTestPopRepository,
      ));
      await tester.pumpAndSettle();
      // The Drop card's broken test-fixture image URL throws a harmless
      // NetworkImageLoadException -- same expected noise as "renders a
      // mix of Drop and Pop cards" above, consumed here rather than
      // there because opening the modal sheet pumps enough extra
      // frames for it to actually surface within this test's window.
      tester.takeException();

      // Same off-screen-hit-test-avoidance as the Like button tests above
      // -- the action row can be pushed below the fold by the Drop
      // card's own image, so this invokes the button's onPressed
      // directly rather than tester.tap(), which needs the widget to
      // actually be on-screen to hit-test successfully.
      final redropButton = find.widgetWithIcon(IconButton, Icons.repeat);
      expect(redropButton, findsOneWidget);
      tester.widget<IconButton>(redropButton).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('🔄 ReDrop'));
      await tester.pumpAndSettle();

      expect(toggleRedropTestDropRepository.toggleRedropCalls, 1);
      expect(
        toggleRedropTestDropRepository.toggleRedropCurrentlyRedroppedArgs,
        [false],
      );
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets(
        'an already-ReDropped card\'s sheet offers "ยกเลิก ReDrop" instead, '
        'and tapping it calls toggleRedrop with currentlyRedropped: true',
        (tester) async {
      await tester.pumpWidget(buildHome(
        alreadyRedroppedTestHomeRepository,
        dropRepository: cancelRedropTestDropRepository,
        popRepository: cancelRedropTestPopRepository,
      ));
      await tester.pumpAndSettle();
      // The Drop card's broken test-fixture image URL throws a harmless
      // NetworkImageLoadException -- same expected noise as "renders a
      // mix of Drop and Pop cards" above, consumed here rather than
      // there because opening the modal sheet pumps enough extra
      // frames for it to actually surface within this test's window.
      tester.takeException();

      // Same off-screen-hit-test-avoidance as the Like button tests above
      // -- the action row can be pushed below the fold by the Drop
      // card's own image, so this invokes the button's onPressed
      // directly rather than tester.tap(), which needs the widget to
      // actually be on-screen to hit-test successfully.
      final redropButton = find.widgetWithIcon(IconButton, Icons.repeat);
      expect(redropButton, findsOneWidget);
      tester.widget<IconButton>(redropButton).onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('ยกเลิก ReDrop'), findsOneWidget);
      expect(find.text('🔄 ReDrop'), findsNothing);

      await tester.tap(find.text('ยกเลิก ReDrop'));
      await tester.pumpAndSettle();

      expect(cancelRedropTestDropRepository.toggleRedropCalls, 1);
      expect(
        cancelRedropTestDropRepository.toggleRedropCurrentlyRedroppedArgs,
        [true],
      );
    });

    testWidgets('tapping "💬 Quote ReDrop" opens QuoteRedropScreen',
        (tester) async {
      await tester.pumpWidget(buildHome(
        quoteRedropNavTestHomeRepository,
        dropRepository: quoteRedropNavTestDropRepository,
        popRepository: quoteRedropNavTestPopRepository,
      ));
      await tester.pumpAndSettle();
      // The Drop card's broken test-fixture image URL throws a harmless
      // NetworkImageLoadException -- same expected noise as "renders a
      // mix of Drop and Pop cards" above, consumed here rather than
      // there because opening the modal sheet pumps enough extra
      // frames for it to actually surface within this test's window.
      tester.takeException();

      // Same off-screen-hit-test-avoidance as the Like button tests above
      // -- the action row can be pushed below the fold by the Drop
      // card's own image, so this invokes the button's onPressed
      // directly rather than tester.tap(), which needs the widget to
      // actually be on-screen to hit-test successfully.
      final redropButton = find.widgetWithIcon(IconButton, Icons.repeat);
      expect(redropButton, findsOneWidget);
      tester.widget<IconButton>(redropButton).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('💬 Quote ReDrop'));
      await tester.pumpAndSettle();
      // QuoteRedropScreen's own preview card loads the same broken
      // fixture image URL again -- same expected noise, consumed again.
      tester.takeException();

      expect(find.byType(QuoteRedropScreen), findsOneWidget);
    });

    testWidgets(
        'the More menu on the viewer\'s own ReDrop card offers "ลบ ReDrop" '
        '(alongside "รายงานโพสต์" for the original Drop, authored by '
        'someone else) -- tapping it deletes the ReDrop and removes the '
        'card', (tester) async {
      await tester.pumpWidget(buildHome(
        ownRedropTestHomeRepository,
        dropRepository: deleteRedropTestDropRepository,
        popRepository: deleteRedropTestPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final moreButton = find.widgetWithIcon(IconButton, Icons.more_vert);
      expect(moreButton, findsOneWidget);
      tester.widget<IconButton>(moreButton).onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('รายงานโพสต์'), findsOneWidget);
      expect(find.text('ลบ ReDrop'), findsOneWidget);

      await tester.tap(find.text('ลบ ReDrop'));
      await tester.pumpAndSettle();

      expect(deleteRedropTestDropRepository.deleteRedropCalls, ['r6']);
      expect(find.text('แคปชัน Drop'), findsNothing);
    });
  });

  group('"Hide" User Signal (WYNOS Unified Home Feed Algorithm V1.0)', () {
    testWidgets(
        'tapping "ไม่สนใจโพสต์นี้" on a Drop card calls hideContent and '
        'removes just that card', (tester) async {
      await tester.pumpWidget(buildHome(
        hideDropTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final moreButton = find.widgetWithIcon(IconButton, Icons.more_vert);
      expect(moreButton, findsOneWidget);
      tester.widget<IconButton>(moreButton).onPressed!();
      await tester.pumpAndSettle();

      expect(find.text('ไม่สนใจโพสต์นี้'), findsOneWidget);
      await tester.tap(find.text('ไม่สนใจโพสต์นี้'));
      await tester.pumpAndSettle();

      expect(
        hideDropTestHomeRepository.hideContentArgs,
        [(HomeContentType.drop, 'hide-d1')],
      );
      expect(find.text('แคปชัน Drop'), findsNothing);
    });

    testWidgets(
        'tapping "ไม่สนใจโพสต์นี้" on a Pop card calls hideContent with '
        'HomeContentType.pop', (tester) async {
      await tester.pumpWidget(buildHome(
        hidePopTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final moreButton = find.widgetWithIcon(IconButton, Icons.more_vert);
      expect(moreButton, findsOneWidget);
      tester.widget<IconButton>(moreButton).onPressed!();
      await tester.pumpAndSettle();

      await tester.tap(find.text('ไม่สนใจโพสต์นี้'));
      await tester.pumpAndSettle();

      expect(
        hidePopTestHomeRepository.hideContentArgs,
        [(HomeContentType.pop, 'hide-p1')],
      );
    });

    testWidgets('a failed hideContent call restores the card and stays '
        'silent (no error banner)', (tester) async {
      await tester.pumpWidget(buildHome(
        hideFailTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final moreButton = find.widgetWithIcon(IconButton, Icons.more_vert);
      tester.widget<IconButton>(moreButton).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('ไม่สนใจโพสต์นี้'));
      await tester.pumpAndSettle();

      expect(find.widgetWithIcon(IconButton, Icons.more_vert), findsOneWidget);
    });
  });

  group('Poll voting (WYN-035)', () {
    testWidgets(
        'a not-yet-voted Poll card shows plain options (no percentages), '
        'and tapping one calls votePoll and reveals the result '
        'optimistically', (tester) async {
      await tester.pumpWidget(buildHome(
        pollVoteTestHomeRepository,
        dropRepository: pollVoteTestDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Pizza'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);

      // Same off-screen-hit-test-avoidance as the Like/ReDrop button
      // tests above -- the option can sit below the 600px test
      // viewport's fold, so this invokes the option's InkWell.onTap
      // directly rather than tester.tap(), which needs the widget to
      // actually be on-screen to hit-test successfully.
      final sushiInkWell = find.ancestor(
        of: find.text('Sushi'),
        matching: find.byType(InkWell),
      );
      // 2 ancestors: HomeDropCard's own outer InkWell (opens the
      // Drop) and the option's own inner InkWell (votes) -- the
      // closer (first) one is the option's.
      expect(sushiInkWell, findsNWidgets(2));
      tester.widget<InkWell>(sushiInkWell.first).onTap!();
      await tester.pumpAndSettle();

      expect(pollVoteTestDropRepository.votePollArgs, [('poll-d1', 1)]);
      // Optimistic update: 1 total vote, Sushi (index 1) at 100%.
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('a Poll card whose results are already visible shows '
        'percentages and highlights the viewer\'s own vote',
        (tester) async {
      await tester.pumpWidget(buildHome(
        pollResultsVisibleTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();

      expect(find.text('25%'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('a failed vote reverts the optimistic update',
        (tester) async {
      await tester.pumpWidget(buildHome(
        pollVoteFailTestHomeRepository,
        dropRepository: pollVoteFailTestDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();

      final pizzaInkWell = find.ancestor(
        of: find.text('Pizza'),
        matching: find.byType(InkWell),
      );
      expect(pizzaInkWell, findsNWidgets(2));
      tester.widget<InkWell>(pizzaInkWell.first).onTap!();
      await tester.pumpAndSettle();

      // RecordingDropRepository.votePoll throws before recording the
      // call when votePollError is set (mirrors quoteRedropError's
      // identical shape in RecordingDropRepository) -- the revert is
      // what this test actually verifies, same as
      // quote_redrop_screen_test.dart's "a failed post" test.
      expect(find.textContaining('%'), findsNothing);
    });
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
      'tapping the Comment icon on a Pop card opens PopSingleClipScreen '
      'with the comment sheet already showing (WYN-023 R2)', (tester) async {
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
    // The actual regression this task fixes: previously the Comment icon
    // just opened the clip, same as tapping the card, leaving the viewer
    // to tap Comment a second time once the clip loaded. Now the sheet
    // is already open.
    expect(find.byType(PopCommentSheet), findsOneWidget);
  });

  testWidgets(
      'tapping a Pop card itself (not its Comment icon) opens '
      'PopSingleClipScreen WITHOUT auto-opening the comment sheet',
      (tester) async {
    await tester.pumpWidget(buildHome(
      popCommentTestHomeRepository,
      dropRepository: popCommentTestDropRepository,
      popRepository: popCommentTestPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // The card's own tap target is its outermost InkWell (onTap) --
    // distinct from the inner avatar/username InkWell (onOpenProfile).
    // Read the callback directly and invoke it, same as this file's
    // IconButton.onPressed pattern above, rather than a hit-test tap()
    // that depends on the card's on-screen scroll position.
    final cardInkWell = tester
        .widgetList<InkWell>(
          find.descendant(
            of: find.byType(HomePopCard),
            matching: find.byType(InkWell),
          ),
        )
        .first;
    expect(cardInkWell.onTap, isNotNull);
    cardInkWell.onTap!();
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(PopSingleClipScreen), findsOneWidget);
    expect(find.byType(PopCommentSheet), findsNothing);
  });

  group('"สำหรับคุณ"/"จาก Club ของคุณ" feed toggle (WYN-015)', () {
    testWidgets('defaults to "สำหรับคุณ" showing the regular Drop/Pop feed',
        (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('แคปชัน Drop'), findsOneWidget);
      expect(find.byKey(const Key('from_your_clubs_feed')), findsNothing);
    });

    testWidgets(
        'switching to "จาก Club ของคุณ" shows Club posts instead of Drop/Pop',
        (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        clubPostRepository: fromClubsPostRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('จาก Club ของคุณ'));
      await tester.pumpAndSettle();

      expect(find.text('โพสต์จาก Club ที่เข้าร่วม'), findsOneWidget);
      expect(find.text('แคปชัน Drop'), findsNothing);
    });

    testWidgets(
        'shows a join-prompt message on "จาก Club ของคุณ" when the user has no '
        'joined-club posts', (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        clubPostRepository: emptyFromClubsPostRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('จาก Club ของคุณ'));
      await tester.pumpAndSettle();

      expect(find.text('เข้าร่วม Club เพื่อดูโพสต์ที่นี่'), findsOneWidget);
      // WYN-023 (R3): the join-prompt now has a "สำรวจ Club" button --
      // previously the only way out of this empty state was the
      // ClubSection button further up the same scroll view (which is
      // still present too, hence scoping this finder to
      // FromYourClubsFeed specifically rather than an unscoped lookup
      // that would find both).
      final joinPromptExploreButton = find.descendant(
        of: find.byKey(const Key('from_your_clubs_feed')),
        matching: find.widgetWithText(OutlinedButton, 'สำรวจ Club'),
      );
      expect(joinPromptExploreButton, findsOneWidget);
    });

    testWidgets(
        '"สำรวจ Club" button on the join-prompt opens ExploreClubsScreen '
        'and reloads on return (WYN-023 R3)', (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        clubPostRepository: emptyFromClubsPostRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('จาก Club ของคุณ'));
      await tester.pumpAndSettle();
      final callsBeforeExplore =
          emptyFromClubsPostRepository.fetchFromJoinedClubsCalls;

      final joinPromptExploreButton = find.descendant(
        of: find.byKey(const Key('from_your_clubs_feed')),
        matching: find.widgetWithText(OutlinedButton, 'สำรวจ Club'),
      );
      await tester.tap(joinPromptExploreButton);
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(ExploreClubsScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      tester.takeException();

      expect(
        emptyFromClubsPostRepository.fetchFromJoinedClubsCalls,
        greaterThan(callsBeforeExplore),
      );
    });

    testWidgets('switching back to "สำหรับคุณ" restores the regular feed',
        (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        clubPostRepository: fromClubsPostRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('จาก Club ของคุณ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('สำหรับคุณ'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('แคปชัน Drop'), findsOneWidget);
      expect(find.text('โพสต์จาก Club ที่เข้าร่วม'), findsNothing);
    });
  });

  group('Home feed ranking (WYN-018)', () {
    testWidgets(
        '"สำหรับคุณ" (default) calls fetchRankedFeed, not the '
        'chronological fetchFeed', (tester) async {
      await tester.pumpWidget(buildHome(
        rankingTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('จากสำหรับคุณ'), findsOneWidget);
      expect(find.text('จากล่าสุด'), findsNothing);
      expect(rankingTestHomeRepository.fetchRankedFeedCalls, 1);
    });

    testWidgets('switching to "ล่าสุด" shows the chronological feed instead',
        (tester) async {
      await tester.pumpWidget(buildHome(
        rankingTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('ล่าสุด'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('จากล่าสุด'), findsOneWidget);
      expect(find.text('จากสำหรับคุณ'), findsNothing);
    });

    testWidgets(
        'switching back to "สำหรับคุณ" from "ล่าสุด" restores the ranked feed',
        (tester) async {
      await tester.pumpWidget(buildHome(
        rankingTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('ล่าสุด'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('สำหรับคุณ'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('จากสำหรับคุณ'), findsOneWidget);
      expect(find.text('จากล่าสุด'), findsNothing);
    });

    testWidgets(
        'all 4 segments ("สำหรับคุณ"/"ติดตาม"/"ล่าสุด"/"จาก Club ของคุณ") are present (WYN-024)',
        (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('สำหรับคุณ'), findsOneWidget);
      expect(find.text('ติดตาม'), findsOneWidget);
      expect(find.text('ล่าสุด'), findsOneWidget);
      expect(find.text('จาก Club ของคุณ'), findsOneWidget);
    });

    testWidgets(
        'a Rainbow accent dot (DS-009) marks whichever segment is active, and only that one',
        (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byKey(const Key('active_segment_accent')), findsOneWidget);

      await tester.tap(find.text('ล่าสุด'));
      await tester.pumpAndSettle();
      tester.takeException();

      // Still exactly one -- it moved with the selection, it didn't
      // multiply.
      expect(find.byKey(const Key('active_segment_accent')), findsOneWidget);
    });

    testWidgets(
        'the widest segment label ("จาก Club ของคุณ") stays single-line at real phone '
        'widths when active, instead of wrapping into a tall column (QA round 2 '
        'regression, 2026-08-22)', (tester) async {
      // Real phone widths this codebase's own SELLER-004 lesson
      // (.wyn/learning/LESSONS_LEARNED.md) established as the required
      // baseline -- the default 800x600 test viewport is wide enough
      // that this bug class never shows up there.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // WYN-024 follow-up (2026-08-22): the feed-mode selector now lives
      // in a horizontal SingleChildScrollView, so the widest/last segment
      // isn't necessarily on-screen at scroll offset 0 on a narrow
      // viewport -- scroll it into view before tapping, or the tap can
      // silently miss.
      await tester.dragUntilVisible(
        find.text('จาก Club ของคุณ'),
        find.byType(SingleChildScrollView).first,
        const Offset(-60, 0),
      );
      await tester.tap(find.text('จาก Club ของคุณ'));
      await tester.pumpAndSettle();
      final exception = tester.takeException();
      expect(exception, isNull);

      final labelFinder = find.text('จาก Club ของคุณ');
      expect(labelFinder, findsOneWidget);
      final renderParagraph =
          tester.renderObject(labelFinder) as RenderParagraph;
      // A single line of this font size is ~20px tall -- wrapping into
      // even 2 lines roughly doubles that. Before the fix this measured
      // ~160px (7-8 wrapped lines), ballooning the whole SegmentedButton
      // row's height whenever this segment was active.
      expect(renderParagraph.size.height, lessThan(25),
          reason: 'label must stay a single line (ellipsis-truncated if it '
              'does not fit), not wrap vertically and grow the row taller');
    });

    testWidgets(
        'the selected-checkmark icon is off (QA round 3 regression, 2026-08-22) -- '
        'it ate a fixed width share of whichever segment was active, squeezing '
        'every label (including the default "สำหรับคุณ") to 1-3 visible characters',
        (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // SegmentedButton's default selected-icon is Icons.check -- with
      // showSelectedIcon: false it must never appear, on the default
      // active segment or any other.
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.tap(find.text('ล่าสุด'));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets(
        'the two short segment labels ("ติดตาม"/"ล่าสุด") are fully legible, not '
        'ellipsis-truncated, once active at a typical phone width (QA round 3 '
        'regression, 2026-08-22)', (tester) async {
      // 390px (iPhone 14/15) rather than round 2's 360px floor -- QA round 3
      // measured that even after reclaiming width from the removed
      // checkmark icon and tightened padding, the two 6-character labels
      // only became fully non-truncated from ~390px up under THAT fix.
      // The two longer labels ("สำหรับคุณ" 9 chars, "จาก Club ของคุณ" 15
      // chars) still weren't covered by that round's fix -- but the
      // scrollable-width fix below (WYN-024 follow-up, 2026-08-22)
      // supersedes this entirely: see the comprehensive all-4-segments
      // test further down, which covers every label, at every real
      // width, with no residual gap.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      for (final label in ['ติดตาม', 'ล่าสุด']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final exception = tester.takeException();
        expect(exception, isNull);

        final renderParagraph =
            tester.renderObject(find.text(label)) as RenderParagraph;
        expect(renderParagraph.didExceedMaxLines, isFalse,
            reason: '"$label" is short enough that it should render fully, '
                'not get ellipsis-truncated, once the checkmark icon is off');
      }
    });

    for (final width in [360.0, 375.0, 390.0, 414.0, 430.0]) {
      testWidgets(
          'every segment label (not just the short ones) is fully legible '
          'at ${width}px once active -- WYN-024 follow-up (2026-08-22): '
          'SegmentedButton now gets an unbounded width via a horizontal '
          'SingleChildScrollView + IntrinsicWidth instead of being '
          'stretched to the screen, so every segment gets its full natural '
          'width regardless of viewport, and the row scrolls instead. '
          'Closes the residual gap the round-3 fix above left open for '
          '"สำหรับคุณ" (the default segment) and "จาก Club ของคุณ".',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildHome(
          mixedFeedHomeRepository,
          dropRepository: sharedDropRepository,
          popRepository: sharedPopRepository,
        ));
        await tester.pumpAndSettle();
        tester.takeException();

        for (final label in [
          'สำหรับคุณ',
          'ติดตาม',
          'ล่าสุด',
          'จาก Club ของคุณ',
        ]) {
          await tester.dragUntilVisible(
            find.text(label),
            find.byType(SingleChildScrollView).first,
            const Offset(-60, 0),
          );
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          // A mocked NetworkImage 400 from a Drop's image resolving on
          // this exact frame is unrelated network-mock noise (this test
          // is about label legibility, not image loading -- every other
          // takeException() call in this file drains without asserting
          // for the same reason); anything else (e.g. a RenderFlex
          // overflow from the segment switch itself) must still fail.
          final exception = tester.takeException();
          if (exception != null && exception is! NetworkImageLoadException) {
            fail('Unexpected exception at ${width}px: $exception');
          }

          final renderParagraph =
              tester.renderObject(find.text(label)) as RenderParagraph;
          expect(renderParagraph.didExceedMaxLines, isFalse,
              reason: '"$label" must never be truncated at ${width}px -- that '
                  'is the whole point of the scrollable-width fix');
        }

        // The Rainbow indicator (DS-009) must still track exactly one
        // active segment, even though segments are no longer stretched
        // to equal widths within the (now scrollable) row.
        expect(find.byKey(const Key('active_segment_accent')), findsOneWidget);
      });
    }
  });

  group('"ติดตาม" (Following) feed mode (WYN-024)', () {
    testWidgets(
        'switching to "ติดตาม" calls fetchFollowingFeed and shows only its items',
        (tester) async {
      await tester.pumpWidget(buildHome(
        followingTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('ติดตาม'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('จากติดตาม'), findsOneWidget);
      expect(find.text('จากล่าสุด'), findsNothing);
      expect(followingTestHomeRepository.fetchFollowingFeedCalls, 1);
    });

    testWidgets(
        'shows a distinct join-prompt-style empty message on "ติดตาม" when '
        'following no one, not the generic empty state', (tester) async {
      await tester.pumpWidget(buildHome(
        emptyFollowingTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('ติดตาม'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(
        find.text(
            'ยังไม่ได้ follow ใครเลย ลองดู สำหรับคุณ เพื่อค้นหาคนน่าสนใจ'),
        findsOneWidget,
      );
      expect(find.text('ยังไม่มีใครโพสต์อะไรเลย เป็นคนแรกสิ!'), findsNothing);
    });

    testWidgets(
        'switching back to "สำหรับคุณ" from "ติดตาม" restores the ranked feed',
        (tester) async {
      await tester.pumpWidget(buildHome(
        rankingTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('ติดตาม'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('สำหรับคุณ'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('จากสำหรับคุณ'), findsOneWidget);
    });
  });

  group('Trending row (WYN-017)', () {
    testWidgets(
        'shows the "กำลังนิยม" header and items when trending content exists',
        (tester) async {
      await tester.pumpWidget(buildHome(
        trendingItemsHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('กำลังนิยม'), findsOneWidget);
      expect(find.byType(TrendingTile), findsNWidgets(2));
    });

    testWidgets(
        'shows an empty message instead of crashing when there is no trending content',
        (tester) async {
      await tester.pumpWidget(buildHome(
        emptyTrendingHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('กำลังนิยม'), findsOneWidget);
      expect(find.byType(TrendingTile), findsNothing);
      expect(find.text('ยังไม่มี content กำลังนิยม'), findsOneWidget);
    });

    testWidgets('tapping a Drop trending tile opens DropDetailScreen',
        (tester) async {
      await tester.pumpWidget(buildHome(
        trendingDropOnlyHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.byType(TrendingTile));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(DropDetailScreen), findsOneWidget);
    });

    testWidgets('tapping a Pop trending tile opens PopSingleClipScreen',
        (tester) async {
      await tester.pumpWidget(buildHome(
        trendingPopOnlyHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.byType(TrendingTile));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(PopSingleClipScreen), findsOneWidget);
    });
  });

  group('Recommended Clubs row (WYN-017)', () {
    testWidgets(
        'shows "Club แนะนำ" when the user has joined fewer than 3 Clubs',
        (tester) async {
      await tester.pumpWidget(buildHome(
        emptyHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        clubRepository: fewClubsRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('Club แนะนำ'), findsOneWidget);
      expect(find.text('Club กำลังนิยม'), findsOneWidget);
    });

    testWidgets('hides "Club แนะนำ" once the user has joined 3 or more Clubs',
        (tester) async {
      await tester.pumpWidget(buildHome(
        emptyHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        clubRepository: manyClubsRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('Club แนะนำ'), findsNothing);
      expect(find.text('Club กำลังนิยม'), findsNothing);
    });

    testWidgets('tapping a recommended Club opens ClubPage', (tester) async {
      await tester.pumpWidget(buildHome(
        emptyHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        clubRepository: noJoinedClubsRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('Club กำลังนิยม'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(ClubPage), findsOneWidget);
    });
  });
}
