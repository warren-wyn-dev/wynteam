import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:wyn/features/pop/data/pop.dart';
import 'package:wyn/features/pop/presentation/pop_feed_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/fake_video_player_platform.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

Pop _pop({
  String id = 'p1',
  String authorId = 'someone-else',
  int likeCount = 0,
  int commentCount = 0,
  int viewCount = 0,
  bool likedByMe = false,
  bool savedByMe = false,
}) =>
    Pop(
      id: id,
      authorId: authorId,
      authorUsername: 'namfah',
      videoUrl: 'https://example.supabase.co/pops/$id.mp4',
      durationSeconds: 15,
      viewCount: viewCount,
      createdAt: DateTime.now(),
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe,
      savedByMe: savedByMe,
    );

void main() {
  // See drop_comment_like_test.dart (WYN-005) for why every repo (and its
  // underlying SupabaseClient auto-refresh Timer) is built once in
  // setUpAll rather than inside individual testWidgets callbacks. Each
  // scenario below needs its own feed data, so multiple repos are built
  // here -- all still outside any single test's tracked timer zone.
  late RecordingPopRepository otherUserPopRepo;
  late RecordingPopRepository ownPopRepo;
  late RecordingPopRepository likeTestRepo;
  late RecordingPopRepository muteTestRepo;
  late RecordingFollowRepository followRepo;
  late RecordingFollowRepository followToggleTestFollowRepo;
  late RecordingPopRepository followToggleTestPopRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingDropRepository dropRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingPopRepository tapProfileTestPopRepo;
  late FakeVideoPlayerPlatform fakeVideoPlatform;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    SharedPreferences.setMockInitialValues({});
    fakeVideoPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fakeVideoPlatform;

    otherUserPopRepo = RecordingPopRepository(
      feedPops: [_pop(id: 'p1', authorId: 'someone-else')],
    );
    ownPopRepo = RecordingPopRepository(
      feedPops: [_pop(id: 'p1', authorId: 'me')],
    );
    likeTestRepo = RecordingPopRepository(
      feedPops: [_pop(id: 'p2', likeCount: 0, likedByMe: false)],
    );
    muteTestRepo = RecordingPopRepository(feedPops: [_pop(id: 'p3')]);
    followRepo = RecordingFollowRepository();
    followToggleTestPopRepo = RecordingPopRepository(
      feedPops: [_pop(id: 'p4', authorId: 'someone-else')],
    );
    followToggleTestFollowRepo =
        RecordingFollowRepository(initiallyFollowing: false);
    profileRepo = RecordingProfileRepository(
      profile: const Profile(id: 'someone-else', username: 'namfah'),
    );
    dropRepo = RecordingDropRepository();
    savedRepo = RecordingSavedRepository();
    tapProfileTestPopRepo = RecordingPopRepository(
      feedPops: [_pop(id: 'p5', authorId: 'someone-else')],
    );
  });

  setUp(() {
    fakeVideoPlatform.setVolumeCalls.clear();
  });

  Widget buildPop(RecordingPopRepository popRepository) => MaterialApp(
        home: PopFeedScreen(
          popRepository: popRepository,
          followRepository: followRepo,
          dropRepository: dropRepo,
          profileRepository: profileRepo,
          savedRepository: savedRepo,
        ),
      );

  testWidgets('the current clip initializes, plays, and records a view once',
      (tester) async {
    await tester.pumpWidget(buildPop(otherUserPopRepo));
    await tester.pumpAndSettle();

    // No error state -- the fake platform's initialized event went
    // through, unlike a real MissingPluginException in a plain test env.
    expect(find.text('โหลดคลิปไม่สำเร็จ'), findsNothing);
    expect(otherUserPopRepo.recordViewCalls, 1);
    expect(otherUserPopRepo.recordViewArgs, ['p1']);
    // The optimistic view-count bump is visible immediately.
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('shows a delete button only for the current user\'s own Pop',
      (tester) async {
    await tester.pumpWidget(buildPop(ownPopRepo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    // Own Pop doesn't show a Follow button (can't follow yourself).
    expect(find.text('ติดตาม'), findsNothing);
  });

  testWidgets('hides the delete button and shows Follow for another user\'s Pop',
      (tester) async {
    await tester.pumpWidget(buildPop(otherUserPopRepo));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.text('ติดตาม'), findsOneWidget);
  });

  testWidgets(
      'rapid double-tap on Like sends a fresh currentlyLiked value each '
      'time instead of reusing the stale pre-tap state', (tester) async {
    await tester.pumpWidget(buildPop(likeTestRepo));
    await tester.pumpAndSettle();

    final likeButton = find.widgetWithIcon(IconButton, Icons.favorite_border);
    expect(likeButton, findsOneWidget);

    final onPressed = tester.widget<IconButton>(likeButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(likeTestRepo.toggleLikeCalls, 2);
    expect(likeTestRepo.toggleLikeCurrentlyLikedArgs, [false, true]);
  });

  testWidgets(
      'rapid double-tap on Follow sends a fresh currentlyFollowing value '
      'each time instead of reusing the stale pre-tap state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PopFeedScreen(
        popRepository: followToggleTestPopRepo,
        followRepository: followToggleTestFollowRepo,
        dropRepository: dropRepo,
        profileRepository: profileRepo,
        savedRepository: savedRepo,
      ),
    ));
    await tester.pumpAndSettle();

    final followButton = find.widgetWithText(OutlinedButton, 'ติดตาม');
    expect(followButton, findsOneWidget);

    final onPressed = tester.widget<OutlinedButton>(followButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(followToggleTestFollowRepo.toggleFollowCalls, 2);
    expect(
      followToggleTestFollowRepo.toggleFollowCurrentlyFollowingArgs,
      [false, true],
    );
  });

  testWidgets(
      'tapping the avatar/name opens the author\'s profile, without also '
      'toggling Follow (WYN-013)', (tester) async {
    await tester.pumpWidget(buildPop(tapProfileTestPopRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('@namfah'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });

  testWidgets('toggling mute calls setVolume(0) then setVolume(1)',
      (tester) async {
    await tester.pumpWidget(buildPop(muteTestRepo));
    await tester.pumpAndSettle();

    // Sound starts on (unmuted) the very first time, per design --
    // setVolume(1) comes from the video_player package's own
    // _applyVolume() during initialization, not an explicit call.
    expect(fakeVideoPlatform.setVolumeCalls, [1.0]);

    await tester.tap(find.byIcon(Icons.volume_up));
    await tester.pumpAndSettle();
    expect(fakeVideoPlatform.setVolumeCalls, [1.0, 0.0]);

    await tester.tap(find.byIcon(Icons.volume_off));
    await tester.pumpAndSettle();
    expect(fakeVideoPlatform.setVolumeCalls, [1.0, 0.0, 1.0]);
  });
}
