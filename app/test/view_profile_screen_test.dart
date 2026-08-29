import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/follow/presentation/follow_list_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_skeleton.dart';
import 'package:wyn/features/saved/presentation/widgets/saved_grid_tile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
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
  late RecordingClubPostRepository clubPostRepo;

  late RecordingProfileRepository otherProfileRepo;
  late RecordingFollowRepository otherFollowRepo;

  late RecordingClubRepository clubsJoinedRepo;

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
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();

    clubPostRepo = RecordingClubPostRepository();

    otherProfileRepo = RecordingProfileRepository(profile: otherProfile);
    otherFollowRepo = RecordingFollowRepository(followerCount: 3, followingCount: 8);

    clubsJoinedRepo = RecordingClubRepository(myClubs: [
      Club(
        id: 'club-1',
        name: 'ชมรมถ่ายภาพ',
        privacy: ClubPrivacy.public,
        ownerId: 'me',
        createdAt: DateTime.now(),
        memberCount: 5,
      ),
    ]);

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

  testWidgets('shows Follower/Following counts loaded alongside the profile',
      (tester) async {
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
      'WYN-073: the Edit Profile button is a small centered pill, not a '
      'full-width button', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    final buttonFinder = find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์');
    final buttonWidth = tester.getSize(buttonFinder).width;
    // WYN-073 de-emphasized this button (`/05-profile.tsx`'s ActionRow,
    // R4) -- it no longer stretches across the screen (that used to
    // assert > 400 here, WYN-065/WYN-071); a small pill sized to its
    // label + fixed horizontal padding is well under half that.
    expect(buttonWidth, lessThan(250));
    // Still sits beside the Bookmark/PenLine icons (same destinations
    // as before -- see the next test), not alone.
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
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
      'own profile shows Edit + Saved/Draft icons, 3 public tabs '
      '(โพสต์/ReDrop/ถูกใจ), no logout icon, and no Follow button '
      '(WYN-013, WYN-073)',
      (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'), findsOneWidget);
    // WYN-073: the standalone header logout icon is gone -- only the
    // gear (Settings) remains. Sign-out now lives inside SettingsScreen
    // instead (see settings_screen_test.dart).
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ติดตาม'), findsNothing);
    // WYN-071: Saved/Draft are icons next to "แก้ไขโปรไฟล์" now, not tabs.
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
    // WYN-073: 3 tabs now (โพสต์/ReDrop/ถูกใจ) -- ตอบกลับ/มีเดีย removed
    // from own-profile per `/05-profile.tsx`'s own explicit change list
    // (a deliberate reversal of WYN-071's 5-tab set for this branch
    // only -- someone else's profile still has all 5, see the next
    // test).
    // "โพสต์" appears twice by design here: once as the Stats row's 3rd
    // stat label (R3, data.postCount), once as the 1st tab's own label.
    expect(find.text('โพสต์'), findsNWidgets(2));
    expect(find.text('ReDrop'), findsOneWidget);
    expect(find.text('ถูกใจ'), findsOneWidget);
    expect(find.text('Posts'), findsNothing);
    expect(find.text('ReDrops'), findsNothing);
    expect(find.text('Replies'), findsNothing);
    expect(find.text('Media'), findsNothing);
    expect(find.text('Likes'), findsNothing);
    expect(find.text('Pop'), findsNothing);
    expect(find.text('บันทึก'), findsNothing);
    expect(find.text('ร่าง'), findsNothing);
    expect(find.byType(Tab), findsNWidgets(3));
  });

  testWidgets(
      'someone else\'s profile shows Follow, the same 5 public tabs, no '
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
    expect(find.widgetWithText(OutlinedButton, 'ติดตาม'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
    expect(find.byIcon(Icons.edit_note_outlined), findsNothing);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('ReDrops'), findsOneWidget);
    expect(find.text('Replies'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);
    // Pop is hidden from Profile for WYNOS V1.0.0 Beta -- requirement 3.
    expect(find.text('Pop'), findsNothing);
    expect(find.byType(Tab), findsNWidgets(5));
  });

  testWidgets(
      'WYN-073: โพสต์ tab shows this profile\'s Drops as full-width rows '
      '(scoped by author, not the global feed)', (tester) async {
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

    // โพสต์ is the first (default-selected) tab -- its content should
    // be visible without switching tabs. The 3-column grid tile is gone
    // (WYN-073) -- this Drop's own caption now renders directly as a
    // WynosPostRow, and its (unliked) heart icon is the outline variant.
    expect(find.text('แคปชัน Drop ของฉัน'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets(
      'WYN-073: switching to the ReDrop tab shows this profile\'s '
      'Standard/Quote ReDrops as full-width rows, with the quote text '
      'and original Drop untouched (WYN-034)',
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

    await tester.tap(find.text('ReDrop'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(contentTestHomeRepo.fetchRedropsByUserUserIdArgs, contains('me'));
    expect(find.text('ดูนี่สิ'), findsOneWidget);
    expect(find.text('แคปชัน Drop ต้นฉบับ'), findsOneWidget);
    expect(find.textContaining('ReDrop โดย @me_user'), findsOneWidget);
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

    await tester.tap(find.byIcon(Icons.bookmark_border));
    await tester.pumpAndSettle();
    tester.takeException();

    // SavedGridTile shows only media, not caption text -- assert on the
    // tile widget itself (mirrors DropGridTile/PopGridTile's own
    // "no caption on the tile" precedent).
    expect(find.byType(SavedGridTile), findsOneWidget);
  });

  // WYN-073: the "Club ของฉัน" shelf (WYN-015) is removed from
  // own-profile entirely, per `/05-profile.tsx`'s own explicit list of
  // changes -- it never rendered anywhere but own-profile in the first
  // place (see the old suite's "never shows on someone else's profile"
  // case), so this single test (still supplying a ClubRepository with
  // real joined clubs, to prove the removal is real and not just an
  // empty-list coincidence) replaces that whole group.
  testWidgets(
      'WYN-073: "Club ของฉัน" never renders on own-profile any more, even '
      'with a ClubRepository and joined clubs supplied', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ViewProfileScreen(
        profileRepository: ownProfileRepo,
        followRepository: ownFollowRepo,
        dropRepository: dropRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        userId: 'me',
        clubRepository: clubsJoinedRepo,
        clubPostRepository: clubPostRepo,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Club ของฉัน'), findsNothing);
    expect(find.text('ชมรมถ่ายภาพ'), findsNothing);
  });

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
