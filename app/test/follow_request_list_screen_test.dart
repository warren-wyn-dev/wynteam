import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/follow/presentation/follow_request_list_screen.dart';
import 'package:wyn/features/profile/data/profile.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_follow_request_repository.dart';

/// WYN-039 Design, Screen 3 -- mirrors follow_list_screen_test.dart's own
/// shape closely, since FollowRequestListScreen was built by copying
/// FollowListScreen's list/pagination/state pattern.
void main() {
  const requester =
      Profile(id: 'requester-1', username: 'aof', displayName: 'Aof');

  late RecordingFollowRequestRepository repo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingFollowRequestRepository();
  });

  setUp(() {
    repo.pendingRequests
      ..clear()
      ..add(requester);
    repo.acceptRequestArgs.clear();
    repo.rejectRequestArgs.clear();
    repo.acceptRequestError = null;
    repo.rejectRequestError = null;
  });

  Widget buildScreen() => MaterialApp(
        home: FollowRequestListScreen(followRequestRepository: repo),
      );

  testWidgets('shows every pending requester returned by the repository',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('Aof'), findsOneWidget);
    expect(find.text('@aof'), findsOneWidget);
    expect(find.text('ยอมรับ'), findsOneWidget);
    expect(find.text('ปฏิเสธ'), findsOneWidget);
  });

  testWidgets('empty state shows the no-requests message, not a crash',
      (tester) async {
    repo.pendingRequests.clear();
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    expect(find.text('ยังไม่มีคำขอติดตาม'), findsOneWidget);
  });

  testWidgets('tapping ยอมรับ calls acceptRequest and removes the row',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ยอมรับ'));
    await tester.pumpAndSettle();

    expect(repo.acceptRequestArgs, ['requester-1']);
    expect(find.text('Aof'), findsNothing);
  });

  testWidgets(
      'tapping ปฏิเสธ asks to confirm, and confirming calls rejectRequest '
      'and removes the row', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ปฏิเสธ'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repo.rejectRequestArgs, isEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'ปฏิเสธ'));
    await tester.pumpAndSettle();

    expect(repo.rejectRequestArgs, ['requester-1']);
    expect(find.text('Aof'), findsNothing);
  });

  testWidgets('canceling the ปฏิเสธ confirm dialog leaves the row in place',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ปฏิเสธ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(repo.rejectRequestArgs, isEmpty);
    expect(find.text('Aof'), findsOneWidget);
  });

  testWidgets('a failed accept shows an error and keeps the row',
      (tester) async {
    repo.acceptRequestError = Exception('network error');
    await tester.pumpWidget(buildScreen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('ยอมรับ'));
    await tester.pumpAndSettle();

    expect(find.text('ยอมรับคำขอไม่สำเร็จ ลองใหม่อีกครั้ง'), findsOneWidget);
    expect(find.text('Aof'), findsOneWidget);
  });
}
