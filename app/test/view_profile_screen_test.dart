import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/design/wyn_spacing.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/follow/presentation/follow_list_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/home/presentation/widgets/verified_badge.dart';
import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/profile/presentation/widgets/avatar_circle.dart';
import 'package:wyn/features/profile/presentation/widgets/profile_skeleton.dart';

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

  // Beta4 §14 -- built in setUpAll, not per-test: every Recording*
  // repository in this project is, because constructing one inside a
  // test body leaves a GoTrue auto-refresh Timer pending past the
  // widget tree's disposal and trips flutter_test's `!timersPending`
  // invariant. See .wyn/learning/PATTERNS.md.
  late RecordingProfileRepository longTextProfileRepo;
  late RecordingFollowRepository largeCountFollowRepo;

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

    longTextProfileRepo = RecordingProfileRepository(
      profile: const Profile(
        id: 'me',
        username: 'a_rather_long_username_here',
        displayName: 'ชื่อที่แสดงยาวมากจนน่าจะล้นออกนอกจอถ้าไม่ได้ตัดคำ',
        bio: 'ไบโอที่ยาวพอสมควร เขียนต่อกันหลายบรรทัดเพื่อดูว่า layout '
            'ยังอยู่ดีไหมเมื่อเจอข้อความจริงที่ไม่ได้สั้นแบบ fixture',
      ),
    );
    largeCountFollowRepo =
        RecordingFollowRepository(followerCount: 123456, followingCount: 98765);

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

  group('Beta4 §2 -- account switcher on the display name', () {
    testWidgets(
        'your own display name is a button labelled as the account '
        'switcher, with a chevron', (tester) async {
      await tester.pumpWidget(buildProfile(
        profileRepository: ownProfileRepo,
        followRepository: ownFollowRepo,
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      final switcher = find.byKey(const Key('profile_account_switcher'));
      expect(switcher, findsOneWidget);

      // The Founder's sketch: "ชื่อที่แสดง ⌄".
      expect(
        find.descendant(of: switcher, matching: find.text('ตัวฉันเอง')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: switcher, matching: find.byIcon(Icons.keyboard_arrow_down)),
        findsOneWidget,
      );
    });

    testWidgets(
        'the whole name+chevron is one tap target, at least '
        'touchTargetMin tall -- not just the 22px glyph', (tester) async {
      await tester.pumpWidget(buildProfile(
        profileRepository: ownProfileRepo,
        followRepository: ownFollowRepo,
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(const Key('profile_account_switcher')));
      expect(size.height, greaterThanOrEqualTo(WynSpacing.touchTargetMin));
      // Wide enough to cover the name, not just the arrow.
      expect(size.width,
          greaterThan(tester.getSize(find.text('ตัวฉันเอง')).width));
    });

    testWidgets(
        'Beta4 §2: the semantics say what it does, not just the name -- '
        '"ต้องสื่อชัดว่าใช้เปลี่ยนบัญชี"', (tester) async {
      await tester.pumpWidget(buildProfile(
        profileRepository: ownProfileRepo,
        followRepository: ownFollowRepo,
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      final semantics = tester.getSemantics(
        find.byKey(const Key('profile_account_switcher')),
      );
      expect(semantics.label, contains('สลับบัญชี'));
      expect(
        semantics.flagsCollection.isButton,
        isTrue,
        reason: 'a screen-reader user hearing only a name would have no '
            'way to know it is a control at all',
      );
    });

    testWidgets(
        "Beta4 §2: someone else's profile has no account switcher -- their "
        'name is plain text', (tester) async {
      await tester.pumpWidget(buildProfile(
        profileRepository: otherProfileRepo,
        followRepository: otherFollowRepo,
        userId: 'someone-else',
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_account_switcher')), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
      // The name is still shown -- it just is not a control.
      expect(find.text('น้ำฝน'), findsOneWidget);
    });
  });

  // Beta4 §14 (Responsive). The narrowest screen WYNOS supports; the
  // identity column is at its most cramped here, and the header now
  // holds more than it did (name, handle, bio, stats, action all in one
  // column beside the avatar).
  group('Beta4 §14 -- profile header at small-mobile width', () {
    testWidgets('no overflow at 320x568, with a long display name and bio',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildProfile(
        profileRepository: longTextProfileRepo,
        followRepository: largeCountFollowRepo,
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      // A RenderFlex overflow paints as the yellow/black stripe and
      // reports through the error framework -- takeException() would
      // return it. Nothing else in this tree throws.
      expect(tester.takeException(), isNull);

      // Both stats and the action are still on screen and inside it.
      expect(find.text('กำลังติดตาม'), findsOneWidget);
      expect(find.text('ผู้ติดตาม'), findsOneWidget);
      final button =
          tester.getRect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'));
      expect(button.left, greaterThanOrEqualTo(0));
      expect(button.right, lessThanOrEqualTo(320));
    });
  });

  testWidgets(
      'Beta4 §1: shows exactly two stats -- Following and Followers -- '
      'and no post count', (tester) async {
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

    // Beta4 §1: "แสดงเฉพาะ Following / Followers. ไม่เพิ่ม: จำนวนโพสต์".
    // The Drop count (6, per this fixture) is no longer fetched or
    // shown, so "โพสต์" now appears exactly once on this screen -- as
    // the tab label, not as a third stat.
    expect(find.text('6'), findsNothing);
    expect(find.text('โพสต์'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(3));
  });

  testWidgets(
      'Beta4 §1: avatar on the left, and the whole identity column '
      '(name, username, stats, action) to its right, in that order',
      (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    final avatarRect = tester.getRect(find.byType(AvatarCircle));
    final nameRect = tester.getRect(find.text('ตัวฉันเอง'));
    final usernameTop = tester.getTopLeft(find.text('@me_user')).dy;
    final statsTop = tester.getTopLeft(find.text('ผู้ติดตาม')).dy;
    final buttonTop =
        tester.getTopLeft(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์')).dy;

    // The name sits *beside* the avatar, not below it -- WYN-095's
    // Mockup A had the stats there and the name underneath, which split
    // the identity across two zones (see the layout comment in
    // view_profile_screen.dart).
    expect(nameRect.left, greaterThan(avatarRect.right));
    expect(nameRect.center.dy, greaterThan(avatarRect.top));

    // Reading order down the right-hand column: name → handle → bio →
    // stats → action.
    expect(usernameTop, greaterThan(nameRect.top));
    expect(statsTop, greaterThan(usernameTop));
    expect(buttonTop, greaterThan(statsTop));

    // Everything in that column shares one left edge: the name, the
    // handle, and the action button all start where the column starts.
    //
    // The stats row is measured by its extent, not its left edge --
    // Beta4 §14 made the two stats Expanded so they share the column
    // instead of overflowing it on a small screen, which centres each
    // one's *text* inside its own half. So the meaningful assertion is
    // that the row spans the column, which the two stats' combined
    // horizontal reach shows.
    final columnLeft = tester.getTopLeft(find.text('@me_user')).dx;
    expect((nameRect.left - columnLeft).abs(), lessThan(2));

    final buttonRect =
        tester.getRect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'));
    expect((buttonRect.left - columnLeft).abs(), lessThan(2));

    final followingX = tester.getCenter(find.text('กำลังติดตาม')).dx;
    final followersX = tester.getCenter(find.text('ผู้ติดตาม')).dx;
    expect(followingX, greaterThan(columnLeft));
    expect(followersX, lessThan(buttonRect.right));
  });

  testWidgets(
      'Beta4 §1: Following is listed before Followers, per the '
      'Founder\'s own layout sketch', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    final followingX = tester.getCenter(find.text('กำลังติดตาม')).dx;
    final followersX = tester.getCenter(find.text('ผู้ติดตาม')).dx;
    expect(followingX, lessThan(followersX));
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
      'Beta4 §1: the Edit Profile button spans the identity column, '
      'now that it is the only action there', (tester) async {
    await tester.pumpWidget(buildProfile(
      profileRepository: ownProfileRepo,
      followRepository: ownFollowRepo,
      userId: 'me',
    ));
    await tester.pumpAndSettle();

    final buttonRect =
        tester.getRect(find.widgetWithText(OutlinedButton, 'แก้ไขโปรไฟล์'));
    final usernameLeft = tester.getTopLeft(find.text('@me_user')).dx;

    // It used to be a natural-width pill sharing its row with two
    // unlabelled icon buttons (Saved and Draft). Those moved out
    // entirely (§4/§5), so the one remaining action fills the column
    // instead of floating at its left edge.
    expect((buttonRect.left - usernameLeft).abs(), lessThan(2));
    expect(buttonRect.width, greaterThan(300));
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
      'Beta4 §1/§4/§5: own profile shows Edit Profile and 3 public tabs, '
      'and no longer carries Saved or Draft',
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

    // Beta4 §4: Saved is in Home's ☰ menu ("บันทึกไว้", see
    // side_menu_test.dart). Beta4 §5: Draft is in the post composer
    // (see create_drop_screen_test.dart). Neither belongs on Profile,
    // and neither of the two unlabelled icon buttons that used to open
    // them is here any more.
    expect(find.byKey(const Key('profile_saved_button')), findsNothing);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
    expect(find.byIcon(Icons.edit_note_outlined), findsNothing);

    // 05-profile.tsx cuts Replies/Media -- 3 tabs. "โพสต์" appears once
    // now (the tab); the StatsRow no longer has a third stat saying it.
    expect(find.text('โพสต์'), findsOneWidget);
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
    expect(find.text('โพสต์'), findsOneWidget);
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

  // Beta4 §4: the "tapping the Saved icon opens BookmarksScreen" test
  // that lived here is gone with the icon it exercised. Saved did not
  // change -- BookmarksScreen is the same screen, reached from Home's ☰
  // menu, and side_menu_test.dart's own "บันทึกไว้" test covers that
  // path (it already did before Beta4, since SideMenu has offered the
  // row since WYN-100).

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

  // Founder feedback: the official account's checkmark (VerifiedBadge,
  // already rendered on Home/Suggested Follows via
  // HomeFeedItem.authorIsVerified/Profile.isVerified) never showed here
  // at all -- ProfileRepository.fetchProfile's own query didn't select
  // `is_verified`, so this screen always saw isVerified: false regardless
  // of the real column, on top of never rendering VerifiedBadge in either
  // header branch even if it had.
  group('VerifiedBadge on the profile header', () {
    late RecordingProfileRepository verifiedOwnProfileRepo;
    late RecordingProfileRepository verifiedOtherProfileRepo;

    setUpAll(() {
      verifiedOwnProfileRepo = RecordingProfileRepository(
        profile: const Profile(
          id: 'me',
          username: 'me_user',
          displayName: 'ตัวฉันเอง',
          isVerified: true,
        ),
      );
      verifiedOtherProfileRepo = RecordingProfileRepository(
        profile: const Profile(
          id: 'someone-else',
          username: 'namfah',
          displayName: 'น้ำฝน',
          isVerified: true,
        ),
      );
    });

    testWidgets('shows on your own profile, next to the account switcher '
        'name', (tester) async {
      await tester.pumpWidget(buildProfile(
        profileRepository: verifiedOwnProfileRepo,
        followRepository: ownFollowRepo,
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VerifiedBadge), findsOneWidget);
    });

    testWidgets('shows on someone else\'s profile too', (tester) async {
      await tester.pumpWidget(buildProfile(
        profileRepository: verifiedOtherProfileRepo,
        followRepository: otherFollowRepo,
        userId: 'someone-else',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VerifiedBadge), findsOneWidget);
    });

    testWidgets('does not show for an unverified profile', (tester) async {
      await tester.pumpWidget(buildProfile(
        profileRepository: ownProfileRepo,
        followRepository: ownFollowRepo,
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(VerifiedBadge), findsNothing);
    });
  });
}
