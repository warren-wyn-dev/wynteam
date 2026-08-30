import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/follow/presentation/follow_request_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_follow_request_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

/// WYN-039 -- ViewProfileScreen's Locked persona (Design Screen 2), the
/// Follow button's 3rd state, and the own-profile Follow Requests badge.
/// A new file, not folded into view_profile_screen_test.dart, mirrors
/// view_profile_mute_test.dart's own precedent of one dedicated file per
/// feature added to this screen.
void main() {
  const privateProfile =
      Profile(id: 'someone-else', username: 'namfah', isPrivate: true);
  const publicProfile =
      Profile(id: 'someone-else', username: 'namfah', isPrivate: false);

  late RecordingProfileRepository profileRepo;
  late RecordingFollowRepository followRepo;
  late RecordingFollowRequestRepository followRequestRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    profileRepo = RecordingProfileRepository(profile: privateProfile);
    followRepo = RecordingFollowRepository();
    followRequestRepo = RecordingFollowRequestRepository();
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
  });

  setUp(() {
    followRepo.toggleFollowCalls = 0;
    followRequestRepo.hasPendingRequestResult = false;
    followRequestRepo.countPendingRequestsResult = 0;
    followRequestRepo.sendRequestCalls = 0;
    followRequestRepo.cancelRequestCalls = 0;
    followRequestRepo.sendRequestError = null;
    followRequestRepo.cancelRequestError = null;
  });

  Widget buildProfile({Profile? profile, String userId = 'someone-else'}) {
    if (profile != null) profileRepo.profile = profile;
    return MaterialApp(
      home: ViewProfileScreen(
        profileRepository: profileRepo,
        followRepository: followRepo,
        followRequestRepository: followRequestRepo,
        dropRepository: dropRepo,
        popRepository: popRepo,
        savedRepository: savedRepo,
        userId: userId,
      ),
    );
  }

  group('Follow button 3 states', () {
    testWidgets('Public account: unchanged instant follow (regression)',
        (tester) async {
      followRepo.initiallyFollowing = false;
      await tester.pumpWidget(buildProfile(profile: publicProfile));
      await tester.pumpAndSettle();

      expect(find.text('ติดตาม'), findsOneWidget);
      await tester.tap(find.text('ติดตาม'));
      await tester.pump();

      expect(followRepo.toggleFollowCalls, 1);
      expect(followRequestRepo.sendRequestCalls, 0);
    });

    testWidgets(
        'Private account, not following, no pending request: shows '
        'ติดตาม, tapping sends a Follow Request', (tester) async {
      followRepo.initiallyFollowing = false;
      followRequestRepo.hasPendingRequestResult = false;
      await tester.pumpWidget(buildProfile(profile: privateProfile));
      await tester.pumpAndSettle();

      expect(find.text('ติดตาม'), findsOneWidget);
      await tester.tap(find.text('ติดตาม'));
      await tester.pump();

      expect(followRequestRepo.sendRequestCalls, 1);
      expect(followRepo.toggleFollowCalls, 0);
      expect(find.text('ขอติดตามแล้ว'), findsOneWidget);
    });

    testWidgets(
        'Private account, pending request already sent: shows '
        'ขอติดตามแล้ว, tapping asks to confirm before canceling',
        (tester) async {
      followRepo.initiallyFollowing = false;
      followRequestRepo.hasPendingRequestResult = true;
      await tester.pumpWidget(buildProfile(profile: privateProfile));
      await tester.pumpAndSettle();

      expect(find.text('ขอติดตามแล้ว'), findsOneWidget);
      await tester.tap(find.text('ขอติดตามแล้ว'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(followRequestRepo.cancelRequestCalls, 0);

      await tester.tap(find.text('ยกเลิกคำขอ'));
      await tester.pumpAndSettle();

      expect(followRequestRepo.cancelRequestCalls, 1);
      expect(find.text('ติดตาม'), findsOneWidget);
    });

    testWidgets(
        'Private account, already an accepted follower: shows กำลังติดตาม, '
        'behaves exactly like the Public unfollow path', (tester) async {
      followRepo.initiallyFollowing = true;
      await tester.pumpWidget(buildProfile(profile: privateProfile));
      await tester.pumpAndSettle();

      // The "Following" count row's own static label is also literally
      // "กำลังติดตาม" -- disambiguate by widget type, same as
      // drop_detail_screen_test.dart's own convention for this exact
      // string. 18-other-profile.tsx: a filled (tinted) pill, not an
      // outlined button.
      final followButton = find.widgetWithText(FilledButton, 'กำลังติดตาม');
      expect(followButton, findsOneWidget);
      await tester.tap(followButton);
      await tester.pump();

      expect(followRepo.toggleFollowCalls, 1);
      expect(followRequestRepo.cancelRequestCalls, 0);
    });
  });

  group('Locked persona (Drop grid)', () {
    testWidgets(
        'Private account, not following: Drop grid shows the Locked '
        'message instead of the ordinary empty state', (tester) async {
      followRepo.initiallyFollowing = false;
      await tester.pumpWidget(buildProfile(profile: privateProfile));
      await tester.pumpAndSettle();

      expect(find.textContaining('บัญชีนี้เป็นส่วนตัว'), findsOneWidget);
      expect(find.textContaining('ยังไม่มี Post เลย'), findsNothing);
    });

    testWidgets(
        'Private account, accepted follower: Drop grid shows the ordinary '
        'empty state, not the Locked message', (tester) async {
      followRepo.initiallyFollowing = true;
      await tester.pumpWidget(buildProfile(profile: privateProfile));
      await tester.pumpAndSettle();

      expect(find.textContaining('บัญชีนี้เป็นส่วนตัว'), findsNothing);
      expect(find.textContaining('ยังไม่มี Post เลย'), findsOneWidget);
    });

    testWidgets(
        'Follower/Following count stays visible on a Locked profile, but '
        'tapping it shows a SnackBar instead of opening the list',
        (tester) async {
      followRepo
        ..initiallyFollowing = false
        ..followerCount = 5
        ..followingCount = 2;
      await tester.pumpWidget(buildProfile(profile: privateProfile));
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('ผู้ติดตาม'));
      await tester.pumpAndSettle();

      expect(find.text('ต้องติดตามก่อนถึงจะดูรายชื่อได้'), findsOneWidget);
      expect(find.byType(ViewProfileScreen), findsOneWidget);
    });
  });

  group('Own profile: Follow Requests badge', () {
    testWidgets(
        'Private own profile with pending requests shows the badge, '
        'tapping opens FollowRequestListScreen', (tester) async {
      followRequestRepo.countPendingRequestsResult = 3;
      await tester.pumpWidget(buildProfile(
        profile: const Profile(id: 'me', username: 'me', isPrivate: true),
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      expect(find.text('คำขอติดตาม (3)'), findsOneWidget);

      await tester.tap(find.text('คำขอติดตาม (3)'));
      await tester.pumpAndSettle();

      expect(find.byType(FollowRequestListScreen), findsOneWidget);
    });

    testWidgets('Private own profile with 0 pending requests hides the badge',
        (tester) async {
      followRequestRepo.countPendingRequestsResult = 0;
      await tester.pumpWidget(buildProfile(
        profile: const Profile(id: 'me', username: 'me', isPrivate: true),
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('คำขอติดตาม ('), findsNothing);
    });

    testWidgets(
        'Public own profile never shows the badge even with a '
        'nonzero count', (tester) async {
      followRequestRepo.countPendingRequestsResult = 3;
      await tester.pumpWidget(buildProfile(
        profile: const Profile(id: 'me', username: 'me', isPrivate: false),
        userId: 'me',
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('คำขอติดตาม ('), findsNothing);
    });
  });
}
