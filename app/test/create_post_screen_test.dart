import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/feed/presentation/create_post_screen.dart';

import 'support/recording_post_repository.dart';

void main() {
  // RecordingPostRepository constructs a SupabaseClient, which starts a
  // periodic auto-refresh Timer in its constructor -- create it in
  // setUpAll (outside any individual test's tracked zone) so
  // flutter_test's end-of-test "no pending timers" check doesn't trip on
  // it (mirrors the pattern already used for ProfileRepository in
  // edit_profile_screen_test.dart, which builds it at the top of main()).
  late RecordingPostRepository repo;
  setUpAll(() {
    repo = RecordingPostRepository();
  });

  testWidgets(
      'rapid double-tap on "โพสต์" creates only one post, not a duplicate',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: CreatePostScreen(postRepository: repo),
    ));

    await tester.enterText(find.byType(TextField), 'hello world');
    await tester.pump();

    final postButton = find.widgetWithText(TextButton, 'โพสต์');
    expect(postButton, findsOneWidget);

    // Call the button's onPressed twice back-to-back, synchronously, with
    // no `await` between them -- this is what a rapid double-tap actually
    // produces (the button's onPressed is only disabled on the *next*
    // rebuild, which hasn't happened yet). Going through tester.tap()
    // twice instead would be non-deterministic here: tap() is itself
    // async, so awaiting it once already lets the first tap's whole
    // _post() chain (including its Navigator.pop) run before the second
    // tap fires. See .wyn/tasks/bugs/WYN-004-feed-and-post.md (QA round 1).
    final onPressed = tester.widget<TextButton>(postButton).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(repo.createPostCalls, 1);
  });
}
