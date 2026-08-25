import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/follow/presentation/follow_list_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
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
  late RecordingClubRepository noClubsRepo;

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
    noClubsRepo = RecordingClubRepository(myClubs: []);

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
      'own profile shows Edit/logout, Saved/Draft icons, 5 public tabs, and '
      'no Follow button (WYN-013, WYN-071)',
      (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'ติดตาม'), findsNothing);
    // WYN-071: Saved/Draft are icons next to "แก้ไขโปรไฟล์" now, not tabs.
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
    expect(find.byIcon(Icons.edit_note_outlined), findsOneWidget);
    expect(find.text('Posts'), findsOneWidget);
    expect(find.text('ReDrops'), findsOneWidget);
    expect(find.text('Replies'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Likes'), findsOneWidget);
    // Pop is hidden from Profile for WYNOS V1.0.0 Beta -- requirement 3.
    expect(find.text('Pop'), findsNothing);
    expect(find.text('บันทึก'), findsNothing);
    expect(find.text('ร่าง'), findsNothing);
    expect(find.byType(Tab), findsNWidgets(5));
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
    // visible without switching tabs.
    expect(find.byIcon(Icons.favorite), findsOneWidget);
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

    await tester.tap(find.text('ReDrops'));
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

  group('"Club ของฉัน" section (WYN-015)', () {
    testWidgets('shows joined clubs on your own profile when a ClubRepository is supplied',
        (tester) async {
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

      expect(find.text('Club ของฉัน'), findsOneWidget);
      expect(find.text('ชมรมถ่ายภาพ'), findsOneWidget);
    });

    // Design Rule: unlike Home's CLUB section, this one shows nothing at
    // all (not even the label) when the list is empty -- Profile isn't
    // the app's entry point for encouraging Club discovery.
    testWidgets('shows nothing at all when you have no joined clubs', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewProfileScreen(
          profileRepository: ownProfileRepo,
          followRepository: ownFollowRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'me',
          clubRepository: noClubsRepo,
          clubPostRepository: clubPostRepo,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Club ของฉัน'), findsNothing);
    });

    testWidgets('never shows on someone else\'s profile, even with clubs and a '
        'ClubRepository supplied', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: ViewProfileScreen(
          profileRepository: otherProfileRepo,
          followRepository: otherFollowRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'someone-else',
          clubRepository: clubsJoinedRepo,
          clubPostRepository: clubPostRepo,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Club ของฉัน'), findsNothing);
    });

    testWidgets('shows nothing when no ClubRepository is supplied at all '
        '(every non-RootShell call site)', (tester) async {
      await tester.pumpWidget(buildProfile(
        profileRepository: ownProfileRepo,
        followRepository: ownFollowRepo,
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      expect(find.text('Club ของฉัน'), findsNothing);
    });
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
