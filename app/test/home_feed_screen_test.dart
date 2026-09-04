import 'dart:async';

import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/core/widgets/action_metric.dart';
import 'package:wyn/core/widgets/hashtag_text.dart';
import 'package:wyn/features/club/data/club_post.dart';
import 'package:wyn/features/drop/data/drop.dart' show AudienceOption;
import 'package:wyn/features/club/presentation/explore_clubs_screen.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/drop/presentation/quote_redrop_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/data/home_liker.dart';
import 'package:wyn/features/home/data/home_top_reply.dart';
import 'package:wyn/features/home/presentation/home_feed_screen.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
import 'package:wyn/features/home/presentation/widgets/home_card_metrics.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/home/presentation/widgets/home_explainer_banner.dart';
import 'package:wyn/features/home/presentation/widgets/home_feed_skeleton.dart';
import 'package:wyn/features/home/presentation/widgets/home_feed_image_peek_carousel.dart';
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
import 'package:wyn/core/widgets/action_sheet_row.dart';

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
  int? imageWidth,
  int? imageHeight,
  AudienceOption audience = AudienceOption.everyone,
  String? location,
  int? imageCount,
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
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      // WYN-092: null (the default) means "unknown/not multi-image" --
      // every pre-existing call site that doesn't pass this keeps
      // rendering the single-image path unchanged (hasMultipleImages
      // is false for a null-or-1 imageCount).
      imageCount: imageCount,
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
      audience: audience,
      location: location,
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

/// A RecordingHomeRepository whose ranked feed pages the way offset
/// pagination really does when the list grows underneath the viewer:
/// page 1 comes back carrying page 0's last item again. Used by the
/// duplicate-row regression test below.
class _OverlappingPageHomeRepository extends RecordingHomeRepository {
  _OverlappingPageHomeRepository({
    required this.page0,
    required this.page1,
  }) : super(rankedFeedItems: page0);

  final List<HomeFeedItem> page0;
  final List<HomeFeedItem> page1;

  @override
  Future<List<HomeFeedItem>> fetchRankedFeed({required int page}) async {
    fetchRankedFeedCalls++;
    if (page == 0) return page0;
    if (page == 1) return page1;
    return <HomeFeedItem>[];
  }
}

/// A RecordingHomeRepository whose second page always fails -- for the
/// load-more error/retry test.
class _FailingSecondPageHomeRepository extends RecordingHomeRepository {
  _FailingSecondPageHomeRepository({required this.page0})
      : super(rankedFeedItems: page0);

  final List<HomeFeedItem> page0;

  /// Flipped by the test so the retry can be seen to succeed.
  bool failNextPage = true;

  @override
  Future<List<HomeFeedItem>> fetchRankedFeed({required int page}) async {
    fetchRankedFeedCalls++;
    if (page == 0) return page0;
    if (failNextPage) throw Exception('network down');
    return <HomeFeedItem>[];
  }
}

/// A RecordingDropRepository whose toggleLike stays unresolved until the
/// test releases it -- lets the serialization test observe what happens
/// while the first write is genuinely still in flight, the same
/// controlled-Completer shape _DelayedHomeRepository uses above. Tracks
/// how many writes were open at once, which is the property under test.
class _PendingLikeDropRepository extends RecordingDropRepository {
  // Created on first use, inside the test body's own async zone, rather
  // than in the setUpAll that constructs this repository -- a Completer
  // built in the setUpAll zone schedules its continuations there, and
  // pumpAndSettle would never flush them (the test would hang on a write
  // that can't resume).
  Completer<void>? _gate;

  int openWrites = 0;
  int maxConcurrentWrites = 0;

  void release() => _gate?.complete();

  @override
  Future<void> toggleLike({
    required String dropId,
    required bool currentlyLiked,
  }) async {
    final gate = _gate ??= Completer<void>();
    toggleLikeCalls++;
    toggleLikeCurrentlyLikedArgs.add(currentlyLiked);
    openWrites++;
    if (openWrites > maxConcurrentWrites) maxConcurrentWrites = openWrites;
    if (!gate.isCompleted) await gate.future;
    openWrites--;
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

  // WYN-097 -- Screen 6 (hides the ReDrop button when audience !=
  // everyone).
  late RecordingHomeRepository hiddenRedropButtonTestHomeRepository;

  // WYN-098 -- Screen 4 (shows the check-in location on the card).
  late RecordingHomeRepository locationTestHomeRepository;

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
  // WYN-079: dedicated instance, not shared with hideDropTestHomeRepository
  // above -- every fixture in this file is set up once in setUpAll (see
  // below), not per-test, so two tests sharing one RecordingHomeRepository
  // would leak call-log state (hideContentArgs/unhideContentArgs) between
  // them the same way every other "Hide" test here already avoids by
  // using its own dedicated instance.
  late RecordingHomeRepository hideDropUndoTimeoutTestHomeRepository;

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
  late _OverlappingPageHomeRepository overlappingPageHomeRepository;
  late _PendingLikeDropRepository pendingLikeDropRepository;
  late RecordingHomeRepository pendingLikeHomeRepository;
  late RecordingHomeRepository backFromDetailHomeRepository;
  late _FailingSecondPageHomeRepository failingSecondPageHomeRepository;
  late RecordingHomeRepository slowInitialHomeRepository;

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

    hiddenRedropButtonTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd4c', audience: AudienceOption.friends)],
    );

    locationTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'd4d', location: 'สยามพารากอน')],
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
    hideDropUndoTimeoutTestHomeRepository = RecordingHomeRepository(
      feedItems: [_dropItem(id: 'hide-undo-timeout-d1')],
    );

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

    // A full page (pageSize == 10, so _hasMore stays true and the feed
    // will ask for page 1), whose last item comes back at the head of
    // page 1 -- exactly what offset pagination returns when someone
    // posts while the viewer is scrolling. hasImage: false for the same
    // reason scrollToTopTestHomeRepository uses it.
    overlappingPageHomeRepository = _OverlappingPageHomeRepository(
      page0: [
        for (var i = 0; i < 10; i++)
          _dropItem(id: 'dup-\$i', caption: 'โพสต์ที่ \$i', hasImage: false),
      ],
      page1: [
        _dropItem(id: 'dup-9', caption: 'โพสต์ที่ 9', hasImage: false),
        _dropItem(id: 'dup-10', caption: 'โพสต์ที่ 10', hasImage: false),
      ],
    );

    pendingLikeDropRepository = _PendingLikeDropRepository();
    pendingLikeHomeRepository = RecordingHomeRepository(
      rankedFeedItems: [_dropItem(id: 'pending-like-1', hasImage: false)],
    );

    backFromDetailHomeRepository = RecordingHomeRepository(
      rankedFeedItems: [
        for (var i = 0; i < 30; i++)
          _dropItem(id: 'back-\$i', caption: 'โพสต์ที่ \$i', hasImage: false),
      ],
    );
    // What Detail's changes look like when the row is re-read: the post
    // the test opens comes back with one more like.
    backFromDetailHomeRepository.itemsById['back-5:'] =
        _dropItem(id: 'back-5', caption: 'โพสต์ที่ 5', hasImage: false, likeCount: 1);

    failingSecondPageHomeRepository = _FailingSecondPageHomeRepository(
      page0: [
        for (var i = 0; i < 10; i++)
          _dropItem(id: 'fail-\$i', caption: 'หน้าแรกที่ \$i', hasImage: false),
      ],
    );
    slowInitialHomeRepository =
        _DelayedHomeRepository(items: [_dropItem(id: 'slow-1', hasImage: false)]);
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

  // WYN-100: hamburger icon on Home opens the real SideMenu drawer (it
  // used to be a bare SizedBox(width: 48) spacer -- Home had no way to
  // open the drawer at all before this).
  testWidgets('the hamburger icon opens the SideMenu drawer', (tester) async {
    await tester.pumpWidget(buildHome(
      mixedFeedHomeRepository,
      dropRepository: sharedDropRepository,
      popRepository: sharedPopRepository,
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('สร้าง Club'), findsOneWidget);
    expect(find.text('Club ของฉัน'), findsOneWidget);
  });

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
    // WYN-088: the Home feed no longer shows the view-count icon at all
    // (Founder: "หน้า Home เอาดวงตาที่นับยอดคนดูออกจากหน้า Home feed") --
    // used to assert findsOneWidget here (WYN-038 QA fix); still kept
    // (only on Profile now) is covered separately, see WYN-088's own
    // dedicated test group below.
    expect(
      find.descendant(
        of: find.byType(HomeDropCard),
        matching: find.byIcon(Icons.visibility_outlined),
      ),
      findsNothing,
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
    // WYN-088: same removal as the Drop card's own check above -- the
    // Pop card's view-count icon (previously asserted findsOneWidget
    // here per the WYN-038 QA fix note this replaces) is gone from the
    // Home feed too now.
    final popCardViewCount = find.descendant(
      of: find.byType(HomePopCard),
      matching: find.byIcon(Icons.visibility_outlined),
    );
    expect(popCardViewCount, findsNothing);
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
        'Beta4 §6: tapping the ReDrop icon opens an ActionSheetBody '
        'offering "รีโพสต์" and "อ้างอิง", with real icons and no emoji',
        (tester) async {
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

      // Beta4 §6: the WYNOS action-sheet family, not a bare Wrap of
      // ListTiles -- so these two rows get the same 18px icon, the same
      // divider, the same chevron and the same press state as every
      // other "..." menu in the app.
      expect(find.byType(ActionSheetBody), findsOneWidget);
      expect(find.byType(ActionSheetRow), findsNWidgets(2));

      expect(find.text('รีโพสต์'), findsOneWidget);
      expect(find.text('อ้างอิง'), findsOneWidget);
      expect(find.text('ยกเลิกรีโพสต์'), findsNothing);

      // The emoji that used to stand in for icons are gone entirely --
      // an emoji cannot take a colour, a size, or a pressed state from
      // the icon system.
      expect(find.textContaining('🔄'), findsNothing);
      expect(find.textContaining('💬'), findsNothing);

      // Real icons in their place, inside the sheet.
      expect(
        find.descendant(
          of: find.byType(ActionSheetBody),
          matching: find.byIcon(Icons.repeat),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ActionSheetBody),
          matching: find.byIcon(Icons.format_quote),
        ),
        findsOneWidget,
      );
    });

    // WYN-097, Design spec Screen 6.
    testWidgets(
        'the ReDrop button is hidden entirely (not disabled) on a card '
        'whose audience is not "ทุกคน"', (tester) async {
      await tester.pumpWidget(buildHome(
        hiddenRedropButtonTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      // Broken test-fixture image URL -- same expected noise as every
      // other Drop-card test in this file.
      tester.takeException();

      expect(find.widgetWithIcon(ActionMetric, Icons.repeat), findsNothing);
      // The Like/Comment buttons are still there -- only ReDrop is
      // conditionally hidden.
      expect(find.widgetWithIcon(ActionMetric, Icons.favorite_border),
          findsOneWidget);
    });

    // WYN-098, Design spec Screen 4.
    testWidgets(
        'shows "· 📍 {location}" appended to the relative-time line when '
        'a Drop has a check-in', (tester) async {
      await tester.pumpWidget(buildHome(
        locationTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.textContaining('📍 สยามพารากอน'), findsOneWidget);
    });

    testWidgets(
        'tapping "รีโพสต์" in the sheet calls toggleRedrop with '
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
      await tester.tap(find.text('รีโพสต์'));
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

      expect(find.text('ยกเลิกรีโพสต์'), findsOneWidget);
      expect(find.text('รีโพสต์'), findsNothing);
      // Beta4 §6: the ReDrop row keeps its icon in the undo state too.
      // The old emoji version showed '🔄' on one label and nothing on
      // the other, so the row visibly changed shape with your own
      // ReDrop state.
      expect(
        find.descendant(
          of: find.byType(ActionSheetBody),
          matching: find.byIcon(Icons.repeat),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('ยกเลิกรีโพสต์'));
      await tester.pumpAndSettle();

      expect(cancelRedropTestDropRepository.toggleRedropCalls, 1);
      expect(
        cancelRedropTestDropRepository.toggleRedropCurrentlyRedroppedArgs,
        [true],
      );
    });

    testWidgets(
        'WYN-089: the repost icon is WynColors.sapphire when the current '
        'user already reposted, matching DropDetailScreen\'s Focused Action '
        'Bar', (tester) async {
      await tester.pumpWidget(buildHome(
        alreadyRedroppedTestHomeRepository,
        dropRepository: cancelRedropTestDropRepository,
        popRepository: cancelRedropTestPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final redroppedIcon = tester.widget<Icon>(
        find.descendant(
          of: find.widgetWithIcon(ActionMetric, Icons.repeat),
          matching: find.byIcon(Icons.repeat),
        ),
      );
      expect(redroppedIcon.color, WynColors.sapphire);
    });

    testWidgets(
        'WYN-089: the repost icon stays WynColors.graphite when the current '
        'user has not reposted -- the color is a 2-state indicator, not '
        'always-on', (tester) async {
      await tester.pumpWidget(buildHome(
        toggleRedropTestHomeRepository,
        dropRepository: toggleRedropTestDropRepository,
        popRepository: toggleRedropTestPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final notRedroppedIcon = tester.widget<Icon>(
        find.descendant(
          of: find.widgetWithIcon(ActionMetric, Icons.repeat),
          matching: find.byIcon(Icons.repeat),
        ),
      );
      expect(notRedroppedIcon.color, WynColors.graphite);
    });

    testWidgets('tapping "อ้างอิง" opens QuoteRedropScreen',
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
      await tester.tap(find.text('อ้างอิง'));
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
      expect(find.text('ลบรีโพสต์'), findsOneWidget);

      await tester.tap(find.text('ลบรีโพสต์'));
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

    testWidgets(
        'WYN-079: hiding a card offers a Snackbar "เลิกทำ" (Undo) action, '
        'and tapping it restores the card and calls unhideContent',
        (tester) async {
      await tester.pumpWidget(buildHome(
        hideDropTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final moreButton = find.widgetWithIcon(IconButton, Icons.more_vert);
      tester.widget<IconButton>(moreButton).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('ไม่สนใจโพสต์นี้'));
      await tester.pump();

      expect(find.text('แคปชัน Drop'), findsNothing);
      expect(find.text('เลิกทำ'), findsOneWidget);

      // Same off-screen-hit-test-avoidance as elsewhere in this file (see
      // the Poll option test above) -- the Snackbar sits at the bottom
      // of the 800x600 test viewport, below where tester.tap() can
      // reliably hit-test, so this invokes SnackBarAction.onPressed
      // directly instead.
      final undoAction =
          find.widgetWithText(SnackBarAction, 'เลิกทำ');
      tester.widget<SnackBarAction>(undoAction).onPressed();
      await tester.pumpAndSettle();

      expect(find.text('แคปชัน Drop'), findsOneWidget);
      expect(
        hideDropTestHomeRepository.unhideContentArgs,
        [(HomeContentType.drop, 'hide-d1')],
      );
    });

    testWidgets(
        'WYN-079: letting the Undo Snackbar time out without tapping it '
        'leaves the card hidden and never calls unhideContent',
        (tester) async {
      await tester.pumpWidget(buildHome(
        hideDropUndoTimeoutTestHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final moreButton = find.widgetWithIcon(IconButton, Icons.more_vert);
      tester.widget<IconButton>(moreButton).onPressed!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('ไม่สนใจโพสต์นี้'));
      await tester.pump();

      // Not tapping "เลิกทำ" -- the card stays hidden and
      // unhideContent is never called, whether or not/whenever the
      // Snackbar itself eventually auto-dismisses (a stock Flutter
      // SnackBar behavior this task doesn't change, so not re-verified
      // here).
      expect(find.text('แคปชัน Drop'), findsNothing);
      expect(hideDropUndoTimeoutTestHomeRepository.unhideContentArgs, isEmpty);
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

    testWidgets(
        'only 3 segments ("สำหรับคุณ"/"ติดตาม"/"จาก Club ของคุณ") are present '
        '-- "ล่าสุด" was removed (WYN-090)', (tester) async {
      await tester.pumpWidget(buildHome(
        mixedFeedHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('สำหรับคุณ'), findsOneWidget);
      expect(find.text('ติดตาม'), findsOneWidget);
      expect(find.text('ล่าสุด'), findsNothing);
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

      await tester.tap(find.text('ติดตาม'));
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

      await tester.tap(find.text('ติดตาม'));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets(
        'the short segment label ("ติดตาม") is fully legible, not '
        'ellipsis-truncated, once active at a typical phone width (QA round 3 '
        'regression, 2026-08-22)', (tester) async {
      // 390px (iPhone 14/15) rather than round 2's 360px floor -- QA round 3
      // measured that even after reclaiming width from the removed
      // checkmark icon and tightened padding, the short 6-character label
      // only became fully non-truncated from ~390px up under THAT fix.
      // The two longer labels ("สำหรับคุณ" 9 chars, "จาก Club ของคุณ" 15
      // chars) still weren't covered by that round's fix -- but the
      // scrollable-width fix below (WYN-024 follow-up, 2026-08-22)
      // supersedes this entirely: see the comprehensive all-segments
      // test further down, which covers every label, at every real
      // width, with no residual gap. ("ล่าสุด" itself was removed in
      // WYN-090.)
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

      for (final label in ['ติดตาม']) {
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

  group('WYN-086: caption above image (Wynos V1.0.0 Beta2, item 25)', () {
    testWidgets(
        'a Drop card with both a caption and an image shows the caption '
        'above the image, not below it', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(caption: 'ข้อความโพสต์', hasImage: true),
            dropRepository: sharedDropRepository,
            onTap: () {},
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final captionTop = tester.getTopLeft(find.text('ข้อความโพสต์')).dy;
      final imageTop = tester.getTopLeft(find.byType(Image)).dy;
      expect(captionTop, lessThan(imageTop));
    });
  });

  group('WYN-087: relative time on the repost header (Wynos V1.0.0 Beta2, '
      'item 26)', () {
    testWidgets(
        'the "รีโพสต์โดย @username" header shows a relative time, using '
        'the ReDrop\'s own createdAt (not the original Drop\'s)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            dropRepository: sharedDropRepository,
            item: HomeFeedItem(
              id: 'd1',
              contentType: HomeContentType.drop,
              authorId: 'someone-else',
              authorUsername: 'namfah',
              // home_feed's ReDrop UNION branch selects r.created_at
              // (the ReDrop row's own timestamp) into this same
              // created_at column -- see schema.sql. So item.createdAt
              // here already *is* "the time the redropper pressed
              // ReDrop", not the original Drop's post time.
              createdAt: DateTime.now().subtract(const Duration(minutes: 8)),
              caption: 'แคปชัน Drop',
              likeCount: 0,
              commentCount: 0,
              likedByMe: false,
              savedByMe: false,
              redropId: 'r1',
              redropperId: 'someone-else-2',
              redropperUsername: 'sky_blue',
            ),
            onTap: () {},
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(
        find.textContaining('รีโพสต์โดย @sky_blue · 8 นาทีที่แล้ว'),
        findsOneWidget,
      );
    });
  });

  group('WYN-088: view-count icon (Wynos V1.0.0 Beta2, item 27)', () {
    // The Home feed's own removal is covered by "renders a mix of Drop
    // and Pop cards with type-specific UI" above (findsNothing there
    // now) -- this group instead proves the *default* (every other
    // HomeDropCard call site: Profile's 3 tabs, hashtag feed) still
    // shows it, since Founder explicitly wants it kept on Profile.
    testWidgets(
        'HomeDropCard shows the view-count icon by default (i.e. '
        'everywhere except the Home feed, which passes showViewCount: '
        'false explicitly)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(viewCount: 12),
            dropRepository: sharedDropRepository,
            onTap: () {},
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group(
      'WYN-093: dynamic-height/aspect-fit images (Wynos V1.0.0 Beta2, '
      'item 19)', () {
    Future<void> pumpCard(WidgetTester tester, HomeFeedItem item) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: HomeDropCard(
              item: item,
              dropRepository: sharedDropRepository,
              onTap: () {},
              onToggleLike: () {},
              onToggleSave: () {},
              onOpenProfile: () {},
              onToggleRedrop: () {},
              onQuoteRedrop: () {},
            ),
          ),
        ));

    testWidgets(
        'a portrait image within the 4:5 (0.8) .. 1.91:1 clamp range '
        'renders at its true aspect ratio, not cropped to 1:1',
        (tester) async {
      // 800x1000 -> 0.8 exactly, the most-portrait shape allowed.
      await pumpCard(tester, _dropItem(imageWidth: 800, imageHeight: 1000));
      await tester.pumpAndSettle();
      tester.takeException();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(aspectRatio.aspectRatio, 0.8);
    });

    testWidgets(
        'a landscape image within the clamp range renders at its true '
        'aspect ratio', (tester) async {
      // 1910x1000 -> 1.91 exactly, the most-landscape shape allowed.
      await pumpCard(tester, _dropItem(imageWidth: 1910, imageHeight: 1000));
      await tester.pumpAndSettle();
      tester.takeException();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(aspectRatio.aspectRatio, closeTo(1.91, 0.0001));
    });

    testWidgets('a square image renders at 1:1 (same as the old fixed '
        'behavior, just arrived at via its real dimensions now)',
        (tester) async {
      await pumpCard(tester, _dropItem(imageWidth: 500, imageHeight: 500));
      await tester.pumpAndSettle();
      tester.takeException();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(aspectRatio.aspectRatio, 1);
    });

    testWidgets(
        'an extremely tall image (e.g. a chat screenshot) is clamped to '
        '0.8, not rendered at its uncropped extreme ratio', (tester) async {
      // 300x1600 -> ~0.1875 true ratio, way past the 0.8 floor.
      await pumpCard(tester, _dropItem(imageWidth: 300, imageHeight: 1600));
      await tester.pumpAndSettle();
      tester.takeException();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(aspectRatio.aspectRatio, 0.8);
    });

    testWidgets(
        'an extremely wide image (e.g. a panorama) is clamped to 1.91, '
        'not rendered at its uncropped extreme ratio', (tester) async {
      // 2000x500 -> 4.0 true ratio, way past the 1.91 ceiling.
      await pumpCard(tester, _dropItem(imageWidth: 2000, imageHeight: 500));
      await tester.pumpAndSettle();
      tester.takeException();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(aspectRatio.aspectRatio, closeTo(1.91, 0.0001));
    });

    testWidgets(
        'a Drop with no image_width/image_height metadata (uploaded '
        'before this migration) falls back to the old fixed 1:1 square',
        (tester) async {
      await pumpCard(
        tester,
        _dropItem(imageWidth: null, imageHeight: null),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio).first);
      expect(aspectRatio.aspectRatio, 1);
    });

    testWidgets(
        'the media area is capped at 0.75x the screen height regardless '
        'of aspect ratio, so one image can never fill nearly the whole '
        'viewport on a very tall screen', (tester) async {
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpCard(tester, _dropItem(imageWidth: 800, imageHeight: 1000));
      await tester.pumpAndSettle();
      tester.takeException();

      final constrainedBox = tester.widget<ConstrainedBox>(
        find.ancestor(
          of: find.byType(AspectRatio).first,
          matching: find.byType(ConstrainedBox),
        ),
      );
      expect(constrainedBox.constraints.maxHeight, 0.75 * 2000);
    });
  });

  group(
      'WYN-092: multi-image peek carousel (Wynos V1.0.0 Beta2 Phase 2, '
      'item 14)', () {
    // Constructed in setUp, not inline inside a testWidgets body -- see
    // drop_image_gallery_test.dart's identical rationale (a fresh
    // RecordingDropRepository's underlying SupabaseClient starts a
    // GoTrue auto-refresh Timer that would otherwise get attributed to
    // that one test's FakeAsync zone and trip flutter_test's own
    // `!timersPending` invariant at teardown).
    late RecordingDropRepository multiImageRepo;
    late RecordingDropRepository failedFetchRepo;

    setUp(() {
      multiImageRepo = RecordingDropRepository()
        ..dropImagesById = {
          'd1': [
            'https://example.supabase.co/drops/d1.jpg',
            'https://example.supabase.co/drops/d1_1.jpg',
            'https://example.supabase.co/drops/d1_2.jpg',
          ],
        };
      failedFetchRepo = RecordingDropRepository()
        ..fetchDropImagesError = Exception('network');
    });

    testWidgets(
        'a single-image Drop (imageCount 1 or null) never builds the '
        'carousel -- renders exactly as it always has', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(imageCount: 1),
            dropRepository: sharedDropRepository,
            onTap: () {},
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(HomeFeedImagePeekCarousel), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets(
        'a multi-image Drop (imageCount > 1) shows the first image '
        'immediately, before the full list has been fetched',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(imageCount: 3),
            dropRepository: multiImageRepo,
            onTap: () {},
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      // Deliberately no pumpAndSettle here -- checking the state before
      // fetchDropImages resolves.
      tester.takeException();

      expect(find.byType(HomeFeedImagePeekCarousel), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    // WYN-107. The Founder circled this card's action row and wrote
    // "ปุ่มควรขยับ ให้ตรงชื่อ" -- the whole task is that one alignment, so
    // it gets an assertion rather than living only in a screenshot. The
    // card is two columns now: the avatar is the left one, and every
    // other thing the post says starts at the same left edge in the
    // right one.
    testWidgets(
        'every section of a card starts on the same left edge as the '
        "author's name (WYN-107 two-column layout)", (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(imageCount: 3),
            dropRepository: multiImageRepo,
            onTap: () {},
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final cardLeft = tester.getTopLeft(find.byType(HomeDropCard)).dx;
      final nameLeft = tester.getTopLeft(find.text('@namfah')).dx;

      // The name sits exactly one avatar column in from the card's edge.
      expect(nameLeft - cardLeft, closeTo(homeCardContentInset, 0.5));

      // ...and so does everything below it: the caption, the photo row,
      // and the action row the Founder pointed at. Before this task each
      // of these was 12px from the screen edge instead, a different
      // vertical line from the name they belong to.
      final sections = <String, Finder>{
        'caption': find.byType(HashtagText),
        'photo row': find.byType(HomeFeedImagePeekCarousel),
        'action bar': find.byType(ActionMetric).first,
      };
      for (final entry in sections.entries) {
        expect(
          tester.getTopLeft(entry.value).dx - cardLeft,
          closeTo(homeCardContentInset, 0.5),
          reason: 'the ${entry.key} is off the content column',
        );
      }
    });

    testWidgets(
        'once fetched, a multi-image Drop shows every image at 82% of '
        'the row width with a 4:5 aspect ratio', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(imageCount: 3),
            dropRepository: multiImageRepo,
            onTap: () {},
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // The ListView itself always has all 3 items in its delegate --
      // whether every one of them is actually *built* yet depends on
      // how much of the first item's neighbors fit within the viewport
      // + cacheExtent, same lazy-building behavior any ListView.builder
      // has. This checks the data model directly rather than assuming a
      // particular number of built Image widgets.
      final listView = tester.widget<ListView>(find.byType(ListView));
      final delegate =
          listView.childrenDelegate as SliverChildBuilderDelegate;
      expect(delegate.childCount, 3);

      // WYN-107: 82% of the *content column* the post is written in, not
      // of the whole card. The column starts after the avatar column
      // (homeCardContentInset) and the card holds its own right inset
      // off the screen (homeCardEdgeInset) -- the photo row is laid out
      // past that inset so the next card can peek towards the screen
      // edge, but a card is still sized off the column, which is what
      // keeps a photo lined up with the caption above it.
      final cardWidth = tester.getSize(find.byType(HomeDropCard)).width;
      final columnWidth =
          cardWidth - homeCardContentInset - homeCardEdgeInset;
      final firstImageSize = tester.getSize(find.byType(Image).first);
      expect(firstImageSize.width, closeTo(columnWidth * 0.82, 0.5));
      expect(
        firstImageSize.height,
        closeTo(firstImageSize.width * 5 / 4, 0.5),
      );

      // The "multiple photos" badge only appears once, on the first
      // card -- not repeated on every image.
      expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
    });

    testWidgets(
        'a failed fetchDropImages falls back to showing just the first '
        'image, silently (no error UI)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(imageCount: 4),
            dropRepository: failedFetchRepo,
            onTap: () {},
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
    });

    testWidgets('double-tapping any image in the carousel likes the Drop',
        (tester) async {
      var likeCalls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(imageCount: 3),
            dropRepository: multiImageRepo,
            onTap: () {},
            onToggleLike: () => likeCalls++,
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final center = tester.getCenter(find.byType(HomeFeedImagePeekCarousel));
      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);
      await tester.pump();
      tester.takeException();

      expect(likeCalls, 1);

      // Let DoubleTapLike's heart-animation AnimationController finish
      // ticking before the test ends -- otherwise it trips
      // flutter_test's "no pending timers at teardown" invariant, same
      // as double_tap_like_test.dart's identical pattern.
      await tester.pumpAndSettle();
    });

    testWidgets(
        'a single tap (no second tap) on the carousel opens Detail via '
        "the card's own outer InkWell -- same as the single-image case",
        (tester) async {
      var tapCalls = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HomeDropCard(
            item: _dropItem(imageCount: 3),
            dropRepository: multiImageRepo,
            onTap: () => tapCalls++,
            onToggleLike: () {},
            onToggleSave: () {},
            onOpenProfile: () {},
            onToggleRedrop: () {},
            onQuoteRedrop: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.byType(HomeFeedImagePeekCarousel));
      // A lone tap on a GestureDetector that also has onDoubleTap is
      // deliberately held for kDoubleTapTimeout to see if a second tap
      // follows (see DoubleTapLike.onTap's doc comment) -- pumpAndSettle
      // alone doesn't advance that bare Timer since no frame is
      // scheduled while waiting on it.
      await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(tapCalls, 1);
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
      expect(find.text('ลบรีโพสต์'), findsNothing);
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
      // WYN-091: the visible text is a constant "มีโพสต์ใหม่" now (no
      // count) -- the "right count" this test's own description refers
      // to is still tracked internally (drives the Semantics label,
      // see new_posts_pill_test.dart), just not shown on screen.
      expect(find.text('มีโพสต์ใหม่'), findsOneWidget);
      expect(
        tester.widget<NewPostsPill>(find.byType(NewPostsPill)).count,
        1,
      );
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

      // WYN-091: no count in the visible text anymore -- assert the
      // internal count directly instead (the pill's own text stays the
      // constant "มีโพสต์ใหม่" the whole time).
      expect(
        tester.widget<NewPostsPill>(find.byType(NewPostsPill)).count,
        2,
      );
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

  group('feed integrity under real pagination/tap behaviour (Beta2 audit)',
      () {
    testWidgets(
        'a row that offset pagination hands back on both pages is shown '
        'once, not twice', (tester) async {
      await tester.pumpWidget(buildHome(
        overlappingPageHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // Scroll far enough past the bottom to trip the load-more
      // threshold, then let page 1 arrive.
      await tester.drag(
        find.byKey(const Key('home_feed_scroll_view')),
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(overlappingPageHomeRepository.fetchRankedFeedCalls, 2,
          reason: 'page 1 should have been requested');
      // Scrolled to the bottom, the tail of the list is what's on
      // screen: the row both pages returned, and the genuinely new one
      // behind it. Before the dedupe, "โพสต์ที่ 9" was appended a second
      // time and rendered twice in a row (with a duplicate ValueKey).
      expect(find.text('โพสต์ที่ 10'), findsOneWidget);
      expect(find.text('โพสต์ที่ 9'), findsOneWidget);
    });

    testWidgets(
        'a second Like tap while the first write is still in flight is '
        'queued behind it, not sent concurrently', (tester) async {
      await tester.pumpWidget(buildHome(
        pendingLikeHomeRepository,
        dropRepository: pendingLikeDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final like = find.byWidgetPredicate(
        (w) => w is ActionMetric && w.semanticsLabel.contains('ถูกใจ'),
      );
      expect(like, findsOneWidget);

      final onTap = tester.widget<ActionMetric>(like).onTap!;
      onTap();
      onTap();
      await tester.pump();

      // Both taps are real user intent and both must reach the server --
      // but the second one waits for the first, so an INSERT and its
      // DELETE can never be in flight together and race each other.
      expect(pendingLikeDropRepository.toggleLikeCalls, 1,
          reason: 'the second write is queued, not issued yet');
      expect(pendingLikeDropRepository.maxConcurrentWrites, 1);

      pendingLikeDropRepository.release();
      await tester.pumpAndSettle();

      expect(pendingLikeDropRepository.toggleLikeCalls, 2);
      expect(pendingLikeDropRepository.toggleLikeCurrentlyLikedArgs,
          [false, true],
          reason: 'each write still carries the state at its own tap');
      expect(pendingLikeDropRepository.maxConcurrentWrites, 1,
          reason: 'the two writes never overlapped');
    });

    testWidgets(
        'coming back from Detail refreshes only that card, keeping the '
        "viewer's scroll position instead of rebuilding the feed",
        (tester) async {
      await tester.pumpWidget(buildHome(
        backFromDetailHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      final scrollView = find.byKey(const Key('home_feed_scroll_view'));
      await tester.drag(scrollView, const Offset(0, -600));
      await tester.pumpAndSettle();

      // Resolved upward from a card rather than by finding Scrollables
      // under the CustomScrollView -- the pinned tab bar contributes one
      // of its own, and this way there is no ambiguity about which
      // scroll view is meant.
      ScrollPosition position() =>
          Scrollable.of(tester.element(find.byType(HomeDropCard).first))
              .position;
      final pixelsBefore = position().pixels;
      expect(pixelsBefore, greaterThan(0),
          reason: 'the test needs to actually be scrolled down');

      // Whichever card the scroll happened to land on -- the point is
      // that the viewer opens something that is not the first row.
      final card = tester.widget<HomeDropCard>(find.byType(HomeDropCard).first);
      backFromDetailHomeRepository.itemsById['${card.item.id}:'] =
          card.item.copyWith(likeCount: card.item.likeCount + 1);
      final fetchesBefore = backFromDetailHomeRepository.fetchRankedFeedCalls;

      // Invoked directly rather than via tester.tap(): the card's own
      // onTap is what a real tap on the body resolves to, and calling it
      // avoids depending on which part of a partially-scrolled card
      // happens to be hit-testable -- the same approach the Comment-icon
      // test above uses, for the same reason.
      card.onTap();
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.byType(DropDetailScreen), findsOneWidget);

      // Popped through the Navigator rather than tester.pageBack(),
      // which looks for a Cupertino back button this Material app never
      // renders.
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      tester.takeException();

      expect(backFromDetailHomeRepository.fetchItemByIdCalls, 1,
          reason: 'just the one card is re-read');
      expect(backFromDetailHomeRepository.fetchRankedFeedCalls, fetchesBefore,
          reason: 'the feed is not reloaded from page 0');
      expect(position().pixels, pixelsBefore,
          reason: 'the viewer stays exactly where they were');
    });

    testWidgets(
        'a failed load-more offers a retry instead of stopping silently',
        (tester) async {
      await tester.pumpWidget(buildHome(
        failingSecondPageHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.drag(
        find.byKey(const Key('home_feed_scroll_view')),
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();
      tester.takeException();

      final retry = find.byKey(const Key('home_feed_load_more_retry'));
      expect(retry, findsOneWidget,
          reason: 'the user can see the page failed, and ask again');
      final callsAfterFailure =
          failingSecondPageHomeRepository.fetchRankedFeedCalls;

      // Scrolling again does not silently re-fire the request that just
      // failed -- the retry button is the way back.
      await tester.drag(
        find.byKey(const Key('home_feed_scroll_view')),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();
      expect(failingSecondPageHomeRepository.fetchRankedFeedCalls,
          callsAfterFailure);

      failingSecondPageHomeRepository.failNextPage = false;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      tester.takeException();

      expect(failingSecondPageHomeRepository.fetchRankedFeedCalls,
          callsAfterFailure + 1);
      expect(find.byKey(const Key('home_feed_load_more_retry')), findsNothing);
    });

    testWidgets('the initial load shows card-shaped placeholders, not a bare '
        'spinner', (tester) async {
      await tester.pumpWidget(buildHome(
        slowInitialHomeRepository,
        dropRepository: sharedDropRepository,
        popRepository: sharedPopRepository,
      ));
      // A plain pump, not pumpAndSettle: this repository's fetch never
      // resolves, so the feed stays in its loading state for the test.
      await tester.pump();

      expect(find.byType(HomeFeedSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
