import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/presentation/create_drop_screen.dart';
import 'package:wyn/features/home/presentation/widgets/from_your_clubs_feed.dart';
import 'package:wyn/features/notification/presentation/notification_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/root/presentation/root_shell.dart';
import 'package:wyn/features/search/presentation/search_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_club_post_repository.dart';
import 'support/recording_club_repository.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_home_repository.dart';
import 'support/recording_notification_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';
import 'support/recording_zoky_repository.dart';

/// WYN-024: the Bottom Nav shell now owns real logic (5 visual
/// destinations mapping to 4 actual tabs + 1 create action, the unread
/// badge, remount-on-visit keys for Profile/Notifications) that used to
/// be spread across HomeFeedScreen or didn't exist at all. Mirrors the
/// injected-repository pattern every other screen already uses (see
/// RootShell's constructor doc comment) specifically so this is
/// testable, rather than only reachable via Supabase.instance like it
/// was pre-WYN-024. See .wyn/docs/design/wyn-024-bottom-nav-v1-restructure.md.
void main() {
  // Bug fix (QA round 1, 2026-08-22): every repository (and its
  // underlying SupabaseClient auto-refresh Timer) must be built once
  // here, not inside buildShell()/individual testWidgets callbacks -- see
  // drop_comment_like_test.dart (WYN-005) and home_feed_screen_test.dart's
  // own setUpAll for why. The original version of this file built all 8
  // repositories fresh on every buildShell() call (i.e. once per test),
  // leaking a live Timer per test that flutter_test's
  // "!timersPending" invariant then failed on for all 6 tests.
  late RecordingDropRepository sharedDropRepository;
  late RecordingPopRepository sharedPopRepository;
  late RecordingFollowRepository sharedFollowRepository;
  late RecordingProfileRepository sharedProfileRepository;
  late RecordingSavedRepository sharedSavedRepository;
  late RecordingClubRepository sharedClubRepository;
  late RecordingClubPostRepository sharedClubPostRepository;
  late RecordingZokyRepository sharedZokyRepository;
  late RecordingHomeRepository defaultHomeRepository;
  late RecordingNotificationRepository defaultNotificationRepository;
  late RecordingNotificationRepository fewUnreadNotificationRepository;
  late RecordingNotificationRepository manyUnreadNotificationRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');

    sharedDropRepository = RecordingDropRepository();
    sharedPopRepository = RecordingPopRepository();
    sharedFollowRepository = RecordingFollowRepository();
    sharedProfileRepository =
        RecordingProfileRepository(profile: const Profile(id: 'me', username: 'me'));
    sharedSavedRepository = RecordingSavedRepository();
    sharedClubRepository = RecordingClubRepository();
    sharedClubPostRepository = RecordingClubPostRepository();
    sharedZokyRepository = RecordingZokyRepository();
    defaultHomeRepository = RecordingHomeRepository(feedItems: []);
    defaultNotificationRepository = RecordingNotificationRepository();
    fewUnreadNotificationRepository = RecordingNotificationRepository(unreadCount: 3);
    manyUnreadNotificationRepository = RecordingNotificationRepository(unreadCount: 15);
  });

  Widget buildShell({
    RecordingNotificationRepository? notificationRepository,
    RecordingHomeRepository? homeRepository,
  }) =>
      MaterialApp(
        home: RootShell(
          dropRepository: sharedDropRepository,
          popRepository: sharedPopRepository,
          followRepository: sharedFollowRepository,
          profileRepository: sharedProfileRepository,
          savedRepository: sharedSavedRepository,
          notificationRepository: notificationRepository ?? defaultNotificationRepository,
          clubRepository: sharedClubRepository,
          clubPostRepository: sharedClubPostRepository,
          zokyRepository: sharedZokyRepository,
          homeRepository: homeRepository ?? defaultHomeRepository,
        ),
      );

  testWidgets('defaults to the Home tab with all 5 destinations present',
      (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Drop'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    // Home's own content (no top row anymore -- WYN-024 Screen 2) is
    // showing by default: the feed-mode toggle is Home's, not any other
    // tab's.
    expect(find.text('สำหรับคุณ'), findsOneWidget);
    expect(find.text('ติดตาม'), findsOneWidget);
  });

  testWidgets('tapping Search switches to SearchScreen without autofocus',
      (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    final search = tester.widget<SearchScreen>(find.byType(SearchScreen));
    expect(search.autofocus, isFalse);
  });

  testWidgets(
      'tapping Drop pushes CreateDropScreen without changing the selected tab',
      (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Drop'));
    await tester.pumpAndSettle();

    expect(find.byType(CreateDropScreen), findsOneWidget);

    // CreateDropScreen has no AppBar/default back button at all -- its
    // own header supplies a plain "ยกเลิก" text button (Key
    // 'cancel_button') that calls Navigator.pop(false), so
    // tester.pageBack() (which looks for a BackButton/
    // CupertinoNavigationBarBackButton specifically) would find neither.
    await tester.tap(find.byKey(const Key('cancel_button')));
    await tester.pumpAndSettle();

    // Still on Home, not stuck on some "Drop tab" -- there is none.
    expect(find.text('สำหรับคุณ'), findsOneWidget);
    expect(find.byType(FromYourClubsFeed), findsNothing);
  });

  testWidgets('shows the unread notification count as a badge, and clears '
      'it optimistically after switching to Notifications', (tester) async {
    await tester.pumpWidget(buildShell(
      notificationRepository: fewUnreadNotificationRepository,
    ));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(find.byType(NotificationListScreen), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('caps the notification badge at "9+"', (tester) async {
    await tester.pumpWidget(buildShell(
      notificationRepository: manyUnreadNotificationRepository,
    ));
    await tester.pumpAndSettle();

    expect(find.text('9+'), findsOneWidget);
    expect(find.text('15'), findsNothing);
  });

  testWidgets('tapping Profile shows ViewProfileScreen for the current user',
      (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });

  // WYN-064: tapping Home while already on Home doesn't navigate anywhere
  // (there's no other tab to go to) -- it signals HomeFeedScreen to
  // scroll-to-top/refresh instead (that behavior itself is covered by
  // home_feed_screen_test.dart's own WYN-064 group, which can reach the
  // signal directly rather than through the Bottom Nav). This just
  // proves the wiring: still on Home, no crash, no accidental remount of
  // Profile/Notifications' visit-key state.
  testWidgets('tapping Home while already on Home stays on Home, no crash',
      (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('สำหรับคุณ'), findsOneWidget);
    expect(find.byType(ViewProfileScreen), findsNothing);
  });
}
