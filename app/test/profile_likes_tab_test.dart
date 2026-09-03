import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/post_media.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_repository.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_likes_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

Drop _drop({String id = 'd1', String? caption}) => Drop(
      id: id,
      caption: caption,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/$id.jpg',
      createdAt: DateTime.now(),
      likeCount: 1,
      commentCount: 0,
      likedByMe: true,
      savedByMe: false,
    );

extension on Drop {
  /// A copy of this fixture that has several images, with the ordered
  /// list already in hand -- what a batch-loaded page hands down.
  Drop copyWithImages({required int count, required List<String> urls}) => Drop(
        id: id,
        authorId: authorId,
        authorUsername: authorUsername,
        imageUrl: imageUrl,
        createdAt: createdAt,
        likeCount: likeCount,
        commentCount: commentCount,
        likedByMe: likedByMe,
        savedByMe: savedByMe,
        imageCount: count,
        imageUrls: urls,
      );
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  // Constructed in setUpAll, not inline per-test -- see profile_drafts_tab_test.dart's
  // own comment on why (GoTrue's Timer.periodic / FakeAsync zone attribution).
  late RecordingDropRepository emptyRepo;
  late RecordingDropRepository listRepo;
  late RecordingDropRepository errorRepo;
  late RecordingFollowRepository followRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;
  // WYN-099 -- same setUpAll discipline as every repo above.
  late RecordingProfileRepository canViewTrueRepo;
  late RecordingProfileRepository canViewFalseRepo;
  late int countingRepoCalls;
  late _CountingCanViewLikesProfileRepository countingRepo;
  // Beta3 -- built here, not in the test bodies: a fresh
  // RecordingDropRepository constructs a SupabaseClient, whose GoTrue
  // auto-refresh Timer.periodic would be attributed to that one test's
  // FakeAsync zone and trip flutter_test's !timersPending invariant at
  // teardown (see this group's own comment above).
  late RecordingDropRepository backFromDetailRepo;
  late RecordingDropRepository unlikedInDetailRepo;
  late RecordingDropRepository overlappingPagesRepo;
  late RecordingDropRepository carriedImagesRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    emptyRepo = RecordingDropRepository();
    listRepo = RecordingDropRepository()
      ..likedDropsByAuthor = {
        'someone-else': [_drop(id: 'd1'), _drop(id: 'd2')],
      };
    errorRepo = RecordingDropRepository()..fetchLikedByAuthorError = Exception('boom');
    followRepo = RecordingFollowRepository();
    profileRepo = RecordingProfileRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
    canViewTrueRepo = RecordingProfileRepository()..canViewLikesResult = true;
    canViewFalseRepo = RecordingProfileRepository()..canViewLikesResult = false;
    countingRepoCalls = 0;
    countingRepo = _CountingCanViewLikesProfileRepository(
      onCall: () => countingRepoCalls++,
    );
    backFromDetailRepo = RecordingDropRepository();
    unlikedInDetailRepo = RecordingDropRepository();
    overlappingPagesRepo = RecordingDropRepository();
    carriedImagesRepo = RecordingDropRepository();
  });

  testWidgets('shows the empty state when the author has liked nothing',
      (tester) async {
    await tester.pumpWidget(_wrap(ProfileLikesTab(
      dropRepository: emptyRepo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'someone-else',
      emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
    )));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีอะไรที่ถูกใจ'), findsOneWidget);
  });

  testWidgets(
      'shows every Drop returned by fetchLikedByAuthor as a full-width '
      'post card', (tester) async {
    await tester.pumpWidget(_wrap(ProfileLikesTab(
      dropRepository: listRepo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'someone-else',
      emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
    )));
    await tester.pumpAndSettle();
    tester.takeException();

    // A full-width HomeDropCard is much taller than the old grid tile
    // was, so the 2nd card isn't guaranteed to be on-screen without
    // scrolling -- scroll it into view (a no-op if it's already
    // visible) rather than asserting the exact pre-scroll count, which
    // depends on card height (and, since WYN-093, on the 0.75x-screen-
    // height cap on the image area too -- not a fixed number of pixels
    // this test should hardcode an assumption about).
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('d2')),
      500,
      scrollable: find.byType(Scrollable),
    );
    tester.takeException();
    expect(find.byType(HomeDropCard), findsNWidgets(2));
  });

  testWidgets(
      'WYN-081: pulling to refresh also calls onRefreshHeader, not just '
      "this tab's own reload", (tester) async {
    var refreshHeaderCalls = 0;
    await tester.pumpWidget(_wrap(ProfileLikesTab(
      dropRepository: listRepo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'someone-else',
      emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
      onRefreshHeader: () => refreshHeaderCalls++,
    )));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(refreshHeaderCalls, 0,
        reason: 'the initial load must not have triggered it');

    // Same off-screen-hit-test-avoidance as elsewhere in this suite --
    // invoke RefreshIndicator.onRefresh directly rather than simulating
    // a physical drag gesture.
    final indicator = tester.widget<RefreshIndicator>(
      find.byType(RefreshIndicator),
    );
    await indicator.onRefresh();
    await tester.pumpAndSettle();
    tester.takeException();

    expect(refreshHeaderCalls, 1);
  });

  testWidgets('a fetch failure shows an error with a retry button',
      (tester) async {
    await tester.pumpWidget(_wrap(ProfileLikesTab(
      dropRepository: errorRepo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'someone-else',
      emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
    )));
    await tester.pumpAndSettle();

    expect(find.text('โหลดรายการที่ถูกใจไม่สำเร็จ'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'ลองใหม่'), findsOneWidget);
  });

  group('WYN-099: distinguishing "no Likes yet" from "not allowed to see '
      'this"', () {
    testWidgets(
        'an empty list + canViewLikes true shows the ordinary empty '
        'text, not the privacy-blocked one', (tester) async {
      await tester.pumpWidget(_wrap(ProfileLikesTab(
        dropRepository: emptyRepo,
        followRepository: followRepo,
        profileRepository: canViewTrueRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'someone-else',
        emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
      )));
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีอะไรที่ถูกใจ'), findsOneWidget);
      expect(find.text('บัญชีนี้ซ่อนรายการที่ถูกใจไว้'), findsNothing);
    });

    testWidgets(
        'an empty list + canViewLikes false shows the privacy-blocked '
        'empty state instead of the ordinary "no Likes yet" text',
        (tester) async {
      await tester.pumpWidget(_wrap(ProfileLikesTab(
        dropRepository: emptyRepo,
        followRepository: followRepo,
        profileRepository: canViewFalseRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'someone-else',
        emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
      )));
      await tester.pumpAndSettle();

      expect(find.text('บัญชีนี้ซ่อนรายการที่ถูกใจไว้'), findsOneWidget);
      expect(find.text('ยังไม่มีอะไรที่ถูกใจ'), findsNothing);
    });

    testWidgets(
        'a non-empty list never calls canViewLikes at all -- the RPC '
        'itself already filtered to only what is visible', (tester) async {
      await tester.pumpWidget(_wrap(ProfileLikesTab(
        dropRepository: listRepo,
        followRepository: followRepo,
        profileRepository: countingRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'someone-else',
        emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
      )));
      await tester.pumpAndSettle();
      tester.takeException();

      expect(countingRepoCalls, 0);
    });
  });

  group('Beta3 -- coming back from Detail', () {
    testWidgets(
        'refreshes only the row that was opened, instead of reloading the '
        'whole tab', (tester) async {
      // The defect: _openDropDetail ended in _loadInitial(), which
      // flipped _isLoadingInitial back to true -- the list was replaced
      // by a spinner, the ListView (and its scroll position) was torn
      // down, and every page paged in so far was thrown away. Open the
      // 30th post on a profile, come back, and it was somewhere far
      // below you again.
      final repo = backFromDetailRepo
        ..likedDropsByAuthor = {
          'someone-else': [_drop(id: 'd1'), _drop(id: 'd2')],
        };

      await tester.pumpWidget(_wrap(ProfileLikesTab(
        dropRepository: repo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'someone-else',
        emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
      )));
      await tester.pumpAndSettle();
      tester.takeException();
      expect(repo.fetchLikedByAuthorCalls, 1);

      // The row comes back with one more like on it than it went in
      // with -- the resync has to actually pick that up.
      repo.fetchByIdResults['d1'] =
          _drop(id: 'd1').copyWith(likeCount: 9);

      // The comment metric, not the card body: the body's centre is
      // the image, whose double-tap-to-like recognizer holds a single
      // tap for the disambiguation window. Both open Detail.
      await tester.tap(find.bySemanticsLabel('ดูคอมเมนต์').first);
      await tester.pumpAndSettle();
      tester.takeException();
      expect(find.byType(DropDetailScreen), findsOneWidget);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();
      tester.takeException();

      // One targeted refresh of the row that was open...
      expect(repo.fetchByIdCalls, 1);
      // ...and no second page-0 reload of the list behind it.
      expect(repo.fetchLikedByAuthorCalls, 1);
      // The list itself is still standing -- never replaced by the
      // initial-load spinner.
      expect(find.byType(HomeDropCard), findsNWidgets(2));
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('drops a row that was unliked while Detail was open',
        (tester) async {
      // This is the Likes tab: a post the viewer unliked no longer
      // belongs in it, the same way a deleted post doesn't.
      final repo = unlikedInDetailRepo
        ..likedDropsByAuthor = {
          'me': [_drop(id: 'd1'), _drop(id: 'd2')],
        };
      repo.fetchByIdResults['d1'] =
          _drop(id: 'd1').copyWith(likedByMe: false, likeCount: 0);

      await tester.pumpWidget(_wrap(ProfileLikesTab(
        dropRepository: repo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        authorId: 'me',
        emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
      )));
      await tester.pumpAndSettle();
      tester.takeException();

      await tester.tap(find.bySemanticsLabel('ดูคอมเมนต์').first);
      await tester.pumpAndSettle();
      tester.takeException();

      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      tester.takeException();

      expect(find.byType(HomeDropCard), findsOneWidget);
    });
  });

  testWidgets(
      'Beta3: a second page that overlaps the first does not put the same '
      'row in the list twice', (tester) async {
    // What offset pagination really does: someone adds a row at the top
    // while the reader is scrolling, so everything shifts down one and
    // the last row of page 0 comes back as the first row of page 1.
    // Appended blindly that showed the row twice *and* put two
    // identical ValueKeys in one ListView -- which Flutter rejects
    // outright, so the tab threw rather than merely looking wrong.
    final pageZero = [
      for (var i = 0; i < DropRepository.pageSize - 1; i++) _drop(id: 'd$i'),
      // The boundary row, captioned so the test can count how many
      // times it actually renders.
      _drop(id: 'boundary', caption: 'ROW-AT-THE-PAGE-BOUNDARY'),
    ];
    final repo = overlappingPagesRepo
      ..likedDropPagesByAuthor = {
        'someone-else': [
          pageZero,
          // Page 1 leads with page 0's last row, then genuinely new ones.
          [pageZero.last, _drop(id: 'new-1'), _drop(id: 'new-2')],
        ],
      };

    await tester.pumpWidget(_wrap(ProfileLikesTab(
      dropRepository: repo,
      followRepository: followRepo,
      profileRepository: profileRepo,
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

    expect(repo.fetchLikedByAuthorCalls, 2);
    // The boundary row is in the list exactly once. Without the guard
    // it is appended a second time immediately after itself -- both
    // copies adjacent, both in the viewport, both carrying
    // ValueKey('boundary').
    await tester.scrollUntilVisible(
      find.text('ROW-AT-THE-PAGE-BOUNDARY'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('ROW-AT-THE-PAGE-BOUNDARY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Beta3: a multi-image post on a profile costs no image request of its '
      'own, the same as in the feed', (tester) async {
    // Founder, 2026-09-03: "โปรไฟล์ ก็ต้องคล้ายฟีดดิ (โพสต์)". These
    // tabs already build the feed's own HomeDropCard -- but they build
    // it from a plain Drop, which used to carry no image list, so a
    // multi-image post here still asked the server for its own images
    // from inside the card. The feed stopped doing that; this is the
    // same card, so it stops here too.
    final withImages = _drop(id: 'multi').copyWithImages(
      count: 3,
      urls: const [
        'https://example.supabase.co/drops/multi_0.jpg',
        'https://example.supabase.co/drops/multi_1.jpg',
        'https://example.supabase.co/drops/multi_2.jpg',
      ],
    );
    final repo = carriedImagesRepo
      ..likedDropsByAuthor = {
        'someone-else': [withImages],
      };

    await tester.pumpWidget(_wrap(ProfileLikesTab(
      dropRepository: repo,
      followRepository: followRepo,
      profileRepository: profileRepo,
      popRepository: popRepo,
      savedRepository: savedRepo,
      authorId: 'someone-else',
      emptyText: 'ยังไม่มีอะไรที่ถูกใจ',
    )));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(repo.fetchDropImagesCalls, 0);
    // ...and the card row is built on the first frame, snapping cards
    // and all, rather than a lone photo that swaps a moment later.
    expect(find.byType(PostImageCarousel), findsOneWidget);
  });
}

class _CountingCanViewLikesProfileRepository extends RecordingProfileRepository {
  _CountingCanViewLikesProfileRepository({required this.onCall});

  final VoidCallback onCall;

  @override
  Future<bool> canViewLikes(String targetUserId) async {
    onCall();
    return super.canViewLikes(targetUserId);
  }
}
