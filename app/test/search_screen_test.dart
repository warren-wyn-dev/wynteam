import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/home/presentation/pop_single_clip_screen.dart';
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

  testWidgets(
      'typing fewer than 2 characters does not fire a query, even after '
      'the debounce window passes, and keeps showing DiscoveryView',
      (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'n');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(profileRepo.searchProfilesCalls, 0);
    expect(find.byType(DiscoveryView), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets(
      'typing a second time before the first debounce timer fires cancels '
      'it, instead of both eventually firing and searching twice',
      (tester) async {
    // Deliberately timed so each timer's firing is observed via its own
    // separate tester.pump() call rather than one pump long enough to
    // cover both -- pumping past both deadlines in a single pump() only
    // triggers one rebuild at the end either way, which would make a
    // still-pending (uncancelled) first timer indistinguishable from a
    // properly cancelled one. Splitting the pumps is what actually
    // exercises Timer.cancel(). See .wyn/learning/PATTERNS.md.
    final field = find.byType(TextField);
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    // 'na' is a *valid* (>= 2 char) query on its own -- if its debounce
    // timer isn't cancelled, it will fire and search on its own, which
    // 'n' alone (too short to search) wouldn't have caught.
    await tester.enterText(field, 'na');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'namfah');

    // Crosses only 'na''s 400ms deadline (fires at 400ms from its own
    // creation, i.e. 500ms of total elapsed time) -- 'namfah''s timer
    // (created 100ms later) isn't due yet.
    await tester.pump(const Duration(milliseconds: 350));
    expect(profileRepo.searchProfilesCalls, 0,
        reason: '"na"\'s debounce timer should have been cancelled when '
            '"namfah" was typed, so it must not have fired here');

    // Now cross 'namfah''s deadline too.
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException();

    expect(profileRepo.searchProfilesCalls, 1);
    expect(profileRepo.searchProfilesQueryArgs, ['namfah']);
  });

  testWidgets('finding a matching user opens ViewProfileScreen when tapped',
      (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    // The Drop/Pop tabs are also built (TabBarView keeps every tab's
    // widget mounted, not just the visible one) and searched with the
    // same shared query -- DropGridTile's Image.network fails to load in
    // the test env, same harmless/expected exception as every other test
    // in this suite that renders one. See .wyn/learning/PATTERNS.md.
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
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drop'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(dropRepo.searchByCaptionQueryArgs, ['namfah']);
    await tester.tap(find.byType(Image).first);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropDetailScreen), findsOneWidget);
  });

  testWidgets('finding a matching Pop opens PopSingleClipScreen when tapped',
      (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    tester.takeException();

    await tester.tap(find.text('Pop'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(popRepo.searchByCaptionQueryArgs, ['namfah']);
    await tester.tap(find.byIcon(Icons.play_circle_fill));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(PopSingleClipScreen), findsOneWidget);
  });

  testWidgets(
      'a query with no matches shows a tab-specific "not found" '
      'message, not an error or a stuck loading state', (tester) async {
    await tester.pumpWidget(buildSearch(profileRepository: noMatchProfileRepo));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('ไม่พบผู้ใช้สำหรับ "zzz"'), findsOneWidget);
  });

  testWidgets(
      'clearing the query goes back to DiscoveryView immediately, '
      'without waiting for the debounce window', (tester) async {
    await tester.pumpWidget(buildSearch());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'namfah');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    tester.takeException();
    expect(find.text('@namfah'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    // Deliberately pump for less than the debounce window -- clearing
    // must not wait it out.
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(DiscoveryView), findsOneWidget);
    expect(find.text('@namfah'), findsNothing);
  });
}
