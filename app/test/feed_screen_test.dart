import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/feed/data/post.dart';
import 'package:wyn/features/feed/presentation/feed_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_post_repository.dart';

void main() {
  // Both of these construct a SupabaseClient, which starts a periodic
  // auto-refresh Timer in its constructor -- run this in setUpAll (outside
  // any individual test's tracked zone) so flutter_test's end-of-test
  // "no pending timers" check doesn't trip on it.
  late RecordingPostRepository repo;
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingPostRepository(feedPosts: [
      Post(
        id: 'p1',
        authorId: 'someone-else',
        authorUsername: 'namfah',
        createdAt: DateTime.now(),
        textContent: 'hello',
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
      ),
    ]);
  });

  testWidgets(
      'rapid double-tap on Like sends a fresh currentlyLiked value each '
      'time instead of reusing the stale pre-tap state', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: FeedScreen(postRepository: repo),
    ));
    await tester.pumpAndSettle();

    final likeButton = find.widgetWithIcon(IconButton, Icons.favorite_border);
    expect(likeButton, findsOneWidget);

    // Call the button's onPressed twice back-to-back, synchronously, with
    // no `await` between them -- this is what a rapid double-tap actually
    // produces (nothing rebuilds between the two calls). Going through
    // tester.tap() twice instead would be non-deterministic here: tap()
    // is itself async, so awaiting it once already lets the first tap's
    // whole _toggleLike() chain run before the second tap fires. See
    // .wyn/tasks/bugs/WYN-004-feed-and-post.md (QA round 1).
    final onPressed = tester.widget<IconButton>(likeButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    // Before the fix, both calls read the same captured (pre-tap, unliked)
    // Post and both sent currentlyLiked: false -- a duplicate "like" insert
    // that would violate the likes table's primary key on a real backend.
    // After the fix, each call re-reads the live state, so the second call
    // correctly reflects what the first call's optimistic update produced.
    expect(repo.toggleLikeCalls, 2);
    expect(repo.toggleLikeCurrentlyLikedArgs, [false, true]);
  });
}
