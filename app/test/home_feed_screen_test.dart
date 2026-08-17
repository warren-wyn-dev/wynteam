import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/presentation/club_page.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/home_feed_screen.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/home/presentation/widgets/home_pop_card.dart';
import 'package:wyn/features/home/presentation/widgets/trending_tile.dart';
import 'package:wyn/features/notification/presentation/notification_list_screen.dart';
import 'package:wyn/features/pop/presentation/widgets/pop_comment_sheet.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/search/presentation/search_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/fake_video_player_platform.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_home_repository.dart';
import 'support/recording_notification_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';
import 'support/recording_zoky_repository.dart';

HomeFeedItem _dropItem({
  String id = 'd1',
  int likeCount = 0,
  bool likedByMe = false,
  String caption = 'แคปชัน Drop',
}) =>
    HomeFeedItem(
      id: id,
      contentType: HomeContentType.drop,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      createdAt: DateTime.now(),
      caption: caption,
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

Club _club({required String id, required String name, int memberCount = 1}) => Club(
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
  late RecordingNotificationRepository sharedNotificationRepository;
  late RecordingClubRepository sharedClubRepository;
  late RecordingZokyRepository sharedZokyRepository;
  late RecordingClubPostRepository sharedClubPostRepository;
  late RecordingClubPostRepository emptyFromClubsPostRepository;
  late RecordingClubPostRepository fromClubsPostRepository;
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

  late RecordingNotificationRepository fewUnreadNotificationRepository;
  late RecordingNotificationRepository manyUnreadNotificationRepository;
  late RecordingNotificationRepository noUnreadNotificationRepository;
  late RecordingHomeRepository badgeTestHomeRepository;
  late RecordingDropRepository badgeTestDropRepository;
  late RecordingPopRepository badgeTestPopRepository;

  // WYN-017: Trending row + Recommended Clubs row.
  late RecordingHomeRepository trendingItemsHomeRepository;
  late RecordingHomeRepository emptyTrendingHomeRepository;
  late RecordingHomeRepository trendingDropOnlyHomeRepository;
  late RecordingHomeRepository trendingPopOnlyHomeRepository;
  late RecordingClubRepository fewClubsRepository;
  late RecordingClubRepository manyClubsRepository;
  late RecordingClubRepository noJoinedClubsRepository;
  late RecordingHomeRepository rankingTestHomeRepository;

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
    sharedNotificationRepository = RecordingNotificationRepository();
    sharedClubRepository = RecordingClubRepository();
    sharedZokyRepository = RecordingZokyRepository();
    sharedClubPostRepository = RecordingClubPostRepository();
    emptyFromClubsPostRepository = RecordingClubPostRepository(fromJoinedClubs: []);
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

    fewUnreadNotificationRepository = RecordingNotificationRepository(unreadCount: 3);
    manyUnreadNotificationRepository = RecordingNotificationRepository(unreadCount: 15);
    noUnreadNotificationRepository = RecordingNotificationRepository(unreadCount: 0);
    badgeTestHomeRepository = RecordingHomeRepository(feedItems: []);
    badgeTestDropRepository = RecordingDropRepository();
    badgeTestPopRepository = RecordingPopRepository();

    trendingItemsHomeRepository = RecordingHomeRepository(
      feedItems: [],
      trendingItems: [_dropItem(id: 'trend-1'), _popItem(id: 'trend-2')],
    );
    emptyTrendingHomeRepository = RecordingHomeRepository(feedItems: [], trendingItems: []);
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
      discoverableClubs: [_club(id: 'popular-1', name: 'Club กำลังนิยม', memberCount: 50)],
    );
    manyClubsRepository = RecordingClubRepository(
      myClubs: [
        _club(id: 'joined-1', name: 'Club หนึ่ง'),
        _club(id: 'joined-2', name: 'Club สอง'),
        _club(id: 'joined-3', name: 'Club สาม'),
      ],
      discoverableClubs: [_club(id: 'popular-1', name: 'Club กำลังนิยม', memberCount: 50)],
    );
    noJoinedClubsRepository = RecordingClubRepository(
      myClubs: [],
      discoverableClubs: [_club(id: 'popular-1', name: 'Club กำลังนิยม', memberCount: 50)],
    );
    rankingTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'latest-only', caption: 'จากล่าสุด')],
      rankedFeedItems: [_dropItem(id: 'ranked-only', caption: 'จากสำหรับคุณ')],
    );
  });

  Widget buildHome(
    RecordingHomeRepository homeRepository, {
    required RecordingDropRepository dropRepository,
    required RecordingPopRepository popRepository,
    RecordingNotificationRepository? notificationRepository,
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
          notificationRepository: notificationRepository ?? sharedNotificationRepository,
          clubRepository: clubRepository ?? sharedClubRepository,
          clubPostRepository: clubPostRepository ?? sharedClubPostRepository,
          zokyRepository: sharedZokyRepository,
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
      scrollable: find.descendant(
        of: find.byKey(const Key('home_feed_list')),
        matching: find.byType(Scrollable),
      ),
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

  testWidgets(
      'shows a relative timestamp under the author name on a Drop card '
      '(WYN-023) -- HomePopCard is deliberately out of scope, see '
      '.wyn/docs/design/wyn-023-home-drop-polish.md Non-goal', (tester) async {
    await tester.pumpWidget(buildHome(
      mixedFeedHomeRepository,
      dropRepository: sharedDropRepository,
      popRepository: sharedPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // _dropItem() defaults createdAt to DateTime.now(), so
    // relativeTimeLabel() renders "เมื่อสักครู่" (diff < 60s) -- exactly
    // one match confirms the Drop card shows it and the Pop card (out of
    // scope this round) doesn't grow a second one by accident.
    expect(find.text('เมื่อสักครู่'), findsOneWidget);
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
      'tapping the Comment icon on a Pop card opens PopSingleClipScreen with '
      'the comment sheet already open (WYN-023 fast-follow on WYN-007 QA '
      'round 2\'s Minor finding)', (tester) async {
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
    // The whole point of R2: no second tap needed once the clip has
    // loaded -- the comment sheet is already showing.
    expect(find.byType(PopCommentSheet), findsOneWidget);
  });

  testWidgets(
      'tapping a Pop card anywhere else (not the Comment icon) opens '
      'PopSingleClipScreen without auto-opening the comment sheet '
      '(WYN-023 regression guard)', (tester) async {
    await tester.pumpWidget(buildHome(
      popCommentTestHomeRepository,
      dropRepository: popCommentTestDropRepository,
      popRepository: popCommentTestPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // Invoke the card's own onTap directly, same as the Comment-icon
    // tests above -- the card's 1:1 media area pushes its own center
    // below the 600px test viewport, so a literal tester.tap() on it
    // would miss (same issue documented on the DS-003 divider test).
    // This is the outermost InkWell (whole-card tap), not the inner one
    // used only for the avatar/name -> onOpenProfile.
    final cardInkWell = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(HomePopCard),
        matching: find.byType(InkWell),
      ).first,
    );
    expect(cardInkWell.onTap, isNotNull);
    cardInkWell.onTap!();
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(PopSingleClipScreen), findsOneWidget);
    expect(find.byType(PopCommentSheet), findsNothing);
  });

  testWidgets('tapping the Search bar opens SearchScreen (WYN-009)',
      (tester) async {
    await tester.pumpWidget(buildHome(
      searchTestHomeRepository,
      dropRepository: sharedDropRepository,
      popRepository: sharedPopRepository,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ค้นหา'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchScreen), findsOneWidget);
  });

  testWidgets('shows the unread notification count as a badge on the '
      'bell icon (WYN-012)', (tester) async {
    await tester.pumpWidget(buildHome(
      badgeTestHomeRepository,
      dropRepository: badgeTestDropRepository,
      popRepository: badgeTestPopRepository,
      notificationRepository: fewUnreadNotificationRepository,
    ));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('caps the notification badge at "9+" rather than showing the '
      'exact count once it is in double digits (WYN-012)', (tester) async {
    await tester.pumpWidget(buildHome(
      badgeTestHomeRepository,
      dropRepository: badgeTestDropRepository,
      popRepository: badgeTestPopRepository,
      notificationRepository: manyUnreadNotificationRepository,
    ));
    await tester.pumpAndSettle();

    expect(find.text('9+'), findsOneWidget);
    expect(find.text('15'), findsNothing);
  });

  testWidgets('hides the badge entirely when there are no unread '
      'notifications (WYN-012)', (tester) async {
    await tester.pumpWidget(buildHome(
      badgeTestHomeRepository,
      dropRepository: badgeTestDropRepository,
      popRepository: badgeTestPopRepository,
      notificationRepository: noUnreadNotificationRepository,
    ));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing);
  });

  testWidgets('tapping the notification bell opens NotificationListScreen '
      '(WYN-012)', (tester) async {
    await tester.pumpWidget(buildHome(
      badgeTestHomeRepository,
      dropRepository: badgeTestDropRepository,
      popRepository: badgeTestPopRepository,
      notificationRepository: fewUnreadNotificationRepository,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationListScreen), findsOneWidget);
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

    testWidgets('switching to "จาก Club ของคุณ" shows Club posts instead of Drop/Pop',
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
      // WYN-023 adds a "สำรวจ Club" button under the join-prompt text, so
      // this empty state now needs more vertical room than the default
      // 800x600 test viewport leaves after ClubSection/Trending/toggle --
      // same tall-viewport fix as the DS-003 divider test above (mirrors
      // store_screen_test.dart's tester.view.physicalSize pattern).
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

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
      // ClubSection above the toggle always shows its own "สำรวจ Club"
      // button too -- scope this to the one inside FromYourClubsFeed's
      // empty state specifically so the assertion isn't vacuously
      // satisfied by that pre-existing button.
      final emptyStateExploreButton = find.descendant(
        of: find.byKey(const Key('from_your_clubs_feed')),
        matching: find.widgetWithText(OutlinedButton, 'สำรวจ Club'),
      );
      expect(emptyStateExploreButton, findsOneWidget);
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
    testWidgets('"สำหรับคุณ" (default) calls fetchRankedFeed, not the '
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

    testWidgets('switching back to "สำหรับคุณ" from "ล่าสุด" restores the ranked feed',
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

    testWidgets('all 3 segments ("สำหรับคุณ"/"ล่าสุด"/"จาก Club ของคุณ") are present',
        (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('สำหรับคุณ'), findsOneWidget);
      expect(find.text('ล่าสุด'), findsOneWidget);
      expect(find.text('จาก Club ของคุณ'), findsOneWidget);
    });
  });

  group('Trending row (WYN-017)', () {
    testWidgets('shows the "กำลังนิยม" header and items when trending content exists',
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

    testWidgets('shows an empty message instead of crashing when there is no trending content',
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

    testWidgets('tapping a Drop trending tile opens DropDetailScreen', (tester) async {
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

    testWidgets('tapping a Pop trending tile opens PopSingleClipScreen', (tester) async {
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
    testWidgets('shows "Club แนะนำ" when the user has joined fewer than 3 Clubs',
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
