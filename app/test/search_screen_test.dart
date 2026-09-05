import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/search/presentation/search_screen.dart';
import 'package:wyn/features/search/presentation/widgets/discovery_view.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_discovery_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_follow_request_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  late RecordingProfileRepository profileRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingFollowRepository followRepo;
  late RecordingFollowRequestRepository followRequestRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingProfileRepository noMatchProfileRepo;
  late RecordingProfileRepository selfProfileRepo;
  late RecordingClubRepository clubRepo;
  late RecordingClubPostRepository clubPostRepo;
  late RecordingDiscoveryRepository discoveryRepo;

  const matchingProfile = Profile(
    id: 'u1',
    username: 'namfah',
    displayName: 'น้ำฝน',
  );

  final matchingDrop = Drop(
    id: 'd1',
    authorId: 'u1',
    authorUsername: 'namfah',
    imageUrl: 'https://example.supabase.co/drops/d1.jpg',
    caption: 'สวัสดี Namfah วันนี้อากาศดี',
    createdAt: DateTime.now(),
    likeCount: 0,
    commentCount: 0,
    likedByMe: false,
    savedByMe: false,
  );

  final matchingPop = Pop(
    id: 'p1',
    authorId: 'u1',
    authorUsername: 'namfah',
    videoUrl: 'https://example.supabase.co/pops/p1.mp4',
    caption: 'คลิป Namfah ดีมาก',
    durationSeconds: 20,
    viewCount: 0,
    createdAt: DateTime.now(),
    likeCount: 0,
    commentCount: 0,
    likedByMe: false,
    savedByMe: false,
  );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    // A fresh repository set per test -- avoids call-count assertions
    // leaking between tests, same discipline as every other test file in
    // this suite (see drop_comment_like_test.dart).
    profileRepo = RecordingProfileRepository(searchResults: [matchingProfile]);
    noMatchProfileRepo = RecordingProfileRepository(searchResults: []);
    selfProfileRepo = RecordingProfileRepository(
      searchResults: [
        const Profile(id: 'me', username: 'me', displayName: 'ตัวเอง'),
      ],
    );
    dropRepo = RecordingDropRepository(feedDrops: [matchingDrop]);
    popRepo = RecordingPopRepository(feedPops: [matchingPop]);
    followRepo = RecordingFollowRepository();
    followRequestRepo = RecordingFollowRequestRepository();
    savedRepo = RecordingSavedRepository();
    clubRepo = RecordingClubRepository();
    clubPostRepo = RecordingClubPostRepository();
    discoveryRepo = RecordingDiscoveryRepository();
  });

  Widget buildSearch({RecordingProfileRepository? profileRepository}) =>
      MaterialApp(
        home: SearchScreen(
          profileRepository: profileRepository ?? profileRepo,
          followRepository: followRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          clubRepository: clubRepo,
          clubPostRepository: clubPostRepo,
          followRequestRepository: followRequestRepo,
          discoveryRepository: discoveryRepo,
        ),
      );

  // WYN-040: an empty/short query now shows DiscoveryView (not the old
  // per-tab "พิมพ์..." prompt, and not the TabBar itself) -- see
  // .wyn/docs/design/wyn-040-discovery-page.md, "ทิศทางภาพรวม".
  testWidgets(
      'shows DiscoveryView (not results, an error, or the TabBar) '
      'before anything is typed', (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    expect(find.byType(DiscoveryView), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
    expect(profileRepo.searchProfilesCalls, 0);
  });

  // WYN-080 (Wynos V1.0.0 Beta2, item 9): typing alone never searches
  // anymore -- Founder didn't like results firing while still typing.
  // An explicit submit (the search icon, tapped here, or the keyboard's
  // own "search" action, covered by its own test below) is required.
  testWidgets(
      'typing alone (no submit) never fires a query, no matter how long '
      'or how much time passes -- keeps showing DiscoveryView',
      (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(profileRepo.searchProfilesCalls, 0);
    expect(find.byType(DiscoveryView), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets(
      'submitting fewer than 2 characters still does not fire a query, '
      'and keeps showing DiscoveryView', (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'n');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(profileRepo.searchProfilesCalls, 0);
    expect(find.byType(DiscoveryView), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets(
      'tapping the search icon submits the current text and fires the '
      'query exactly once', (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    expect(profileRepo.searchProfilesCalls, 0,
        reason: 'still just typing -- not submitted yet');

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(profileRepo.searchProfilesCalls, 1);
    expect(profileRepo.searchProfilesQueryArgs, ['namfah']);
  });

  testWidgets(
      "the keyboard's own search action (TextField.onSubmitted) submits "
      'the same way the search icon does', (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(profileRepo.searchProfilesCalls, 1);
    expect(profileRepo.searchProfilesQueryArgs, ['namfah']);
  });

  testWidgets(
      'editing the text again after a submitted search goes back to '
      'DiscoveryView (not stale results) until submitted again',
      (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.byType(DiscoveryView), findsNothing);
    expect(find.text('@namfah'), findsOneWidget);

    // Typing again without re-submitting -- back to Discovery, old
    // result no longer shown.
    await tester.enterText(find.byType(TextField), 'namfah2');
    await tester.pumpAndSettle();

    expect(find.byType(DiscoveryView), findsOneWidget);
    expect(find.text('@namfah'), findsNothing);
    expect(profileRepo.searchProfilesCalls, 1,
        reason: 'editing alone must not have fired a second query yet');
  });

  testWidgets(
      'WYN-102: the Pop tab is gone -- 3 tabs (User/โพสต์/Club), no '
      '"Pop" text anywhere, and the search placeholder no longer names '
      'it', (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    // Placeholder is visible from the start (Discovery state).
    expect(find.text('ค้นหา username, โพสต์, Club'), findsOneWidget);

    // The TabBar itself only renders once Discovery gives way to the
    // result tabs (see the screen's own `bottom: _showDiscovery ? null
    // : TabBar(...)`).
    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(Tab), findsNWidgets(3));
    expect(find.text('User'), findsOneWidget);
    expect(find.text('โพสต์'), findsOneWidget);
    expect(find.text('Club'), findsOneWidget);
    expect(find.text('Pop'), findsNothing);
  });

  testWidgets('finding a matching user opens ViewProfileScreen when tapped',
      (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    // The โพสต์ tab is also built (TabBarView keeps every tab's widget
    // mounted, not just the visible one) and searched with the same
    // shared query -- DropGridTile's Image.network fails to load in the
    // test env, same harmless/expected exception as every other test in
    // this suite that renders one. See .wyn/learning/PATTERNS.md.
    tester.takeException();

    expect(find.text('@namfah'), findsOneWidget);
    await tester.tap(find.text('@namfah'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });

  testWidgets(
      'finding a matching Drop (case-insensitive caption match) '
      'opens DropDetailScreen when tapped', (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    // Query is lowercase, the Drop's caption has "Namfah" capitalized --
    // proves the match is case-insensitive.
    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.tap(find.text('โพสต์'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(dropRepo.searchByCaptionQueryArgs, ['namfah']);
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets(
      'a query with no matches shows a tab-specific "not found" '
      'message, not an error or a stuck loading state', (tester) async {
    await tester.pumpWidget(buildSearch(profileRepository: noMatchProfileRepo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ไม่พบผู้ใช้สำหรับ "zzz"'), findsOneWidget);
  });

  testWidgets('clearing the query goes back to DiscoveryView immediately',
      (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('@namfah'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    expect(find.byType(DiscoveryView), findsOneWidget);
    expect(find.text('@namfah'), findsNothing);
  });

  // The User tab used to be the one "list of users" surface in the app
  // without a Follow button -- FollowListScreen and Discovery's
  // Suggested Users both already had it via the same shared
  // FollowActionButton.
  testWidgets(
      'a search result for someone else shows a Follow button, and '
      'tapping it follows without also opening their profile',
      (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ติดตาม'), findsOneWidget);

    await tester.tap(find.text('ติดตาม'));
    await tester.pumpAndSettle();

    expect(followRepo.toggleFollowCalls, 1);
    expect(find.byType(ViewProfileScreen), findsNothing,
        reason: 'tapping the Follow button must not also count as '
            "tapping the row and opening the profile it's on");
  });

  testWidgets(
      'searching yourself shows no Follow button on your own row -- '
      'searchProfiles does not exclude the caller the way Discovery/'
      "FollowListScreen's queries structurally do", (tester) async {
    await tester.pumpWidget(buildSearch(profileRepository: selfProfileRepo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'me');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('@me'), findsOneWidget);
    expect(find.text('ติดตาม'), findsNothing);
  });
}
