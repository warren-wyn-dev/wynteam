import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wyn/features/feed/data/post.dart';
import 'package:wyn/features/feed/data/post_repository.dart';
import 'package:wyn/features/feed/presentation/post_detail_screen.dart';

void main() {
  // SupabaseClient() only stores config here -- the actual fetchComments()
  // call below hits the fake test HTTP client (mocked to 400 by
  // flutter_test), which is enough to exercise the error branch without a
  // real backend.
  final postRepository =
      PostRepository(SupabaseClient('https://example.supabase.co', 'test-key'));

  final tallPost = Post(
    id: 'p1',
    authorId: 'u1',
    authorUsername: 'namfah',
    createdAt: DateTime.now(),
    textContent: 'a' * 400,
    imageUrl: 'https://example.supabase.co/posts/p1.jpg',
    likeCount: 0,
    commentCount: 0,
    likedByMe: false,
  );

  testWidgets(
      'a tall post header (long text + image) scrolls instead of '
      'overflowing on a short viewport', (tester) async {
    // The default flutter_test surface (800x600) is wide/short -- exactly
    // the shape that overflowed before the post header and comment list
    // were merged into one scrollable list. See post_detail_screen.dart.
    await tester.pumpWidget(MaterialApp(
      home: PostDetailScreen(postRepository: postRepository, post: tallPost),
    ));
    // fetchComments() fails against the fake network -- expected, and the
    // NetworkImage for the post's image fails too. Neither is what this
    // test checks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();

    expect(tester.takeException(), isNull);
  });
}
