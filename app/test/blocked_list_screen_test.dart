import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/block/presentation/blocked_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_block_repository.dart';

void main() {
  const namfah = Profile(id: 'u1', username: 'namfah', displayName: 'น้ำฝน');
  const ploy = Profile(id: 'u2', username: 'ploy');

  // Built once (not per-test) -- see RecordingReportRepository's doc
  // comment for why: each instance starts its own SupabaseClient
  // auto-refresh Timer, and building a fresh one inside every
  // testWidgets body accumulates timers that trip the "Timer still
  // pending" test-binding assertion.
  late RecordingBlockRepository repo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingBlockRepository();
  });

  setUp(() {
    repo.blockedUsersPages = const [];
    repo.fetchBlockedUsersError = null;
    repo.blockUserError = null;
    repo.unblockUserError = null;
    repo.blockRelationshipError = null;
    repo.blockRelationshipCalls = 0;
    repo.blockUserCalls = 0;
    repo.unblockUserCalls = 0;
    repo.lastBlockedUserId = null;
    repo.lastUnblockedUserId = null;
  });

  Widget buildScreen() => MaterialApp(
        home: BlockedListScreen(blockRepository: repo),
      );

  testWidgets('shows the blocked users with name and username', (tester) async {
    repo.blockedUsersPages = [
      [namfah, ploy],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('บัญชีที่ถูกบล็อก'), findsOneWidget);
    expect(find.text('น้ำฝน'), findsOneWidget);
    expect(find.text('@namfah'), findsOneWidget);
    // u2 has no display name -- nameOrUsername falls back to "@ploy",
    // same as the subtitle line, so it appears twice.
    expect(find.text('@ploy'), findsNWidgets(2));
  });

  testWidgets('shows an empty state when nobody is blocked', (tester) async {
    repo.blockedUsersPages = [[]];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีบัญชีที่ถูกบล็อก'), findsOneWidget);
  });

  testWidgets('shows an error state with retry on load failure, and retry '
      'recovers once the repository stops failing', (tester) async {
    repo.fetchBlockedUsersError = Exception('network down');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('โหลดรายชื่อไม่สำเร็จ'), findsOneWidget);

    repo.fetchBlockedUsersError = null;
    repo.blockedUsersPages = [
      [namfah],
    ];
    await tester.tap(find.text('ลองใหม่'));
    await tester.pumpAndSettle();

    expect(find.text('น้ำฝน'), findsOneWidget);
  });

  testWidgets(
      'tapping เลิกบล็อก then confirming calls unblockUser and removes the row',
      (tester) async {
    repo.blockedUsersPages = [
      [namfah, ploy],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    final unblockButtons = find.widgetWithText(OutlinedButton, 'เลิกบล็อก');
    expect(unblockButtons, findsNWidgets(2));

    await tester.tap(unblockButtons.first);
    await tester.pumpAndSettle();

    expect(find.text('เลิกบล็อก @namfah?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'เลิกบล็อก'));
    await tester.pumpAndSettle();

    expect(repo.unblockUserCalls, 1);
    expect(repo.lastUnblockedUserId, 'u1');
    expect(find.text('น้ำฝน'), findsNothing);
    expect(find.text('@ploy'), findsNWidgets(2));
  });

  testWidgets('cancelling the confirm dialog leaves the row and calls nothing',
      (tester) async {
    repo.blockedUsersPages = [
      [namfah],
    ];
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'เลิกบล็อก'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'ยกเลิก'));
    await tester.pumpAndSettle();

    expect(repo.unblockUserCalls, 0);
    expect(find.text('น้ำฝน'), findsOneWidget);
  });
}
