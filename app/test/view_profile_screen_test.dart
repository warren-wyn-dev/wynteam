import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/follow/presentation/follow_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_profile_repository.dart';

void main() {
  const profile = Profile(
    id: 'me',
    username: 'me_user',
    displayName: 'ตัวฉันเอง',
  );

  late RecordingProfileRepository profileRepo;
  late RecordingFollowRepository followRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    profileRepo = RecordingProfileRepository(profile: profile);
    followRepo = RecordingFollowRepository(followerCount: 12, followingCount: 5);
  });

  testWidgets('shows Follower/Following counts loaded alongside the profile',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ViewProfileScreen(
        profileRepository: profileRepo,
        followRepository: followRepo,
        userId: 'me',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('12'), findsOneWidget);
    expect(find.text('ผู้ติดตาม'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('กำลังติดตาม'), findsOneWidget);
  });

  testWidgets('tapping the Followers count opens FollowListScreen in '
      'followers mode', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ViewProfileScreen(
        profileRepository: profileRepo,
        followRepository: followRepo,
        userId: 'me',
      ),
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
    await tester.pumpWidget(MaterialApp(
      home: ViewProfileScreen(
        profileRepository: profileRepo,
        followRepository: followRepo,
        userId: 'me',
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('กำลังติดตาม'));
    await tester.pumpAndSettle();

    final screen = tester.widget<FollowListScreen>(
      find.byType(FollowListScreen),
    );
    expect(screen.mode, FollowListMode.following);
  });
}
