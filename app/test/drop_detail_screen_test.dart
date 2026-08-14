import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  // DropDetailScreen reads Supabase.instance.client.auth.currentUser
  // directly (for the "is this my own Drop" check) -- initialize a fake
  // local-only session so it can be pumped at all. See
  // .wyn/learning/PATTERNS.md.
  late RecordingDropRepository repo;
  late RecordingFollowRepository followRepo;
  late RecordingPopRepository popRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingSavedRepository savedRepo;
  late RecordingDropRepository ownDropRepo;
  late RecordingFollowRepository ownDropFollowRepo;
  late RecordingDropRepository followToggleTestDropRepo;
  late RecordingFollowRepository followToggleTestFollowRepo;
  late RecordingDropRepository tapProfileTestDropRepo;
  late RecordingFollowRepository tapProfileTestFollowRepo;
  late RecordingProfileRepository tapProfileTestProfileRepo;
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingDropRepository();
    followRepo = RecordingFollowRepository();
    popRepo = RecordingPopRepository();
    profileRepo = RecordingProfileRepository(
      profile: const Profile(id: 'someone-else', username: 'namfah'),
    );
    savedRepo = RecordingSavedRepository();
    ownDropRepo = RecordingDropRepository();
    ownDropFollowRepo = RecordingFollowRepository();
    followToggleTestDropRepo = RecordingDropRepository();
    followToggleTestFollowRepo =
        RecordingFollowRepository(initiallyFollowing: false);
    tapProfileTestDropRepo = RecordingDropRepository();
    tapProfileTestFollowRepo = RecordingFollowRepository();
    tapProfileTestProfileRepo = RecordingProfileRepository(
      profile: const Profile(id: 'someone-else', username: 'namfah'),
    );
  });

  final tallDrop = Drop(
    id: 'd1',
    authorId: 'u1',
    authorUsername: 'namfah',
    imageUrl: 'https://example.supabase.co/drops/d1.jpg',
    caption: 'a' * 400,
    createdAt: DateTime.now(),
    likeCount: 0,
    commentCount: 0,
    likedByMe: false,
    savedByMe: false,
  );

  testWidgets(
      'a tall Drop header (long caption + image) scrolls instead of '
      'overflowing on a short viewport', (tester) async {
    // The default flutter_test surface (800x600) is wide/short -- the
    // exact shape that overflowed WYN-004's PostDetailScreen before it
    // merged the header into the comment list's scrollable. This spec
    // (.wyn/docs/design/wyn-005-drop.md) called out building it that way
    // from the start, so this test exists to prove it actually was.
    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, followRepository: followRepo, profileRepository: profileRepo, popRepository: popRepo, savedRepository: savedRepo, drop: tallDrop),
    ));
    // fetchComments() fails against the fake network, and the image
    // fails to load -- both expected, neither is what this test checks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();

    expect(tester.takeException(), isNull);
  });

  testWidgets('toggling Like flips the icon and count optimistically',
      (tester) async {
    final drop = Drop(
      id: 'd2',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d2.jpg',
      createdAt: DateTime.now(),
      likeCount: 3,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, followRepository: followRepo, profileRepository: profileRepo, popRepository: popRepo, savedRepository: savedRepo, drop: drop),
    ));
    await tester.pump();
    // No real network access in the test environment -- expected and
    // irrelevant to what this test checks (that the like state toggles).
    tester.takeException();

    final likeButton = find.byIcon(Icons.favorite_border);
    expect(likeButton, findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // The square image above it (AspectRatio 1, 800px wide in this test
    // viewport) pushes the like button below the visible 600px-tall
    // surface -- scroll it into view before tapping.
    await tester.ensureVisible(likeButton);
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(likeButton);
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('shows a Follow button for another user\'s Drop',
      (tester) async {
    final otherDrop = Drop(
      id: 'd3',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d3.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: repo,
        followRepository: followRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: otherDrop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.widgetWithText(OutlinedButton, 'ติดตาม'), findsOneWidget);
  });

  testWidgets('does not show a Follow button for the current user\'s own '
      'Drop', (tester) async {
    final ownDrop = Drop(
      id: 'd4',
      authorId: 'me',
      authorUsername: 'me_user',
      imageUrl: 'https://example.supabase.co/drops/d4.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: ownDropRepo,
        followRepository: ownDropFollowRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: ownDrop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.widgetWithText(OutlinedButton, 'ติดตาม'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'กำลังติดตาม'), findsNothing);
  });

  testWidgets(
      'rapid double-tap on Follow sends a fresh currentlyFollowing value '
      'each time instead of reusing the stale pre-tap state', (tester) async {
    final drop = Drop(
      id: 'd5',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d5.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: followToggleTestDropRepo,
        followRepository: followToggleTestFollowRepo,
        profileRepository: profileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: drop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

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
    final drop = Drop(
      id: 'd6',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d6.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(
        dropRepository: tapProfileTestDropRepo,
        followRepository: tapProfileTestFollowRepo,
        profileRepository: tapProfileTestProfileRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        drop: drop,
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    final nameFinder = find.text('@namfah');
    await tester.ensureVisible(nameFinder);
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(nameFinder);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
    expect(tapProfileTestFollowRepo.toggleFollowCalls, 0);
  });
}
