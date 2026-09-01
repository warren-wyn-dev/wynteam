import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:wyn/core/widgets/action_metric.dart';
import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/club/presentation/explore_clubs_screen.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/drop/presentation/quote_redrop_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/data/home_liker.dart';
import 'package:wyn/features/home/data/home_top_reply.dart';
import 'package:wyn/features/home/presentation/home_feed_screen.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/home/presentation/widgets/home_explainer_banner.dart';
import 'package:wyn/features/home/presentation/widgets/home_pop_card.dart';
import 'package:wyn/features/home/presentation/widgets/liked_by_row.dart';
import 'package:wyn/features/home/presentation/widgets/new_posts_pill.dart';
import 'package:wyn/features/home/presentation/widgets/top_reply_preview.dart';
import 'package:wyn/features/home/presentation/widgets/verified_badge.dart';
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
  bool hasImage = true,
  HomeTopReply? topReply,
  bool authorIsVerified = false,
  List<HomeLiker> likedBy = const [],
}) =>
    HomeFeedItem(
      id: id,
      contentType: HomeContentType.drop,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      authorIsVerified: authorIsVerified,
      createdAt: createdAt ?? DateTime.now(),
      caption: caption,
      imageUrl: hasImage ? 'https://example.supabase.co/drops/$id.jpg' : null,
      likeCount: likeCount,
      likedBy: likedBy,
      commentCount: 0,
      topReply: topReply,
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

/// A RecordingHomeRepository whose fetchRankedFeed never resolves --
/// used only by the WYN-064 "duplicate call while loading" regression
/// test, where the guard needs to be exercised while a fetch is
/// deterministically still in flight rather than relying on
/// microtask-timing luck against the default (immediately-resolving)
/// RecordingHomeRepository. Same never-completed-Completer shape as
/// settings_screen_test.dart's "export in flight" test (see its own doc
/// comment) -- the test only needs to prove the second call never
/// happens while the first is still pending, not observe what happens
/// once it resolves, so nothing here ever completes the gate.
class _DelayedHomeRepository extends RecordingHomeRepository {
  _DelayedHomeRepository({required List<HomeFeedItem> items})
      : super(rankedFeedItems: items);

  final _gate = Completer<void>();

  @override
  Future<List<HomeFeedItem>> fetchRankedFeed({required int page}) async {
    fetchRankedFeedCalls++;
    await _gate.future;
    return page == 0 ? rankedFeedItems : <HomeFeedItem>[];
  }
}

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

  late RecordingHomeRepository rankingTestHomeRepository;

  // WYN-024: "ติดตาม" (Following) feed mode.
  late RecordingHomeRepository followingTestHomeRepository;
  late RecordingHomeRepository emptyFollowingTestHomeRepository;

  // WYNOS Unified Home Feed Algorithm V1.0 -- "Hide" User Signal.
  late RecordingHomeRepository hideDropTestHomeRepository;
  late RecordingHomeRepository hidePopTestHomeRepository;
  late RecordingHomeRepository hideFailTestHomeRepository;

  // WYNOSHomeSpec.md 4.8: Liked-by stacked avatars.
  late RecordingHomeRepository likedByTestHomeRepository;
  late RecordingHomeRepository noLikedByTestHomeRepository;

  // WYNOSHomeSpec.md 4.10: Top reply preview.
  late RecordingHomeRepository topReplyTestHomeRepository;
  late RecordingHomeRepository noTopReplyTestHomeRepository;

  // WYNOSHomeSpec.md 4.9: Verified badge.
  late RecordingHomeRepository verifiedAuthorTestHomeRepository;
  late RecordingHomeRepository unverifiedAuthorTestHomeRepository;

  // WYNOSHomeSpec.md 4.6: Share/Save moved into the "..." menu.
  late RecordingDropRepository moreMenuTestDropRepository;
  late RecordingPopRepository moreMenuTestPopRepository;
  late RecordingHomeRepository moreMenuTestHomeRepository;

  // WYNOSHomeSpec.md 4.4: New-posts pill. A dedicated repository per
  // scenario, same one-repo-per-scenario convention as every other
  // call-count-asserting group above -- newPostsPillTapTestHomeRepository
  // specifically (whose test asserts fetchRankedFeedCalls) must not
  // share an instance with any other test in this group.
  late RecordingHomeRepository newPostsPillTestHomeRepository;
  late RecordingHomeRepository newPostsPillTapTestHomeRepository;

  // WYNOSHomeSpec.md item 1: first-time explainer banner.
  late RecordingHomeRepository explainerBannerTestHomeRepository;

  // WYN-064: Tap Home Tab to Scroll to Top & Refresh -- one repository
  // per scenario, same reasoning as every group above (built once here,
  // not inline inside a testWidgets callback, so its SupabaseClient's
  // auto-refresh Timer doesn't leak and fail the "!timersPending"
  // invariant flutter_test enforces after every test).
  late RecordingHomeRepository scrollToTopTestHomeRepository;
  late RecordingHomeRepository triggerRefreshTestHomeRepository;
  late _DelayedHomeRepository duplicateFetchGuardTestHomeRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    // WYNOSHomeSpec.md item 1: pre-dismissed by default so the one-time
    // explainer banner doesn't add unexpected height above every other
    // test in this file (it's exercised on its own, both dismissed and
    // not, in home_explainer_banner_test.dart and in the dedicated group
    // below).
    SharedPreferences.setMockInitialValues({'home_explainer_banner_dismissed': true});
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

    likedByTestHomeRepository = RecordingHomeRepository(
      feedItems: [
        _dropItem(
          id: 'lb1',
          hasImage: false,
          likeCount: 5,
          likedBy: const [
            HomeLiker(id: 'u1', username: 'warren', displayName: 'Warren'),
            HomeLiker(id: 'u2', username: 'zen', displayName: 'Zen'),
          ],
        ),
      ],
    );
    noLikedByTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'lb2', hasImage: false, likeCount: 5)],
    );

    topReplyTestHomeRepository = RecordingHomeRepository(
      feedItems: [
        _dropItem(
          id: 'tr1',
          hasImage: false,
          topReply: const HomeTopReply(
            authorUsername: 'zen',
            authorDisplayName: 'Zen',
            text: 'สวยมากกก',
          ),
        ),
      ],
    );
    noTopReplyTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'tr2', hasImage: false)],
    );

    verifiedAuthorTestHomeRepository = RecordingHomeRepository(
      feedItems: [
        _dropItem(id: 'v1', hasImage: false, authorIsVerified: true),
      ],
    );
    unverifiedAuthorTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'v2', hasImage: false)],
    );

    moreMenuTestDropRepository = RecordingDropRepository();
    moreMenuTestPopRepository = RecordingPopRepository();
    moreMenuTestHomeRepository = RecordingHomeRepository(
      feedItems: [
        HomeFeedItem(
          id: 'mm1',
          contentType: HomeContentType.drop,
          // 'me' matches initFakeSupabaseSession's userId (setUpAll
          // above) -- the viewer's own Drop.
          authorId: 'me',
          authorUsername: 'me',
          createdAt: DateTime.now(),
          caption: 'โพสต์ของฉันเอง',
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          savedByMe: false,
        ),
      ],
    );

    newPostsPillTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'np1', hasImage: false)],
    );
    newPostsPillTapTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'np2', hasImage: false)],
    );

    explainerBannerTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'exp1', hasImage: false)],
    );

    // hasImage: false -- avoids kicking off 30 concurrent NetworkImage
    // fetches (each fails against the fake "example.supabase.co" host
    // and flutter_test's takeException() can only absorb one exception
    // per call, so more than one in-flight failure fails the test with
    // "Multiple exceptions... at least one was unexpected"). Only the
    // scroll extent matters for this scenario, not the cards' visuals.
    scrollToTopTestHomeRepository = RecordingHomeRepository(
      rankedFeedItems: [
        for (var i = 0; i < 30; i++)
          _dropItem(id: 'scroll-$i', caption: 'โพสต์ที่ $i', hasImage: false),
      ],
    );
    triggerRefreshTestHomeRepository = RecordingHomeRepository(
      rankedFeedItems: [_dropItem(id: 'top-1', hasImage: false)],
    );
    duplicateFetchGuardTestHomeRepository =
        _DelayedHomeRepository(items: [_dropItem(id: 'guard-1', hasImage: false)]);
  });

  Widget buildHome(
    RecordingHomeRepository homeRepository, {
    required RecordingDropRepository dropRepository,
    required RecordingPopRepository popRepository,
    RecordingClubPostRepository? clubPostRepository,
    RecordingClubRepository? clubRepository,
    ValueNotifier<int>? homeTabReselectSignal,
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
          homeTabReselectSignal:
              homeTabReselectSignal ?? ValueNotifier<int>(0),
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
    // must have a tappable Comment icon, not just Like/Save. See
    // .wyn/tasks/approved/WYN-007-home-feed.md.
    expect(
      find.widgetWithIcon(ActionMetric, Icons.mode_comment_outlined),
      findsOneWidget,
    );
    // WYNOSHomeSpec.md 4.6: Share/Save moved out of the action bar into
    // the "..." menu -- the menu button is now always shown (even on
    // the viewer's own plain Drop), and opening it offers both.
    final dropMoreButton = find.descendant(
      of: find.byType(HomeDropCard),
      matching: find.widgetWithIcon(IconButton, Icons.more_vert),
    );
    expect(dropMoreButton, findsOneWidget);
    await tester.tap(dropMoreButton);
    await tester.pumpAndSettle();
    expect(find.text('แชร์'), findsOneWidget);
    expect(find.text('บันทึก'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
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
    // Same "..." menu check as the Drop card above, scoped to the Pop
    // card specifically -- the Drop card above may still be in the
    // element tree (ListView cacheExtent) at this scroll position, so
    // an unscoped findsOneWidget would over-count.
    final popMoreButton = find.descendant(
      of: find.byType(HomePopCard),
      matching: find.widgetWithIcon(IconButton, Icons.more_vert),
    );
    expect(popMoreButton, findsOneWidget);
    await tester.tap(popMoreButton);
    await tester.pumpAndSettle();
    expect(find.text('แชร์'), findsOneWidget);
    expect(find.text('บันทึก'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    final popCardComment = find.descendant(
      of: find.byType(HomePopCard),
      matching: find.widgetWithIcon(ActionMetric, Icons.mode_comment_outlined),
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

    final likeButton = find.widgetWithIcon(ActionMetric, Icons.favorite_border);
    expect(likeButton, findsOneWidget);

    final onPressed = tester.widget<ActionMetric>(likeButton).onTap!;
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

    final likeButton = find.widgetWithIcon(ActionMetric, Icons.favorite_border);
    expect(likeButton, findsOneWidget);

    final onPressed = tester.widget<ActionMetric>(likeButton).onTap!;
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
      final redropButton = find.widgetWithIcon(ActionMetric, Icons.repeat);
      expect(redropButton, findsOneWidget);
      tester.widget<ActionMetric>(redropButton).onTap!();
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
      final redropButton = find.widgetWithIcon(ActionMetric, Icons.repeat);
      expect(redropButton, findsOneWidget);
      tester.widget<ActionMetric>(redropButton).onTap!();
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
      final redropButton = find.widgetWithIcon(ActionMetric, Icons.repeat);
      expect(redropButton, findsOneWidget);
      tester.widget<ActionMetric>(redropButton).onTap!();
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
      final redropButton = find.widgetWithIcon(ActionMetric, Icons.repeat);
      expect(redropButton, findsOneWidget);
      tester.widget<ActionMetric>(redropButton).onTap!();
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
        find.widgetWithIcon(ActionMetric, Icons.mode_comment_outlined);
    expect(commentButton, findsOneWidget);

    // Invoke onTap directly rather than tester.tap(): the card's
    // 1:1 image pushes the interaction row below the 600px test
    // viewport, same as the scroll-to-find issue above -- calling the
    // callback exercises the exact same wiring without needing to
    // scroll it into hit-testable range first.
    final onPressed = tester.widget<ActionMetric>(commentButton).onTap;
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
        find.widgetWithIcon(ActionMetric, Icons.mode_comment_outlined);
    expect(commentButton, findsOneWidget);

    final onPressed = tester.widget<ActionMetric>(commentButton).onTap;
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
      // The join-prompt now lives in a scrollable (_CenterOrScroll --
      // FromYourClubsFeed's own doc comment) rather than a plain Center,
      // so it can need a scroll into view on a short viewport instead of
      // always being on-screen already.
      await tester.ensureVisible(joinPromptExploreButton);
      await tester.tap(joinPromptExploreButton);
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(ExploreClubsScreen), findsOneWidget);

      // ExploreClubsScreen's own header supplies a plain chevron
      // IconButton (Key 'explore_clubs_back_button'), not a Material/
      // Cupertino back button -- tester.pageBack() (which looks for
      // one of those specifically) would find neither. See
      // 09-club-explore.tsx's restyle.
      await tester.tap(find.byKey(const Key('explore_clubs_back_button')));
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
        'shows the WYNOSHomeSpec.md 4.5 suggested-follow empty state on '
        '"ติดตาม" when following no one, not the generic empty state',
        (tester) async {
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

      expect(find.text('ยังไม่มีอะไรให้ดูตรงนี้'), findsOneWidget);
      expect(
        find.text('ลองติดตามคนที่คุณสนใจ เพื่อเริ่มเห็นโพสต์ในหน้านี้'),
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

  // WYN-073: the Trending row (WYN-017) and Recommended Clubs row
  // (ClubSection) were both removed from Home -- both are already
  // reachable from the Search tab (Top100Screen, Club discovery/create),
  // so this is a duplicate-entry-point removal, not a lost capability.
  // See .wyn/docs/design/wyn-073-home-layout-tabs-restyle.md. Their own
  // widget tests (TrendingTile, ClubSection) still cover the underlying
  // widgets directly; only HomeFeedScreen's own wiring of them is gone,
  // so the "Trending row (WYN-017)"/"Recommended Clubs row (WYN-017)"
  // groups that used to live here are deleted rather than fixed.

  group('Tap Home Tab to Scroll to Top & Refresh (WYN-064)', () {
    testWidgets(
        'reselecting Home while scrolled down scrolls back to top without '
        'refetching', (tester) async {
      final reselectSignal = ValueNotifier<int>(0);

      await tester.pumpWidget(buildHome(
        scrollToTopTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        homeTabReselectSignal: reselectSignal,
      ));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(scrollToTopTestHomeRepository.fetchRankedFeedCalls, 1);

      final controller = tester
          .widget<CustomScrollView>(
            find.byKey(const Key('home_feed_scroll_view')),
          )
          .controller!;

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      tester.takeException();
      expect(controller.position.pixels, greaterThan(0));

      reselectSignal.value++;
      await tester.pumpAndSettle();

      expect(controller.position.pixels, 0);
      // Case 1 (Scroll Position > 0 -> Scroll to Top): no refetch, just
      // the scroll animation -- still the single initial-load call.
      expect(scrollToTopTestHomeRepository.fetchRankedFeedCalls, 1);
    });

    testWidgets('reselecting Home while already at the top triggers a refresh',
        (tester) async {
      final reselectSignal = ValueNotifier<int>(0);

      await tester.pumpWidget(buildHome(
        triggerRefreshTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        homeTabReselectSignal: reselectSignal,
      ));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(triggerRefreshTestHomeRepository.fetchRankedFeedCalls, 1);

      // Case 2 (Scroll Position == 0 -> Trigger Pull-to-Refresh).
      reselectSignal.value++;
      await tester.pumpAndSettle();
      tester.takeException();

      expect(triggerRefreshTestHomeRepository.fetchRankedFeedCalls, 2);
    });

    testWidgets(
        'reselecting Home while a refresh is already loading does not fire '
        'a duplicate fetch', (tester) async {
      final reselectSignal = ValueNotifier<int>(0);

      await tester.pumpWidget(buildHome(
        duplicateFetchGuardTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
        homeTabReselectSignal: reselectSignal,
      ));
      // The initial load's fetchRankedFeed call is in flight and never
      // resolves (see _DelayedHomeRepository's doc comment) --
      // _isLoadingInitial stays true for the rest of this test, same as
      // settings_screen_test.dart's "export in flight" test never
      // resolving its own completer either. Not pumpAndSettle -- the
      // indeterminate CircularProgressIndicator this leaves on screen
      // would never let it settle.
      await tester.pump();
      expect(duplicateFetchGuardTestHomeRepository.fetchRankedFeedCalls, 1);

      // Edge case from the ticket: prevent a duplicate API call while
      // already loading. Reselecting Home again here must not start a
      // second concurrent fetch.
      reselectSignal.value++;
      await tester.pump();
      expect(duplicateFetchGuardTestHomeRepository.fetchRankedFeedCalls, 1);
      tester.takeException();
    });
  });

  group('Liked-by stacked avatars (WYNOSHomeSpec.md 4.8)', () {
    testWidgets('shows the row when the card has likers', (tester) async {
      await tester.pumpWidget(buildHome(
        likedByTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(LikedByRow), findsOneWidget);
      expect(find.textContaining('Warren'), findsOneWidget);
      expect(find.textContaining('และอีก 3 คน'), findsOneWidget);
    });

    testWidgets('renders nothing when the card has no liker data',
        (tester) async {
      await tester.pumpWidget(buildHome(
        noLikedByTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.textContaining('ถูกใจโดย'), findsNothing);
    });
  });

  group('Top reply preview (WYNOSHomeSpec.md 4.10)', () {
    testWidgets('shows the reply when the card has one', (tester) async {
      await tester.pumpWidget(buildHome(
        topReplyTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(TopReplyPreview), findsOneWidget);
      expect(find.textContaining('Zen'), findsOneWidget);
      expect(find.textContaining('สวยมากกก'), findsOneWidget);
    });

    testWidgets('renders nothing when the card has no qualifying reply',
        (tester) async {
      await tester.pumpWidget(buildHome(
        noTopReplyTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(TopReplyPreview), findsNothing);
    });

    testWidgets('tapping the reply preview opens DropDetailScreen '
        '(same destination as tapping the card itself)', (tester) async {
      await tester.pumpWidget(buildHome(
        topReplyTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // Same off-screen-hit-test-avoidance as the redrop/comment button
      // tests above -- the action row can push this preview below the
      // fold, so this invokes the callback directly rather than
      // tester.tap(), which needs the widget to actually be on-screen.
      tester.widget<TopReplyPreview>(find.byType(TopReplyPreview)).onTap();
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(DropDetailScreen), findsOneWidget);
    });
  });

  group('Verified badge (WYNOSHomeSpec.md 4.9)', () {
    testWidgets('shows the badge next to a verified author\'s name',
        (tester) async {
      await tester.pumpWidget(buildHome(
        verifiedAuthorTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(VerifiedBadge), findsOneWidget);
    });

    testWidgets('hides the badge for an unverified author', (tester) async {
      await tester.pumpWidget(buildHome(
        unverifiedAuthorTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(VerifiedBadge), findsNothing);
    });
  });

  group('"..." menu Share/Save (WYNOSHomeSpec.md 4.6)', () {
    testWidgets(
        'the "..." menu is shown even on the viewer\'s own plain Drop, '
        'and offers only Share/Save (no Report/Hide/Delete ReDrop)',
        (tester) async {
      await tester.pumpWidget(buildHome(
        moreMenuTestHomeRepository,
        dropRepository: moreMenuTestDropRepository,
        popRepository: moreMenuTestPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final moreButton = find.widgetWithIcon(IconButton, Icons.more_vert);
      expect(moreButton, findsOneWidget);

      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      expect(find.text('แชร์'), findsOneWidget);
      expect(find.text('บันทึก'), findsOneWidget);
      expect(find.text('รายงานโพสต์'), findsNothing);
      expect(find.text('ไม่สนใจโพสต์นี้'), findsNothing);
      expect(find.text('ลบ ReDrop'), findsNothing);
    });

    testWidgets('tapping "บันทึก" in the menu calls DropRepository.toggleSave',
        (tester) async {
      await tester.pumpWidget(buildHome(
        moreMenuTestHomeRepository,
        dropRepository: moreMenuTestDropRepository,
        popRepository: moreMenuTestPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('บันทึก'));
      await tester.pumpAndSettle();

      expect(moreMenuTestDropRepository.toggleSaveCalls, 1);
    });
  });

  group('New-posts pill (WYNOSHomeSpec.md 4.4)', () {
    testWidgets(
        'hidden by default, appears once someone else posts, with the '
        'right count', (tester) async {
      await tester.pumpWidget(buildHome(
        newPostsPillTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(NewPostsPill), findsNothing);

      newPostsPillTestHomeRepository.emitNewPost('someone-else');
      await tester.pump();

      expect(find.byType(NewPostsPill), findsOneWidget);
      expect(find.text('มีโพสต์ใหม่ 1 โพสต์'), findsOneWidget);
    });

    testWidgets('each new post from someone else increments the count',
        (tester) async {
      await tester.pumpWidget(buildHome(
        newPostsPillTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      newPostsPillTestHomeRepository.emitNewPost('someone-else');
      newPostsPillTestHomeRepository.emitNewPost('another-user');
      await tester.pump();

      expect(find.text('มีโพสต์ใหม่ 2 โพสต์'), findsOneWidget);
    });

    testWidgets(
        'a post from the current viewer themselves never shows the pill '
        '(RootShell._openCreateDrop already remounts Home on success)',
        (tester) async {
      await tester.pumpWidget(buildHome(
        newPostsPillTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // 'me' matches initFakeSupabaseSession's userId (setUpAll above).
      newPostsPillTestHomeRepository.emitNewPost('me');
      await tester.pump();

      expect(find.byType(NewPostsPill), findsNothing);
    });

    testWidgets('tapping the pill reloads the feed and clears the pill',
        (tester) async {
      await tester.pumpWidget(buildHome(
        newPostsPillTapTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(newPostsPillTapTestHomeRepository.fetchRankedFeedCalls, 1);

      newPostsPillTapTestHomeRepository.emitNewPost('someone-else');
      await tester.pump();
      expect(find.byType(NewPostsPill), findsOneWidget);

      await tester.tap(find.byType(NewPostsPill));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(newPostsPillTapTestHomeRepository.fetchRankedFeedCalls, 2);
      expect(find.byType(NewPostsPill), findsNothing);
    });
  });

  group('First-time explainer banner (WYNOSHomeSpec.md item 1)', () {
    // The banner's own shown-once/dismiss/persist behavior is covered in
    // isolation by home_explainer_banner_test.dart -- this just confirms
    // HomeFeedScreen actually wires it in above the feed. Every other
    // test in this file pre-dismisses it (see setUpAll's SharedPreferences
    // mock) so its absence there isn't a regression.
    testWidgets('is present above the feed', (tester) async {
      await tester.pumpWidget(buildHome(
        explainerBannerTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // skipOffstage: false -- every other test in this file pre-
      // dismisses the banner (see setUpAll), so it renders a zero-size
      // SizedBox.shrink() here too; the default finder treats that as
      // offstage and would report 0 matches even though the widget is
      // genuinely mounted, which is all this test asserts.
      expect(
        find.byType(HomeExplainerBanner, skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
