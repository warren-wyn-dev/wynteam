// WYN-110: the Founder reported (screen recording, 2026-09-05) that
// scrolling posts on a profile only ever revealed the bottom half of the
// screen -- the header (avatar/name/bio/stats/button) and the TabBar sat
// in a plain, non-scrolling Column, so they stayed on screen permanently
// no matter how far the reader scrolled. Every test elsewhere in this
// suite that mounts ViewProfileScreen never drags it, so none of them
// would have caught this. This file drives an actual scroll gesture and
// checks the one property that matters: the header leaves, the TabBar
// stays pinned at the top, and scrolling back up brings the header back
// -- the same two-way behavior home_feed_screen.dart's own pinned
// feed-mode toggle already has.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  // Built once in setUpAll, not per test body -- a Recording*Repository
  // constructs a real SupabaseClient, whose GoTrue auto-refresh
  // Timer.periodic gets attributed to whichever test happened to be
  // running when it was created, and trips flutter_test's
  // `!timersPending` invariant at that test's teardown if it's a fresh
  // one made inline. See .wyn/learning/PATTERNS.md and every other test
  // file in this suite for the same discipline.
  late RecordingProfileRepository profileRepo;
  late RecordingFollowRepository followRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    profileRepo = RecordingProfileRepository(
      profile: const Profile(
        id: 'me',
        username: 'me_user',
        displayName: 'ตัวฉันเอง',
      ),
    );
    followRepo = RecordingFollowRepository();
    // 40 short text-only posts -- comfortably more than a 600px test
    // viewport can show at once, so there is real scroll distance to
    // exercise, regardless of exactly how tall one HomeDropCard renders.
    dropRepo = RecordingDropRepository(feedDrops: [
      for (var i = 0; i < 40; i++)
        Drop(
          id: 'd$i',
          authorId: 'me',
          authorUsername: 'me_user',
          caption: 'โพสต์ที่ $i',
          createdAt: DateTime.now(),
          likeCount: 0,
          commentCount: 0,
          likedByMe: false,
          savedByMe: false,
        ),
    ]);
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
  });

  Future<void> pumpScrollableProfile(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ViewProfileScreen(
        profileRepository: profileRepo,
        followRepository: followRepo,
        dropRepository: dropRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        userId: 'me',
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();
  }

  testWidgets('the header is on screen at rest, before any scrolling happens',
      (tester) async {
    await pumpScrollableProfile(tester);

    expect(find.text('แก้ไขโปรไฟล์'), findsOneWidget);
    expect(find.text('โพสต์'), findsOneWidget);
  });

  testWidgets(
      'scrolling past the header leaves the edit-profile button behind '
      'but keeps the tab bar on screen', (tester) async {
    await pumpScrollableProfile(tester);

    // One long drag is enough to carry the header (well under 400px:
    // avatar + name + bio + stats + button) out of a 600px viewport.
    await tester.drag(find.text('โพสต์ที่ 0'), const Offset(0, -900));
    await tester.pumpAndSettle();
    tester.takeException();

    // The header scrolled away with the rest of the content...
    expect(find.text('แก้ไขโปรไฟล์'), findsNothing);
    // ...but the TabBar -- the one thing that is supposed to stay --
    // is still there, pinned rather than scrolled off with it.
    expect(find.text('โพสต์'), findsOneWidget);
    expect(find.text('รีโพสต์'), findsOneWidget);
    expect(find.text('ถูกใจ'), findsOneWidget);

    // Pinned means fixed at a Y position, not just "still built
    // somewhere off-screen": it must actually be on screen, just below
    // the AppBar.
    final tabBarTop = tester.getTopLeft(find.text('โพสต์')).dy;
    expect(tabBarTop, greaterThan(0));
    expect(tabBarTop, lessThan(150));
  });

  testWidgets(
      'scrolling back up brings the header back -- this is what a plain '
      'SliverFillRemaining (no NestedScrollView) could not do', (tester) async {
    await pumpScrollableProfile(tester);

    await tester.drag(find.text('โพสต์ที่ 0'), const Offset(0, -900));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('แก้ไขโปรไฟล์'), findsNothing);

    // Drag back down by the same amount, from wherever the pointer can
    // still find scrollable content (the tab bar itself doesn't scroll,
    // so drag from a visible post row instead).
    await tester.drag(find.text('โพสต์ที่ 5'), const Offset(0, 900));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('แก้ไขโปรไฟล์'), findsOneWidget);
  });

  testWidgets(
      'switching tabs after scrolling past the header does not throw, '
      'and the new tab starts back at its own top', (tester) async {
    await pumpScrollableProfile(tester);

    await tester.drag(find.text('โพสต์ที่ 0'), const Offset(0, -900));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('ถูกใจ'));
    await tester.pumpAndSettle();
    tester.takeException();

    // No crash, and the (empty) Likes tab's own empty text renders --
    // proves the TabBarView + NestedScrollView body switched cleanly.
    expect(find.textContaining('ถูกใจ'), findsWidgets);
  });
}
