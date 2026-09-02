import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_likes_tab.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

Drop _drop({String id = 'd1'}) => Drop(
      id: id,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/$id.jpg',
      createdAt: DateTime.now(),
      likeCount: 1,
      commentCount: 0,
      likedByMe: true,
      savedByMe: false,
    );

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
}
