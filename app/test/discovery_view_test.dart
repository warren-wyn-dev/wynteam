import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/hashtag/presentation/hashtag_feed_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/search/data/discovery_ranking.dart';
import 'package:wyn/features/search/presentation/top_100_screen.dart';
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

/// DiscoveryView, restyled to `03-search.tsx`'s 2-section layout
/// (2026-08-29, Founder-approved re-brand -- see
/// .wyn/company/DECISIONS.md): "แฮชแท็กกำลังนิยม" (Top 100 preview) +
/// "แนะนำให้ติดตาม" only. The old Trending Now/Rising/Suggested Clubs
/// sections were removed from this screen (not deleted from the data
/// layer -- see discovery_view.dart's own doc comment), so this file no
/// longer covers them.
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

  // displayName set -- without it, Profile.nameOrUsername falls back to
  // "@username" too, which would make the row's name line and @username
  // line render identical text and break `find.text('@...')` below
  // (ambiguous: 2 matches).
  const suggestedProfile = Profile(
      id: 'u3', username: 'suggested_user', displayName: 'Suggested User');

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  setUp(() {
    clubRepo = RecordingClubRepository();
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

  Future<void> pumpDiscovery(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildDiscovery());
    await tester.pumpAndSettle();
  }

  testWidgets('renders both section labels, and each section\'s data',
      (tester) async {
    discoveryRepo
      ..trendingHashtags = const [RankedHashtag(tag: 'wyn', postCount: 5)]
      ..suggestedUsers = const [suggestedProfile];

    await pumpDiscovery(tester);

    expect(find.text('แฮชแท็กกำลังนิยม'), findsOneWidget);
    expect(find.text('แนะนำให้ติดตาม'), findsOneWidget);

    expect(find.text('#wyn'), findsOneWidget);
    expect(find.text('5 โพสต์ · กำลังนิยมใน ไทย'), findsOneWidget);
    expect(find.text('@suggested_user'), findsOneWidget);
  });

  testWidgets(
      'an empty section shows its own "ยังไม่มี...ตอนนี้" message, '
      'not a blank gap', (tester) async {
    await pumpDiscovery(tester);

    expect(find.text('ยังไม่มีแฮชแท็กกำลังนิยมตอนนี้'), findsOneWidget);
    expect(find.text('ยังไม่มีบัญชีแนะนำให้ติดตามตอนนี้'), findsOneWidget);
  });

  testWidgets('tapping a ranked hashtag row opens HashtagFeedScreen',
      (tester) async {
    discoveryRepo.trendingHashtags = const [
      RankedHashtag(tag: 'wyn', postCount: 5),
    ];
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

  testWidgets('"ดูอันดับทั้งหมด (Top 100)" does not appear while the '
      'ranked list is empty', (tester) async {
    await pumpDiscovery(tester);

    expect(find.text('ดูอันดับทั้งหมด (Top 100)'), findsNothing);
  });

  testWidgets('tapping "ดูอันดับทั้งหมด (Top 100)" opens Top100Screen',
      (tester) async {
    discoveryRepo.trendingHashtags = const [
      RankedHashtag(tag: 'wyn', postCount: 5),
    ];
    await pumpDiscovery(tester);

    expect(find.text('ดูอันดับทั้งหมด (Top 100)'), findsOneWidget);
    await tester.tap(find.text('ดูอันดับทั้งหมด (Top 100)'));
    await tester.pumpAndSettle();

    expect(find.byType(Top100Screen), findsOneWidget);
  });
}
