import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/drop_comment.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';
import 'support/recording_follow_repository.dart';

void main() {
  // RecordingDropRepository constructs a SupabaseClient, which starts a
  // periodic auto-refresh Timer in its constructor -- create it (and the
  // fake session) in setUpAll, outside any individual test's tracked
  // zone, so flutter_test's end-of-test "no pending timers" check
  // doesn't trip on it. See feed_screen_test.dart (WYN-004) for the same
  // pattern.
  late RecordingDropRepository repo;
  late RecordingFollowRepository followRepo;
  final drop = Drop(
    id: 'd1',
    authorId: 'someone-else',
    authorUsername: 'namfah',
    imageUrl: 'https://example.supabase.co/drops/d1.jpg',
    createdAt: DateTime.now(),
    likeCount: 0,
    commentCount: 1,
    likedByMe: false,
    savedByMe: false,
  );
  final comment = DropComment(
    id: 'c1',
    dropId: 'd1',
    authorId: 'someone-else',
    authorUsername: 'ploy',
    textContent: 'สวยมาก',
    createdAt: DateTime.now(),
    likeCount: 0,
    likedByMe: false,
  );

  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingDropRepository(comments: [comment]);
    followRepo = RecordingFollowRepository();
  });

  testWidgets(
      'rapid double-tap on a comment\'s Like sends a fresh currentlyLiked '
      'value each time instead of reusing the stale pre-tap state',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, followRepository: followRepo, drop: drop),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // The 1:1 image (800px wide in this test viewport) plus the header
    // pushes the comment well below the visible 600px-tall surface --
    // scroll it into the ListView's build/cache extent before searching
    // for it (a plain find.byType() only sees mounted elements, and a
    // sliver list doesn't mount far-off-screen children at all).
    await tester.scrollUntilVisible(
      find.text('สวยมาก'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    tester.takeException();

    // The Drop's own header also has a favorite_border Like button, so
    // disambiguate by the comment button's distinctive small iconSize
    // (16, set in DropDetailScreen's comment row -- the header's Like
    // button uses the default size).
    final likeButton = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.iconSize == 16,
    );
    await tester.ensureVisible(likeButton);
    await tester.pumpAndSettle();
    expect(likeButton, findsOneWidget);

    // Call the button's onPressed twice back-to-back, synchronously, with
    // no `await` between them -- this is what a rapid double-tap actually
    // produces (nothing rebuilds between the two calls). See
    // .wyn/tasks/bugs/WYN-004-feed-and-post.md (QA round 1) for why
    // tester.tap() twice would be non-deterministic here instead.
    final onPressed = tester.widget<IconButton>(likeButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();
    tester.takeException();

    // Before a fix, both calls would read the same captured (pre-tap,
    // unliked) DropComment and both send currentlyLiked: false -- a
    // duplicate insert that would violate drop_comment_likes' primary
    // key on a real backend. Reading _comments[index] fresh each call
    // means the second call correctly reflects what the first call's
    // optimistic update produced.
    expect(repo.toggleCommentLikeCalls, 2);
    expect(repo.toggleCommentLikeCurrentlyLikedArgs, [false, true]);
  });
}
