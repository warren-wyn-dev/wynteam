import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/follow/presentation/follow_list_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/profile/presentation/widgets/avatar_circle.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_skeleton.dart';
import 'package:wyn/features/saved/presentation/widgets/saved_post_row.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_home_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  const ownProfile = Profile(
    id: 'me',
    username: 'me_user',
    displayName: 'ตัวฉันเอง',
  );
  const otherProfile = Profile(
    id: 'someone-else',
    username: 'namfah',
    displayName: 'น้ำฝน',
  );

  late RecordingProfileRepository ownProfileRepo;
  late RecordingFollowRepository ownFollowRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  late RecordingProfileRepository otherProfileRepo;
  late RecordingFollowRepository otherFollowRepo;

  late RecordingProfileRepository contentTestProfileRepo;
  late RecordingFollowRepository contentTestFollowRepo;
  late RecordingDropRepository contentTestDropRepo;
  late RecordingPopRepository contentTestPopRepo;
  late RecordingSavedRepository contentTestSavedRepo;
  late RecordingHomeRepository contentTestHomeRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    ownProfileRepo = RecordingProfileRepository(profile: ownProfile);
    ownFollowRepo = RecordingFollowRepository(followerCount: 12, followingCount: 5);
    dropRepo = RecordingDropRepository()
      ..dropCountByAuthor = {'me': 6};
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();

    otherProfileRepo = RecordingProfileRepository(profile: otherProfile);
    otherFollowRepo = RecordingFollowRepository(followerCount: 3, followingCount: 8);

    contentTestProfileRepo = RecordingProfileRepository(profile: ownProfile);
    contentTestFollowRepo = RecordingFollowRepository();
    contentTestDropRepo = RecordingDropRepository(feedDrops: [
      Drop(
        id: 'd1',
        authorId: 'me',
        authorUsername: 'me_user',
        imageUrl: 'https://example.supabase.co/drops/d1.jpg',
        caption: 'แคปชัน Drop ของฉัน',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      ),
    ]);
    contentTestPopRepo = RecordingPopRepository(feedPops: [
      Pop(
        id: 'p1',
        authorId: 'me',
        authorUsername: 'me_user',
        videoUrl: 'https://example.supabase.co/pops/p1.mp4',
        durationSeconds: 42,
        viewCount: 0,
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
      ),
    ]);
    contentTestSavedRepo = RecordingSavedRepository(feedItems: [
      HomeFeedItem(
        id: 'd2',
        contentType: HomeContentType.drop,
        authorId: 'someone-else',
        authorUsername: 'namfah',
        createdAt: DateTime.now(),
        caption: 'แคปชันที่บันทึกไว้',
        imageUrl: 'https://example.supabase.co/drops/d2.jpg',
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: true,
        // WYN-038 -- avoids rendering the literal string "null" if this
        // item is ever shown through a HomeDropCard-style widget.
        viewCount: 0,
      ),
    ]);
    contentTestHomeRepo = RecordingHomeRepository(redropsByUser: [
      HomeFeedItem(
        id: 'd3',
        contentType: HomeContentType.drop,
        authorId: 'someone-else',
        authorUsername: 'namfah',
        createdAt: DateTime.now(),
        caption: 'แคปชัน Drop ต้นฉบับ',
        imageUrl: 'https://example.supabase.co/drops/d3.jpg',
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
        savedByMe: false,
        redropId: 'r1',
        redropperId: 'me',
        redropperUsername: 'me_user',
        quoteText: 'ดูนี่สิ',
        // WYN-038 -- this item renders through HomeDropCard (see
        // ProfileRedropsTab), which would show the literal string
        // "null" for view count without this.
        viewCount: 0,
      ),
    ]);
  });

  Widget buildProfile({
    required RecordingProfileRepository profileRepository,
    required RecordingFollowRepository followRepository,
    required String userId,
  }) =>
      MaterialApp(
        home: ViewProfileScreen(
          profileRepository: profileRepository,
          followRepository: followRepository,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: userId,
        ),
      );

  testWidgets(
      'shows Follower/Following/Post counts loaded alongside the profile '
      '(05-profile.tsx\'s 3rd StatsRow stat)', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('ผู้ติดตาม'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('กำลังติดตาม'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // The StatsRow label and the "โพสต์" Tab both say the same word.
    expect(find.text('โพสต์'), findsNWidgets(2));
  });

  testWidgets(
      'WYN-095 Mockup A: avatar sits beside the stats row (same top '
      'edge), with display name/username left-aligned below that row, '
      'not the old fully-centered avatar-then-name-then-stats order',
      (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    final avatarRect = tester.getRect(find.byType(AvatarCircle));
    final statsCenterY = tester.getCenter(find.text('ผู้ติดตาม')).dy;
    final nameTop = tester.getTopLeft(find.text('ตัวฉันเอง')).dy;
    final usernameTop = tester.getTopLeft(find.text('@me_user')).dy;

    // The stats row's vertical center falls inside the avatar's own
    // vertical span -- i.e. they're cross-axis-centered in one shared
    // Row (the avatar is taller than the stat text, so their tops
    // don't match, but neither is "below" the other).
    expect(statsCenterY, greaterThan(avatarRect.top));
    expect(statsCenterY, lessThan(avatarRect.bottom));
    // Display name comes entirely after the avatar+stats row, not
    // beside it.
    expect(nameTop, greaterThanOrEqualTo(avatarRect.bottom));
    // Username comes right after the display name.
    expect(usernameTop, greaterThan(nameTop));

    // Display name/username are left-aligned with the avatar, not
    // centered on screen (the old wyn-071 layout centered everything).
    final avatarLeft = tester.getTopLeft(find.byType(AvatarCircle)).dx;
    final nameLeft = tester.getTopLeft(find.text('ตัวฉันเอง')).dx;
    expect((avatarLeft - nameLeft).abs(), lessThan(1));
  });

  testWidgets(
      'WYN-095 Mockup A: Follow and Message buttons split a full-width '
      'row evenly, replacing the old natural-width pill + 40x40 icon '
      'button pair', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: otherProfileRepo,
      followRepository: otherFollowRepo,
      userId: 'someone-else',
    ));
    await tester.pumpAndSettle();

    final followWidth =
        tester.getSize(find.widgetWithText(FilledButton, 'ติดตาม')).width;
    final messageWidth =
        tester.getSize(find.widgetWithText(OutlinedButton, 'ส่งข้อความ')).width;

    // Both buttons are wide (full-width split), not a small pill next
    // to a 40px icon-only circle like the pre-WYN-095 layout.
    expect(followWidth, greaterThan(250));
    expect(messageWidth, greaterThan(250));
    // Split evenly (Expanded on both sides of the Row).
    expect((followWidth - messageWidth).abs(), lessThan(2));
  });

  testWidgets(
      'shows a skeleton loading state (not a bare spinner) while the '
      'initial fetch is in flight', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));

    expect(find.byType(ProfileSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpAndSettle();

    expect(find.byType(ProfileSkeleton), findsNothing);
  });

  testWidgets(
      'the Edit Profile button is a small centered pill, not a full-width '
      'bordered button (05-profile.tsx de-emphasizes it)', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    final buttonFinder =
        find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์');
    final buttonWidth = tester.getSize(buttonFinder).width;
    // Sized to its content (a pill), well under the ~450px a
    // full-width button would span on the 800px-wide default test
    // viewport.
    expect(buttonWidth, lessThan(250));
  });

  testWidgets('tapping the Followers count opens FollowListScreen in '
      'followers mode', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ผู้ติดตาม'));
    await tester.pumpAndSettle();

    final screen = tester.widget<FollowListScreen>(
      find.byType(FollowListScreen),
    );
    expect(screen.mode, FollowListMode.followers);
  });

  testWidgets('tapping the Following count opens FollowListScreen in '
      'following mode', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('กำลังติดตาม'));
    await tester.pumpAndSettle();

    final screen = tester.widget<FollowListScreen>(
      find.byType(FollowListScreen),
    );
    expect(screen.mode, FollowListMode.following);
  });

  testWidgets(
      'own profile shows Edit, Saved/Draft icons, 3 public tabs, no '
      'Follow button, and no logout icon (WYN-013, WYN-071, '
      '05-profile.tsx)',
      (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'), findsOneWidget);
    // 05-profile.tsx removes the standalone header logout icon --
    // moved into SettingsScreen instead, see settings_screen_test.dart.
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'ติดตาม'), findsNothing);
    // WYN-071: Saved/Draft are icons next to "แก้ไขโปรไฟล์" now, not tabs.
    expect(find.byKey(const Key('profile_saved_button')), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
    // 05-profile.tsx cuts Replies/Media -- 3 tabs now, Thai-labeled to
    // match the reference exactly. "โพสต์" appears twice (the StatsRow
    // label and the Tab both say it).
    expect(find.text('โพสต์'), findsNWidgets(2));
    expect(find.text('รีโพสต์'), findsOneWidget);
    expect(find.text('ถูกใจ'), findsOneWidget);
    expect(find.text('Replies'), findsNothing);
    expect(find.text('Media'), findsNothing);
    // Pop is hidden from Profile for WYNOS V1.0.0 Beta -- requirement 3.
    expect(find.text('Pop'), findsNothing);
    expect(find.text('บันทึก'), findsNothing);
    expect(find.text('ร่าง'), findsNothing);
    expect(find.byType(Tab), findsNWidgets(3));
  });

  testWidgets(
      'someone else\'s profile shows Follow, the same 3 public tabs, no '
      'Saved/Draft icons/Pop, and no Edit/logout (WYN-013, WYN-071)',
      (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: otherProfileRepo,
      followRepository: otherFollowRepo,
      userId: 'someone-else',
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
    // 18-other-profile.tsx: a filled sapphire pill, not an outlined
    // button (that's Edit Profile's own de-emphasized treatment).
    expect(find.widgetWithText(FilledButton, 'ติดตาม'), findsOneWidget);
    expect(find.byKey(const Key('profile_saved_button')), findsNothing);
    expect(find.byIcon(Icons.edit_note_outlined), findsNothing);
    expect(find.text('โพสต์'), findsNWidgets(2));
    expect(find.text('รีโพสต์'), findsOneWidget);
    expect(find.text('ถูกใจ'), findsOneWidget);
    // Pop is hidden from Profile for WYNOS V1.0.0 Beta -- requirement 3.
    expect(find.text('Pop'), findsNothing);
    expect(find.byType(Tab), findsNWidgets(3));
  });

  testWidgets('the header stays "โปรไฟล์" for your own profile',
      (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'โปรไฟล์'), findsOneWidget);
  });

  testWidgets(
      '18-other-profile.tsx: the header names the profile owner ("@namfah") '
      'for someone else\'s profile', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: otherProfileRepo,
      followRepository: otherFollowRepo,
      userId: 'someone-else',
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, '@namfah'), findsOneWidget);
  });

  testWidgets(
      'WYN-095 Mockup A: the message button is a full-width labeled '
      '"ส่งข้อความ" pill, not a circular icon-only button', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: otherProfileRepo,
      followRepository: otherFollowRepo,
      userId: 'someone-else',
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.send_outlined), findsOneWidget);
    expect(find.text('ส่งข้อความ'), findsOneWidget);
  });

  testWidgets(
      'WYN-085: someone else\'s profile has no notifications bell icon '
      '(it used to push NotificationListScreen, a back-button-less screen '
      'that stranded the viewer with no way to navigate elsewhere)',
      (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: otherProfileRepo,
      followRepository: otherFollowRepo,
      userId: 'someone-else',
    ));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    // The search shortcut (also WYN-071) is unaffected -- it pushes a
    // screen with a real AppBar/back button, so it stays.
    expect(find.byIcon(Icons.search), findsOneWidget);
  });

  testWidgets('Drop tab shows this profile\'s Drops (scoped by author, '
      'not the global feed)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ViewProfileScreen(
        profileRepository: contentTestProfileRepo,
        followRepository: contentTestFollowRepo,
        dropRepository: contentTestDropRepo,
        popRepository: contentTestPopRepo,
        savedRepository: contentTestSavedRepo,
        userId: 'me',
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // Drop is the first (default-selected) tab -- its content should be
    // visible without switching tabs. 05-profile.tsx's PostRow is a
    // full-width HomeDropCard now, not a grid tile.
    expect(find.byType(HomeDropCard), findsOneWidget);
    expect(find.text('แคปชัน Drop ของฉัน'), findsOneWidget);
  });

  testWidgets(
      'switching to the ReDrops tab shows this profile\'s Standard/Quote '
      'ReDrops, with the quote text and original Drop untouched (WYN-034)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ViewProfileScreen(
        profileRepository: contentTestProfileRepo,
        followRepository: contentTestFollowRepo,
        dropRepository: contentTestDropRepo,
        popRepository: contentTestPopRepo,
        savedRepository: contentTestSavedRepo,
        homeRepository: contentTestHomeRepo,
        userId: 'me',
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('รีโพสต์'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(contentTestHomeRepo.fetchRedropsByUserUserIdArgs, contains('me'));
    expect(find.text('ดูนี่สิ'), findsOneWidget);
    expect(find.text('แคปชัน Drop ต้นฉบับ'), findsOneWidget);
    expect(find.textContaining('รีโพสต์โดย @me_user'), findsOneWidget);
  });

  // "switching to the Pop tab shows this profile's Pops" removed -- Pop is
  // hidden from Profile for WYNOS V1.0.0 Beta (requirement 3), so there is
  // no more Pop tab to switch to here. ProfilePopGridTab itself (and its
  // own widget test, if any) is untouched -- only this screen stopped
  // wiring it up.

  testWidgets(
      'tapping the Saved icon opens saved Drop/Pop content (WYN-071: no '
      'longer a tab)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ViewProfileScreen(
        profileRepository: contentTestProfileRepo,
        followRepository: contentTestFollowRepo,
        dropRepository: contentTestDropRepo,
        popRepository: contentTestPopRepo,
        savedRepository: contentTestSavedRepo,
        userId: 'me',
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.byKey(const Key('profile_saved_button')));
    await tester.pumpAndSettle();
    tester.takeException();

    // BookmarksScreen (15-bookmarks.tsx) shows its own full-width
    // SavedPostRow list, not ProfileSavedTab's SavedGridTile grid -- see
    // bookmarks_screen.dart's own doc comment.
    expect(find.byType(SavedPostRow), findsOneWidget);
    expect(find.text('แคปชันที่บันทึกไว้'), findsOneWidget);
  });

  // "Club ของฉัน" section (WYN-015) removed -- 05-profile.tsx drops the
  // shelf from Profile entirely (still reachable via Home's "From Your
  // Clubs" feed). See view_profile_screen.dart's own comment on
  // ClubRepository/ClubPostRepository still being threaded through
  // (only for _openSearch now -- see that comment for why its former
  // sibling _openNotifications is gone, WYN-085).

  group('"Profile Visit" User Signal (WYNOS Unified Home Feed Algorithm '
      'V1.0)', () {
    // Constructed once in setUpAll (not per-test) -- same "avoid a leaked
    // GoTrue auto-refresh timer" discipline as every other
    // RecordingXRepository across this project's test suite
    // (.wyn/learning/PATTERNS.md) -- cleared between tests instead of
    // re-constructed.
    late RecordingHomeRepository visitHomeRepo;

    setUpAll(() {
      visitHomeRepo = RecordingHomeRepository();
    });

    setUp(() {
      visitHomeRepo.recordProfileVisitArgs.clear();
    });

    testWidgets('opening someone else\'s profile records a Profile Visit',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewProfileScreen(
          profileRepository: otherProfileRepo,
          followRepository: otherFollowRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'someone-else',
          homeRepository: visitHomeRepo,
        ),
      ));
      await tester.pumpAndSettle();

      expect(visitHomeRepo.recordProfileVisitArgs, ['someone-else']);
    });

    testWidgets('opening your own profile never records a Profile Visit',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewProfileScreen(
          profileRepository: ownProfileRepo,
          followRepository: ownFollowRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'me',
          homeRepository: visitHomeRepo,
        ),
      ));
      await tester.pumpAndSettle();

      expect(visitHomeRepo.recordProfileVisitArgs, isEmpty);
    });
  });
}
