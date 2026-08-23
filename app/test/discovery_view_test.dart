import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/club/data/club.dart';
import 'package:wyn/features/club/presentation/club_page.dart';
import 'package:wyn/features/hashtag/presentation/hashtag_feed_screen.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
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
  late RecordingClubRepository clubRepo;
  late RecordingClubPostRepository clubPostRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingFollowRepository followRepo;
  late RecordingFollowRequestRepository followRequestRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingDiscoveryRepository discoveryRepo;

  final trendingDrop = HomeFeedItem(
    id: 'd1',
    contentType: HomeContentType.drop,
    authorId: 'u1',
    authorUsername: 'namfah',
    createdAt: DateTime.now(),
    caption: 'สวัสดี #wyn',
    imageUrl: 'https://example.supabase.co/drops/d1.jpg',
    likeCount: 10,
    commentCount: 2,
    likedByMe: false,
    savedByMe: false,
  );

  // displayName set on both -- without it, Profile.nameOrUsername falls
  // back to "@username" too, which would make the row's name line and
  // @username line render identical text and break `find.text('@...')`
  // (ambiguous: 2 matches) below.
  const risingProfile =
      Profile(id: 'u2', username: 'rising_user', displayName: 'Rising User');
  const suggestedProfile = Profile(
      id: 'u3', username: 'suggested_user', displayName: 'Suggested User');

  final popularClub = Club(
    id: 'c1',
    name: 'WYN Club',
    privacy: ClubPrivacy.public,
    ownerId: 'owner1',
    createdAt: DateTime.now(),
    memberCount: 5,
  );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    // A fresh repository set per test (same discipline as
    // search_screen_test.dart) -- note discoveryRepo's fields are
    // *mutated* per test below rather than constructing a new instance
    // inside a testWidgets body: see RecordingDiscoveryRepository's own
    // doc comment for why (a `SupabaseClient` built directly inside a
    // testWidgets body, rather than here in `setUp`, trips
    // flutter_test's pending-timer invariant).
    clubRepo = RecordingClubRepository(discoverableClubs: [popularClub]);
    clubPostRepo = RecordingClubPostRepository();
    profileRepo = RecordingProfileRepository();
    followRepo = RecordingFollowRepository();
    followRequestRepo = RecordingFollowRequestRepository();
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
    discoveryRepo = RecordingDiscoveryRepository();
  });

  Widget buildDiscovery() {
    return MaterialApp(
      home: Scaffold(
        body: DiscoveryView(
          discoveryRepository: discoveryRepo,
          clubRepository: clubRepo,
          clubPostRepository: clubPostRepo,
          profileRepository: profileRepo,
          followRepository: followRepo,
          followRequestRepository: followRequestRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
        ),
      ),
    );
  }

  // All 5 sections stacked in one ListView easily exceed the default
  // 800x600 test viewport -- widen it (mirrors
  // home_feed_screen_test.dart's own tester.view.physicalSize pattern)
  // so every section is actually mounted/findable without needing to
  // scroll to it first.
  Future<void> pumpDiscovery(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildDiscovery());
    await tester.pumpAndSettle();
  }

  testWidgets('renders all 5 section headers, and each section\'s data',
      (tester) async {
    discoveryRepo
      ..trendingNowItems = [trendingDrop]
      ..trendingHashtags = const ['wyn']
      ..risingProfiles = const [risingProfile]
      ..suggestedUsers = const [suggestedProfile];

    await pumpDiscovery(tester);
    tester.takeException(); // Image.network fails to load in the test env.

    expect(find.text('กำลังนิยม'), findsOneWidget);
    expect(find.text('แฮชแท็กกำลังนิยม'), findsOneWidget);
    expect(find.text('กำลังเติบโต'), findsOneWidget);
    expect(find.text('แนะนำให้ติดตาม'), findsOneWidget);
    expect(find.text('Club แนะนำ'), findsOneWidget);

    expect(find.text('#wyn'), findsOneWidget);
    expect(find.text('@rising_user'), findsOneWidget);
    expect(find.text('@suggested_user'), findsOneWidget);
    expect(find.text('WYN Club'), findsOneWidget);
  });

  testWidgets(
      'an empty section shows its own "ยังไม่มี...ตอนนี้" message, '
      'not a blank gap', (tester) async {
    await pumpDiscovery(tester);

    expect(find.text('ยังไม่มีบัญชีที่กำลังเติบโตตอนนี้'), findsOneWidget);
    expect(find.text('ยังไม่มีบัญชีแนะนำให้ติดตามตอนนี้'), findsOneWidget);
  });

  testWidgets(
      'a section whose fetch throws fails-safe (shrinks) without blocking '
      'the other sections -- mirrors ClubSection\'s fail-safe pattern '
      '(WYN-017)', (tester) async {
    discoveryRepo
      ..trendingHashtags = const ['stillworks']
      ..risingProfilesError = Exception('boom');

    await pumpDiscovery(tester);

    // Rising's own empty-state text must NOT appear (an error is not the
    // same as "genuinely no data") -- the section just shrinks away.
    expect(find.text('ยังไม่มีบัญชีที่กำลังเติบโตตอนนี้'), findsNothing);
    // The other sections are unaffected.
    expect(find.text('#stillworks'), findsOneWidget);
  });

  testWidgets('tapping a hashtag chip opens HashtagFeedScreen', (tester) async {
    discoveryRepo.trendingHashtags = const ['wyn'];
    await pumpDiscovery(tester);

    await tester.tap(find.text('#wyn'));
    await tester.pumpAndSettle();

    expect(find.byType(HashtagFeedScreen), findsOneWidget);
  });

  testWidgets(
      'tapping a Suggested Users row (outside the Follow button) opens '
      'ViewProfileScreen', (tester) async {
    discoveryRepo.suggestedUsers = const [suggestedProfile];
    await pumpDiscovery(tester);

    await tester.tap(find.text('@suggested_user'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });

  testWidgets(
      'tapping the Follow button in a Suggested Users row toggles Follow '
      'without navigating away', (tester) async {
    discoveryRepo.suggestedUsers = const [suggestedProfile];
    await pumpDiscovery(tester);

    expect(find.text('ติดตาม'), findsOneWidget);
    await tester.tap(find.text('ติดตาม'));
    await tester.pumpAndSettle();

    expect(followRepo.toggleFollowCalls, 1);
    expect(find.byType(ViewProfileScreen), findsNothing);
  });

  testWidgets('tapping a Suggested Clubs card opens ClubPage', (tester) async {
    await pumpDiscovery(tester);

    await tester.tap(find.text('WYN Club'));
    await tester.pumpAndSettle();

    expect(find.byType(ClubPage), findsOneWidget);
  });
}
