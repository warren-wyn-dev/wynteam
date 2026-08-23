import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/follow/presentation/follow_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  late RecordingFollowRepository followersRepo;
  late RecordingFollowRepository followingRepo;
  late RecordingFollowRepository emptyFollowersRepo;
  late RecordingFollowRepository emptyFollowingRepo;
  late RecordingProfileRepository profileRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    followersRepo = RecordingFollowRepository(
      followers: [
        const Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน'),
        const Profile(id: 'u2', username: 'ploy'),
      ],
    );
    followingRepo = RecordingFollowRepository(
      following: [
        const Profile(id: 'u3', username: 'kade', displayName: 'เคด'),
      ],
    );
    emptyFollowersRepo = RecordingFollowRepository(followers: []);
    emptyFollowingRepo = RecordingFollowRepository(following: []);
    profileRepo = RecordingProfileRepository(
      profile:
          const Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน'),
    );
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
  });

  Widget buildList(
    RecordingFollowRepository followRepository, {
    required FollowListMode mode,
  }) =>
      MaterialApp(
        home: FollowListScreen(
          followRepository: followRepository,
          profileRepository: profileRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'me',
          mode: mode,
        ),
      );

  testWidgets('shows the Followers list with display name and username',
      (tester) async {
    await tester
        .pumpWidget(buildList(followersRepo, mode: FollowListMode.followers));
    await tester.pumpAndSettle();

    expect(find.text('ผู้ติดตาม'), findsOneWidget);
    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('@namfah'), findsOneWidget);
    // u2 has no display name -- nameOrUsername falls back to "@ploy",
    // same as the subtitle line, so it appears twice (name + subtitle).
    expect(find.text('@ploy'), findsNWidgets(2));
  });

  testWidgets('shows the Following list under its own title', (tester) async {
    await tester
        .pumpWidget(buildList(followingRepo, mode: FollowListMode.following));
    await tester.pumpAndSettle();

    expect(find.text('กำลังติดตาม'), findsOneWidget);
    expect(find.text('เคด'), findsOneWidget);
    expect(find.text('@kade'), findsOneWidget);
  });

  testWidgets('shows a mode-specific empty state for Followers',
      (tester) async {
    await tester.pumpWidget(
      buildList(emptyFollowersRepo, mode: FollowListMode.followers),
    );
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีใครติดตามคุณเลย'), findsOneWidget);
  });

  testWidgets('shows a mode-specific empty state for Following',
      (tester) async {
    await tester.pumpWidget(
      buildList(emptyFollowingRepo, mode: FollowListMode.following),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
          'คุณยังไม่ได้ติดตามใครเลย ลองกดติดตามจาก Drop หรือ Pop ที่ชอบดูสิ'),
      findsOneWidget,
    );
  });

  testWidgets(
      'tapping a row opens that user\'s profile (WYN-013 -- rows were '
      'intentionally non-tappable in WYN-008 since no destination screen '
      'existed yet)', (tester) async {
    await tester
        .pumpWidget(buildList(followersRepo, mode: FollowListMode.followers));
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsWidgets);

    await tester.tap(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });

  // WYN-039 Requirement 3 ("Remove Follower").
  group('Remove Follower (WYN-039)', () {
    late RecordingFollowRepository removableFollowersRepo;

    setUp(() {
      removableFollowersRepo = RecordingFollowRepository(
        followers: [
          const Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน'),
        ],
      );
    });

    testWidgets('shows ลบ on your own Followers list', (tester) async {
      await tester.pumpWidget(
        buildList(removableFollowersRepo, mode: FollowListMode.followers),
      );
      await tester.pumpAndSettle();

      expect(find.text('ลบ'), findsOneWidget);
    });

    testWidgets('never shows ลบ on your own Following list', (tester) async {
      await tester
          .pumpWidget(buildList(followingRepo, mode: FollowListMode.following));
      await tester.pumpAndSettle();

      expect(find.text('ลบ'), findsNothing);
    });

    testWidgets('never shows ลบ when viewing someone else\'s Followers list',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: FollowListScreen(
          followRepository: removableFollowersRepo,
          profileRepository: profileRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
          userId: 'someone-else',
          mode: FollowListMode.followers,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('ลบ'), findsNothing);
    });

    testWidgets(
        'tapping ลบ asks to confirm, and confirming calls removeFollower '
        'and removes the row', (tester) async {
      await tester.pumpWidget(
        buildList(removableFollowersRepo, mode: FollowListMode.followers),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(removableFollowersRepo.removeFollowerArgs, isEmpty);

      await tester.tap(find.text('เอาออก'));
      await tester.pumpAndSettle();

      expect(removableFollowersRepo.removeFollowerArgs, ['u1']);
      expect(find.text('น้ำฝน'), findsNothing);
    });

    testWidgets('canceling the confirm dialog leaves the row in place',
        (tester) async {
      await tester.pumpWidget(
        buildList(removableFollowersRepo, mode: FollowListMode.followers),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();

      expect(removableFollowersRepo.removeFollowerArgs, isEmpty);
      expect(find.text('น้ำฝน'), findsOneWidget);
    });

    testWidgets('a failed removal shows an error and keeps the row',
        (tester) async {
      removableFollowersRepo.removeFollowerError = Exception('network error');
      await tester.pumpWidget(
        buildList(removableFollowersRepo, mode: FollowListMode.followers),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('เอาออก'));
      await tester.pumpAndSettle();

      expect(find.text('ทำรายการไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
      expect(find.text('น้ำฝน'), findsOneWidget);
    });
  });
}
