import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/chat/presentation/chat_inbox_screen.dart';
import 'package:wyn/features/drop/presentation/create_drop_screen.dart';
import 'package:wyn/features/notification/presentation/notification_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';
import 'package:wyn/features/root/presentation/root_shell.dart';

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

/// WYN-072 (Guest Browsing): requireRealAccount() (guest_gate.dart) must
/// intercept Profile/Drop("+")/Notifications/Chat for an Anonymous
/// Sign-In session -- a separate file from root_shell_test.dart because
/// it needs its own `initFakeSupabaseSession(isAnonymous: true)` in
/// `setUpAll` (Supabase.initialize() is a singleton -- can't flip
/// anonymity mid-file the way a fresh RecordingAuthRepository can for
/// AuthGate elsewhere). Uses the exact same injected-Recording*-
/// repository shape as root_shell_test.dart's own buildShell() --
/// deliberately does NOT go through AuthGate/a real HomeRepository (see
/// that file's own comment on why RootShell built with all-default
/// repositories leaks a RealtimeClient pending-disconnect Timer at test
/// teardown -- .wyn/tasks/bugs/WYN-072-auth-gate-test-realtime-timer-leak.md).
void main() {
  late RecordingDropRepository sharedDropRepository;
  late RecordingPopRepository sharedPopRepository;
  late RecordingFollowRepository sharedFollowRepository;
  late RecordingProfileRepository sharedProfileRepository;
  late RecordingSavedRepository sharedSavedRepository;
  late RecordingClubRepository sharedClubRepository;
  late RecordingClubPostRepository sharedClubPostRepository;
  late RecordingHomeRepository sharedHomeRepository;
  late RecordingNotificationRepository sharedNotificationRepository;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'guest', isAnonymous: true);

    sharedDropRepository = RecordingDropRepository();
    sharedPopRepository = RecordingPopRepository();
    sharedFollowRepository = RecordingFollowRepository();
    sharedProfileRepository =
        RecordingProfileRepository(profile: const Profile(id: 'guest', username: 'guest'));
    sharedSavedRepository = RecordingSavedRepository();
    sharedClubRepository = RecordingClubRepository();
    sharedClubPostRepository = RecordingClubPostRepository();
    sharedHomeRepository = RecordingHomeRepository(feedItems: []);
    sharedNotificationRepository = RecordingNotificationRepository();
  });

  // Sanity check that the fake session really is anonymous -- if this
  // ever fails, every test below is meaningless (they'd just be
  // re-testing the already-covered non-guest paths).
  setUp(() {
    expect(Supabase.instance.client.auth.currentUser?.isAnonymous, isTrue);
  });

  Widget buildShell() => MaterialApp(
        home: RootShell(
          dropRepository: sharedDropRepository,
          popRepository: sharedPopRepository,
          followRepository: sharedFollowRepository,
          profileRepository: sharedProfileRepository,
          savedRepository: sharedSavedRepository,
          notificationRepository: sharedNotificationRepository,
          clubRepository: sharedClubRepository,
          clubPostRepository: sharedClubPostRepository,
          homeRepository: sharedHomeRepository,
        ),
      );

  testWidgets(
      'tapping Profile as a guest shows the sign-in dialog instead of '
      'ViewProfileScreen', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อดำเนินการต่อ'), findsOneWidget);
    expect(find.byType(ViewProfileScreen), findsNothing);
  });

  testWidgets(
      'tapping Drop ("+") as a guest shows the sign-in dialog instead of '
      'CreateDropScreen', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('โพสต์'));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อดำเนินการต่อ'), findsOneWidget);
    expect(find.byType(CreateDropScreen), findsNothing);
  });

  testWidgets(
      'tapping Notifications as a guest shows the sign-in dialog instead '
      'of NotificationListScreen', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อดำเนินการต่อ'), findsOneWidget);
    expect(find.byType(NotificationListScreen), findsNothing);
  });

  testWidgets(
      'tapping "ไว้ทีหลัง" on the dialog dismisses it and leaves the guest '
      'on Home, still signed in anonymously', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('เข้าสู่ระบบเพื่อดำเนินการต่อ'), findsOneWidget);

    await tester.tap(find.text('ไว้ทีหลัง'));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อดำเนินการต่อ'), findsNothing);
    expect(find.byType(ViewProfileScreen), findsNothing);
    expect(Supabase.instance.client.auth.currentUser?.isAnonymous, isTrue);
  });

  testWidgets(
      'tapping the chat icon as a guest shows the sign-in dialog instead '
      'of ChatInboxScreen', (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chat_bubble_outline));
    await tester.pumpAndSettle();

    expect(find.text('เข้าสู่ระบบเพื่อดำเนินการต่อ'), findsOneWidget);
    expect(find.byType(ChatInboxScreen), findsNothing);
  });

  // Declared LAST on purpose -- this is the one test in this file that
  // actually signs the fake global Supabase session out, which every
  // other test's setUp() sanity check (currentUser?.isAnonymous == true)
  // depends on staying intact. Supabase.initialize() can only run once
  // per test file, so there's no cheap way to re-hydrate a fresh
  // anonymous session for tests declared after this one -- ordering is
  // the guard instead.
  testWidgets(
      'tapping "สมัคร/เข้าสู่ระบบ" on the dialog signs the guest out',
      (tester) async {
    await tester.pumpWidget(buildShell());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('สมัคร/เข้าสู่ระบบ'));
    await tester.pumpAndSettle();

    expect(Supabase.instance.client.auth.currentSession, isNull);
  });
}
