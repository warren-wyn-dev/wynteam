import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/mute/presentation/muted_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';
import 'package:wyn/features/profile/presentation/view_profile_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';
import 'support/recording_mute_repository.dart';
import 'support/recording_pop_repository.dart';
import 'support/recording_profile_repository.dart';
import 'support/recording_saved_repository.dart';

void main() {
  const namfah = Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน');
  const ploy = Profile(id: 'u2', username: 'ploy');

  // Built once (not per-test) -- see RecordingBlockRepository's doc
  // comment for why: each instance starts its own SupabaseClient
  // auto-refresh Timer, and building a fresh one inside every
  // testWidgets body accumulates timers that trip the "Timer still
  // pending" test-binding assertion.
  late RecordingMuteRepository repo;
  late RecordingProfileRepository profileRepo;
  late RecordingFollowRepository followRepo;
  late RecordingDropRepository dropRepo;
  late RecordingPopRepository popRepo;
  late RecordingSavedRepository savedRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingMuteRepository();
    profileRepo = RecordingProfileRepository(profile: namfah);
    followRepo = RecordingFollowRepository();
    dropRepo = RecordingDropRepository();
    popRepo = RecordingPopRepository();
    savedRepo = RecordingSavedRepository();
  });

  setUp(() {
    repo.mutedUsersPages = const [];
    repo.fetchMutedUsersError = null;
    repo.muteUserError = null;
    repo.unmuteUserError = null;
    repo.isMutedError = null;
    repo.isMutedCalls = 0;
    repo.muteUserCalls = 0;
    repo.unmuteUserCalls = 0;
    repo.lastMutedUserId = null;
    repo.lastUnmutedUserId = null;
  });

  Widget buildScreen() => MaterialApp(
        home: MutedListScreen(
          muteRepository: repo,
          profileRepository: profileRepo,
          followRepository: followRepo,
          dropRepository: dropRepo,
          popRepository: popRepo,
          savedRepository: savedRepo,
        ),
      );

  testWidgets('shows the muted users with name and username', (tester) async {
    repo.mutedUsersPages = [
      [namfah, ploy],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('บัญชีที่ปิดเสียง'), findsOneWidget);
    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('@namfah'), findsOneWidget);
    expect(find.text('@ploy'), findsNWidgets(2));
  });

  testWidgets('shows an empty state when nobody is muted', (tester) async {
    repo.mutedUsersPages = [[]];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีบัญชีที่ปิดเสียง'), findsOneWidget);
  });

  testWidgets('shows an error state with retry on load failure, and retry '
      'recovers once the repository stops failing', (tester) async {
    repo.fetchMutedUsersError = Exception('network down');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('โหลดรายชื่อไม่สำเร็จ'), findsOneWidget);

    repo.fetchMutedUsersError = null;
    repo.mutedUsersPages = [
      [namfah],
    ];
    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('น้ำฝน'), findsOneWidget);
  });

  testWidgets('tapping เปิดเสียง unmutes immediately with no confirm dialog '
      '(unlike Block\'s เลิกบล็อก)', (tester) async {
    repo.mutedUsersPages = [
      [namfah, ploy],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final unmuteButtons = find.widgetWithText(OutlinedButton, 'เปิดเสียง');
    expect(unmuteButtons, findsNWidgets(2));

    await tester.tap(unmuteButtons.first);
    await tester.pumpAndSettle();

    // No dialog anywhere -- straight to the RPC call.
    expect(find.byType(AlertDialog), findsNothing);
    expect(repo.unmuteUserCalls, 1);
    expect(repo.lastUnmutedUserId, 'u1');
    expect(find.text('น้ำฝน'), findsNothing);
    expect(find.text('@ploy'), findsNWidgets(2));
  });

  testWidgets('a row (outside the button) is tappable to that user\'s '
      'profile -- unlike BlockedListScreen, which deliberately is not',
      (tester) async {
    repo.mutedUsersPages = [
      [namfah],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('น้ำฝน'));
    await tester.pumpAndSettle();

    expect(find.byType(ViewProfileScreen), findsOneWidget);
  });
}
