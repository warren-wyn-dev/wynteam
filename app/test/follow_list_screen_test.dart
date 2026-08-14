import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/follow/presentation/follow_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_follow_repository.dart';

void main() {
  late RecordingFollowRepository followersRepo;
  late RecordingFollowRepository followingRepo;
  late RecordingFollowRepository emptyFollowersRepo;
  late RecordingFollowRepository emptyFollowingRepo;

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
  });

  testWidgets('shows the Followers list with display name and username',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FollowListScreen(
        followRepository: followersRepo,
        userId: 'me',
        mode: FollowListMode.followers,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ผู้ติดตาม'), findsOneWidget);
    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('@namfah'), findsOneWidget);
    // u2 has no display name -- nameOrUsername falls back to "@ploy",
    // same as the subtitle line, so it appears twice (name + subtitle).
    expect(find.text('@ploy'), findsNWidgets(2));
  });

  testWidgets('shows the Following list under its own title', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FollowListScreen(
        followRepository: followingRepo,
        userId: 'me',
        mode: FollowListMode.following,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('กำลังติดตาม'), findsOneWidget);
    expect(find.text('เคด'), findsOneWidget);
    expect(find.text('@kade'), findsOneWidget);
  });

  testWidgets('shows a mode-specific empty state for Followers',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FollowListScreen(
        followRepository: emptyFollowersRepo,
        userId: 'me',
        mode: FollowListMode.followers,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีใครติดตามคุณเลย'), findsOneWidget);
  });

  testWidgets('shows a mode-specific empty state for Following',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FollowListScreen(
        followRepository: emptyFollowingRepo,
        userId: 'me',
        mode: FollowListMode.following,
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('คุณยังไม่ได้ติดตามใครเลย ลองกดติดตามจาก Drop หรือ Pop ที่ชอบดูสิ'),
      findsOneWidget,
    );
  });

  testWidgets('rows have no tap ripple -- there is no destination screen '
      'for them this round', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FollowListScreen(
        followRepository: followersRepo,
        userId: 'me',
        mode: FollowListMode.followers,
      ),
    ));
    await tester.pumpAndSettle();

    // See .wyn/docs/design/wyn-008-follow.md, Screen 3: rows are
    // deliberately not wrapped in InkWell -- no ripple, since there's no
    // destination screen to tap through to this round.
    expect(find.byType(InkWell), findsNothing);
  });
}
