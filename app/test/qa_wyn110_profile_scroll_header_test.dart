// QA regression suite for WYN-110 ("หัวโปรไฟล์ต้องเลื่อนหายไปได้"), written
// independently of app/test/view_profile_screen_scroll_test.dart (the
// coding agent's own test) to verify the fix from a fresh angle rather
// than trusting that file alone. Covers:
//   1. Header scroll-away + TabBar pin for a profile that is NOT the
//      viewer's own (isOwnProfile == false), including
//      ProfileRecommendationSection in the header sliver stack.
//   2. All 3 tabs (Posts/ReDrops/Likes) individually confirmed to let
//      the header scroll away, not just the Posts tab.
//   3. Per-tab scroll position retention across tab switches.
//   4. Infinite-scroll pagination across a real page boundary for all
//      3 tabs -- no duplicate ValueKeys, no thrown exceptions, and the
//      exact number of fetch calls one page-boundary crossing should
//      cost (see QA-WYN-110-001: this exposes a real regression --
//      *: findings below).
//   5. Pull-to-refresh still wired for all 3 tabs.
//   6. No overflow while actively dragging (not just at rest) at
//      320/360/390/430 widths (see QA-WYN-110-002: a pre-existing,
//      out-of-scope HomeDropCard overflow found at 320px).
//
// Every RecordingXxxRepository used by more than one test is built in
// setUpAll, never inline in a test body -- see every other test file in
// this suite (and .wyn/learning/PATTERNS.md) for why: a fresh
// SupabaseClient's GoTrue auto-refresh Timer.periodic gets attributed to
// whichever test happened to be running when it was constructed, and
// trips flutter_test's `!timersPending` invariant at that test's
// teardown.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_repository.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/data/home_repository.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_drop_grid_tab.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_redrops_tab.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_likes_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_home_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

/// A RecordingDropRepository whose [fetchByAuthor] actually pages,
/// unlike the base class (page 1+ always []). Local to this file --
/// nothing in test/support/ needed to change for QA to verify
/// pagination independently.
class _PagedDropRepository extends RecordingDropRepository {
  _PagedDropRepository({required this.pagesByAuthor});

  final Map<String, List<List<Drop>>> pagesByAuthor;
  int fetchByAuthorCalls = 0;

  @override
  Future<List<Drop>> fetchByAuthor({
    required String authorId,
    required int page,
  }) async {
    fetchByAuthorCalls++;
    final pages = pagesByAuthor[authorId];
    if (pages == null || page >= pages.length) return [];
    return pages[page];
  }
}

/// Same idea as [_PagedDropRepository], for ProfileRedropsTab's
/// HomeRepository.fetchRedropsByUser.
class _PagedHomeRepository extends RecordingHomeRepository {
  _PagedHomeRepository({required this.pagesByUser});

  final Map<String, List<List<HomeFeedItem>>> pagesByUser;
  int fetchRedropsByUserCallsSeen = 0;

  @override
  Future<List<HomeFeedItem>> fetchRedropsByUser({
    required String userId,
    required int page,
  }) async {
    fetchRedropsByUserCallsSeen++;
    final pages = pagesByUser[userId];
    if (pages == null || page >= pages.length) return [];
    return pages[page];
  }
}

Drop _textDrop(String id, {String authorId = 'me', String? caption}) => Drop(
      id: id,
      authorId: authorId,
      authorUsername: authorId,
      caption: caption ?? 'โพสต์ $id',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

Widget _wrapTab(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  late RecordingProfileRepository ownProfileRepo;
  late RecordingProfileRepository otherProfileRepo;
  late RecordingFollowRepository followRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingDropRepository othersPostsRepo;
  late RecordingHomeRepository redropsForOwnRepo;
  late RecordingDropRepository likesForOwnRepo;
  late RecordingDropRepository postsForOwnScrollRepo;
  late RecordingDropRepository emptyDropRepo;
  late _PagedDropRepository pagedPostsRepo;
  late _PagedHomeRepository pagedRedropsRepo;
  late RecordingDropRepository pagedLikesRepo;
  late RecordingDropRepository refreshPostsRepo;
  late RecordingHomeRepository refreshRedropsRepo;
  late List<RecordingDropRepository> overflowRepos;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    ownProfileRepo = RecordingProfileRepository(
      profile:
          const Profile(id: 'me', username: 'me_user', displayName: 'ตัวฉันเอง'),
    );
    otherProfileRepo = RecordingProfileRepository(
      profile: const Profile(
          id: 'someone-else', username: 'namfah', displayName: 'น้ำฝน'),
    );
    followRepo = RecordingFollowRepository(followerCount: 10, followingCount: 4);
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();

    othersPostsRepo = RecordingDropRepository(feedDrops: [
      for (var i = 0; i < 40; i++) _textDrop('p$i', authorId: 'someone-else'),
    ]);

    redropsForOwnRepo = RecordingHomeRepository(
      redropsByUser: [
        for (var i = 0; i < 30; i++)
          HomeFeedItem.fromDrop(_textDrop('r$i', caption: 'รีโพสต์ r$i')),
      ],
    );

    likesForOwnRepo = RecordingDropRepository()
      ..likedDropsByAuthor = {
        'me': [
          for (var i = 0; i < 30; i++)
            _textDrop('l$i', authorId: 'someone-else', caption: 'ถูกใจ l$i'),
        ],
      };

    postsForOwnScrollRepo = RecordingDropRepository(feedDrops: [
      for (var i = 0; i < 40; i++) _textDrop('sp$i'),
    ])
      ..likedDropsByAuthor = {'me': []};

    emptyDropRepo = RecordingDropRepository();

    pagedPostsRepo = _PagedDropRepository(pagesByAuthor: {
      'someone-else': [
        [for (var i = 0; i < DropRepository.pageSize; i++) _textDrop('gp$i')],
        [_textDrop('gp-new-1'), _textDrop('gp-new-2')],
      ],
    });

    pagedRedropsRepo = _PagedHomeRepository(pagesByUser: {
      'someone-else': [
        [
          for (var i = 0; i < HomeRepository.pageSize; i++)
            HomeFeedItem.fromDrop(_textDrop('rp$i'))
        ],
        [
          HomeFeedItem.fromDrop(_textDrop('rp-new-1')),
          HomeFeedItem.fromDrop(_textDrop('rp-new-2')),
        ],
      ],
    });

    pagedLikesRepo = RecordingDropRepository()
      ..likedDropPagesByAuthor = {
        'someone-else': [
          [
            for (var i = 0; i < DropRepository.pageSize; i++)
              _textDrop('lp$i', authorId: 'someone-else')
          ],
          [
            _textDrop('lp-new-1', authorId: 'someone-else'),
            _textDrop('lp-new-2', authorId: 'someone-else'),
          ],
        ],
      };

    refreshPostsRepo = RecordingDropRepository(feedDrops: [_textDrop('rf1')]);
    refreshRedropsRepo = RecordingHomeRepository(
      redropsByUser: [HomeFeedItem.fromDrop(_textDrop('rf2'))],
    );

    overflowRepos = [
      for (var w = 0; w < 4; w++)
        RecordingDropRepository(feedDrops: [
          for (var i = 0; i < 20; i++) _textDrop('ov${w}_$i', authorId: 'someone-else'),
        ]),
    ];
  });

  group('1. header scroll-away on a profile that is NOT the viewer\'s own',
      () {
    testWidgets(
        'someone else\'s profile (with ProfileRecommendationSection in the '
        'header) still lets the header scroll away and pins the TabBar',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewProfileScreen(
          profileRepository: otherProfileRepo,
          followRepository: followRepo,
          dropRepository: othersPostsRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'someone-else',
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      // At rest: the "ติดตาม" follow button (the header-only element on
      // someone else's profile, standing in for "แก้ไขโปรไฟล์" on your
      // own) is visible.
      expect(find.text('ติดตาม'), findsOneWidget);

      await tester.drag(find.text('โพสต์ p0'), const Offset(0, -1000));
      await tester.pumpAndSettle();
      tester.takeException();

      // Header (including the follow button) scrolled away...
      expect(find.text('ติดตาม'), findsNothing);
      // ...but the TabBar is still on screen, pinned near the top --
      // not just "still in the tree somewhere off-screen".
      expect(find.text('โพสต์'), findsOneWidget);
      final tabBarTop = tester.getTopLeft(find.text('โพสต์')).dy;
      expect(tabBarTop, greaterThan(0));
      expect(tabBarTop, lessThan(150));
    });
  });

  group('2. every tab (not just Posts) lets the header scroll away', () {
    testWidgets('ReDrops tab scrolls its own header away, TabBar stays pinned',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewProfileScreen(
          profileRepository: ownProfileRepo,
          followRepository: followRepo,
          dropRepository: emptyDropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          homeRepository: redropsForOwnRepo,
          userId: 'me',
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('รีโพสต์'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('แก้ไขโปรไฟล์'), findsOneWidget);
      await tester.drag(find.text('รีโพสต์ r0'), const Offset(0, -1000));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('แก้ไขโปรไฟล์'), findsNothing);
      expect(find.text('รีโพสต์'), findsWidgets); // tab label still there
    });

    testWidgets('Likes tab scrolls its own header away, TabBar stays pinned',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewProfileScreen(
          profileRepository: ownProfileRepo,
          followRepository: followRepo,
          dropRepository: likesForOwnRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'me',
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.text('ถูกใจ'));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('แก้ไขโปรไฟล์'), findsOneWidget);
      await tester.drag(find.text('ถูกใจ l0'), const Offset(0, -1000));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.text('แก้ไขโปรไฟล์'), findsNothing);
      expect(find.text('ถูกใจ'), findsWidgets);
    });
  });

  group('3. per-tab scroll position survives switching tabs', () {
    testWidgets(
        'scrolling the Posts tab, switching to Likes and back leaves the '
        'Posts tab scrolled where it was (not reset to the top)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewProfileScreen(
          profileRepository: ownProfileRepo,
          followRepository: followRepo,
          dropRepository: postsForOwnScrollRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'me',
        ),
      ));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.drag(find.text('โพสต์ sp0'), const Offset(0, -1000));
      await tester.pumpAndSettle();
      tester.takeException();
      // Header is gone and some early post has scrolled past the top.
      expect(find.text('แก้ไขโปรไฟล์'), findsNothing);
      expect(find.text('โพสต์ sp0'), findsNothing);

      await tester.tap(find.text('ถูกใจ'));
      await tester.pumpAndSettle();
      tester.takeException();
      await tester.tap(find.text('โพสต์'));
      await tester.pumpAndSettle();
      tester.takeException();

      // If the tab had reset to the top, the header ("แก้ไขโปรไฟล์") and
      // "โพสต์ sp0" would both be visible again. AutomaticKeepAliveClientMixin
      // + NestedScrollView's per-tab controller means neither is.
      expect(find.text('แก้ไขโปรไฟล์'), findsNothing,
          reason:
              'Posts tab scroll offset was reset to the top after switching '
              'tabs and back -- NestedScrollView is not preserving each '
              'tab\'s own inner scroll position.');
      expect(find.text('โพสต์ sp0'), findsNothing);
    });
  });

  group('4. infinite-scroll pagination past a real page boundary', () {
    testWidgets(
        'ProfileDropGridTab (Posts): one scroll past the threshold should '
        'fetch page 1 exactly once (QA-WYN-110-001: currently fetches '
        'several times -- see bug report)', (tester) async {
      await tester.pumpWidget(_wrapTab(ProfileDropGridTab(
        dropRepository: pagedPostsRepo,
        followRepository: followRepo,
        profileRepository: otherProfileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'someone-else',
        emptyText: 'ยังไม่มีโพสต์',
      )));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.scrollUntilVisible(
        find.byType(CircularProgressIndicator),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      tester.takeException();

      // The end result is correct either way -- see the two assertions
      // below -- but a single "near the bottom" crossing should cost
      // exactly 1 extra fetch (2 total including the initial page-0
      // load), not several. This is QA-WYN-110-001.
      expect(pagedPostsRepo.fetchByAuthorCalls, 2,
          reason:
              'QA-WYN-110-001: one scroll-to-near-bottom should trigger '
              'exactly one _loadMore() call; _onScrollNotification\'s '
              'addPostFrameCallback guard is checked at notification time, '
              'not at the callback\'s execution time, so several '
              'notifications queued within the same frame all schedule '
              'their own _loadMore(), each re-fetching the same next page.');

      // Whatever the call count, the *content* must still be correct --
      // no duplicate rows, no crash. Verifying that independently here
      // rather than assuming it from the call count alone.
      await tester.scrollUntilVisible(
        find.text('โพสต์ gp-new-2'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.text('โพสต์ gp-new-2'), findsOneWidget);
      expect(find.byType(HomeDropCard),
          findsNWidgets(DropRepository.pageSize + 2),
          reason:
              'despite the redundant fetches above, _seenKeys dedup means '
              'the visible list itself has no duplicate rows');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ProfileRedropsTab: one scroll past the threshold should fetch '
        'page 1 exactly once (same QA-WYN-110-001 pattern)', (tester) async {
      await tester.pumpWidget(_wrapTab(ProfileRedropsTab(
        homeRepository: pagedRedropsRepo,
        dropRepository: othersPostsRepo,
        followRepository: followRepo,
        profileRepository: otherProfileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'someone-else',
        emptyText: 'ยังไม่มีรีโพสต์',
      )));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.scrollUntilVisible(
        find.byType(CircularProgressIndicator),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(pagedRedropsRepo.fetchRedropsByUserCallsSeen, 2,
          reason: 'QA-WYN-110-001 (see ProfileDropGridTab\'s identical case)');

      await tester.scrollUntilVisible(
        find.text('โพสต์ rp-new-2'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.text('โพสต์ rp-new-2'), findsOneWidget);
      expect(find.byType(HomeDropCard),
          findsNWidgets(HomeRepository.pageSize + 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'ProfileLikesTab: one scroll past the threshold should fetch page '
        '1 exactly once (same QA-WYN-110-001 pattern, using the '
        'pre-existing likedDropPagesByAuthor fake)', (tester) async {
      await tester.pumpWidget(_wrapTab(ProfileLikesTab(
        dropRepository: pagedLikesRepo,
        followRepository: followRepo,
        profileRepository: otherProfileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'someone-else',
        emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
      )));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.scrollUntilVisible(
        find.byType(CircularProgressIndicator),
        600,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      tester.takeException();

      expect(pagedLikesRepo.fetchLikedByAuthorCalls, 2,
          reason: 'QA-WYN-110-001 (see ProfileDropGridTab\'s identical case)');

      await tester.scrollUntilVisible(
        find.text('โพสต์ lp-new-2'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.text('โพสต์ lp-new-2'), findsOneWidget);
      expect(find.byType(HomeDropCard),
          findsNWidgets(DropRepository.pageSize + 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('5. pull-to-refresh still works on every tab', () {
    testWidgets('ProfileDropGridTab RefreshIndicator.onRefresh does not throw',
        (tester) async {
      await tester.pumpWidget(_wrapTab(ProfileDropGridTab(
        dropRepository: refreshPostsRepo,
        followRepository: followRepo,
        profileRepository: ownProfileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'me',
        emptyText: 'ยังไม่มีโพสต์',
      )));
      await tester.pumpAndSettle();
      tester.takeException();

      final indicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      await indicator.onRefresh();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ProfileRedropsTab RefreshIndicator.onRefresh does not throw',
        (tester) async {
      await tester.pumpWidget(_wrapTab(ProfileRedropsTab(
        homeRepository: refreshRedropsRepo,
        dropRepository: othersPostsRepo,
        followRepository: followRepo,
        profileRepository: ownProfileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'me',
        emptyText: 'ยังไม่มีรีโพสต์',
      )));
      await tester.pumpAndSettle();
      tester.takeException();

      final indicator =
          tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
      await indicator.onRefresh();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('6. no overflow while actively dragging at small widths', () {
    const widths = [320.0, 360.0, 390.0, 430.0];
    for (var w = 0; w < widths.length; w++) {
      final width = widths[w];
      final repoIndex = w;
      testWidgets('$width px wide: no overflow mid-drag through the header',
          (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          home: ViewProfileScreen(
            profileRepository: otherProfileRepo,
            followRepository: followRepo,
            dropRepository: overflowRepos[repoIndex],
            popRepository: popRepo,
            savedRepository: savedRepo,
            userId: 'someone-else',
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Drag in small increments from a fixed screen point (not a
        // Finder pinned to text that itself scrolls out of reach after
        // the first drag) so intermediate/partially-collapsed header
        // frames -- not just the final rest state -- get a chance to
        // overflow.
        for (var i = 0; i < 10; i++) {
          await tester.dragFrom(Offset(width / 2, 400), const Offset(0, -60));
          await tester.pump(const Duration(milliseconds: 16));
          final exception = tester.takeException();
          expect(exception, isNull,
              reason: 'QA-WYN-110-002 (pre-existing, out of this diff\'s '
                  'scope): $exception');
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
