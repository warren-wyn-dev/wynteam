import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/pop/data/pop_comment.dart';
import 'package:wyn/features/pop/presentation/widgets/pop_comment_sheet.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_pop_repository.dart';

PopComment _comment({
  required String id,
  required String authorId,
  required String text,
}) =>
    PopComment(
      id: id,
      popId: 'p1',
      authorId: authorId,
      authorUsername: authorId == 'me' ? 'me_user' : 'ploy',
      textContent: text,
      createdAt: DateTime.now(),
      likeCount: 0,
      likedByMe: false,
    );

void main() {
  // See drop_comment_like_test.dart (WYN-005) for why every repo (and its
  // underlying SupabaseClient auto-refresh Timer) is built once in
  // setUpAll rather than inside individual testWidgets callbacks. Each
  // scenario gets its own repo so per-repo call counters can't leak
  // between tests or depend on execution order.
  late RecordingPopRepository twoCommentsRepo;
  late RecordingPopRepository likeTestRepo;
  late RecordingPopRepository deleteTestRepo;

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    twoCommentsRepo = RecordingPopRepository(comments: [
      _comment(id: 'c1', authorId: 'me', text: 'คอมเมนต์ของฉันเอง'),
      _comment(id: 'c2', authorId: 'someone-else', text: 'คอมเมนต์ของคนอื่น'),
    ]);
    likeTestRepo = RecordingPopRepository(comments: [
      _comment(id: 'c3', authorId: 'someone-else', text: 'สวยมาก'),
    ]);
    deleteTestRepo = RecordingPopRepository(comments: [
      _comment(id: 'c4', authorId: 'me', text: 'ลบได้'),
    ]);
  });

  Future<void> pumpSheet(
    WidgetTester tester,
    RecordingPopRepository repo, {
    required ValueChanged<int> onCommentCountChanged,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showPopCommentSheet(
                context,
                popRepository: repo,
                popId: 'p1',
                onCommentCountChanged: onCommentCountChanged,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'shows both comments, with a delete button only next to the '
      'current user\'s own comment', (tester) async {
    await pumpSheet(tester, twoCommentsRepo, onCommentCountChanged: (_) {});

    expect(find.text('คอมเมนต์ของฉันเอง'), findsOneWidget);
    expect(find.text('คอมเมนต์ของคนอื่น'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets(
      'rapid double-tap on a comment\'s Like sends a fresh currentlyLiked '
      'value each time instead of reusing the stale pre-tap state',
      (tester) async {
    await pumpSheet(tester, likeTestRepo, onCommentCountChanged: (_) {});

    final likeButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.iconSize == 16,
    );
    expect(likeButton, findsOneWidget);

    final onPressed = tester.widget<IconButton>(likeButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(likeTestRepo.toggleCommentLikeCalls, 2);
    expect(likeTestRepo.toggleCommentLikeCurrentlyLikedArgs, [false, true]);
  });

  testWidgets(
      'deleting an own comment removes it from the list and reports a -1 '
      'count change', (tester) async {
    var delta = 0;
    await pumpSheet(tester, deleteTestRepo, onCommentCountChanged: (d) => delta = d);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(find.text('ลบคอมเมนต์นี้?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(deleteTestRepo.deleteCommentCalls, ['c4']);
    expect(find.text('ลบได้'), findsNothing);
    expect(delta, -1);
  });
}
