import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/feed/data/post.dart';
import 'package:wyn/features/feed/presentation/widgets/post_card.dart';

Post _post({
  String authorId = 'u1',
  String? textContent = 'hello world',
  String? imageUrl,
  bool likedByMe = false,
  int likeCount = 0,
  int commentCount = 0,
}) =>
    Post(
      id: 'p1',
      authorId: authorId,
      authorUsername: 'namfah',
      createdAt: DateTime.now(),
      textContent: textContent,
      imageUrl: imageUrl,
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe,
    );

void main() {
  testWidgets('shows the delete button only for the current user\'s own post',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: _post(authorId: 'u1'),
          currentUserId: 'u1',
          onTapLike: () {},
          onTapComments: () {},
          onTapDelete: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('hides the delete button for another user\'s post',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: _post(authorId: 'u1'),
          currentUserId: 'someone-else',
          onTapLike: () {},
          onTapComments: () {},
          onTapDelete: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });

  testWidgets('renders text content when present', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: _post(textContent: 'hello world'),
          currentUserId: 'u1',
          onTapLike: () {},
          onTapComments: () {},
          onTapDelete: () {},
        ),
      ),
    ));

    expect(find.text('hello world'), findsOneWidget);
  });

  testWidgets('shows a filled red heart and count when liked by me',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: _post(likedByMe: true, likeCount: 5),
          currentUserId: 'u1',
          onTapLike: () {},
          onTapComments: () {},
          onTapDelete: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.text('5'), findsOneWidget);
    expect(
      find.bySemanticsLabel('ถูกใจแล้ว กดเพื่อเลิกถูกใจ'),
      findsOneWidget,
    );
  });

  testWidgets('shows an outlined heart when not liked by me', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: _post(likedByMe: false),
          currentUserId: 'u1',
          onTapLike: () {},
          onTapComments: () {},
          onTapDelete: () {},
        ),
      ),
    ));

    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.bySemanticsLabel('กดเพื่อถูกใจ'), findsOneWidget);
  });

  testWidgets('tapping the like button calls onTapLike exactly once',
      (tester) async {
    var likeTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: _post(),
          currentUserId: 'u1',
          onTapLike: () => likeTaps++,
          onTapComments: () {},
          onTapDelete: () {},
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.favorite_border));
    expect(likeTaps, 1);
  });

  testWidgets('tapping the comments button calls onTapComments',
      (tester) async {
    var commentTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: _post(),
          currentUserId: 'u1',
          onTapLike: () {},
          onTapComments: () => commentTaps++,
          onTapDelete: () {},
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.mode_comment_outlined));
    expect(commentTaps, 1);
  });

  testWidgets('tapping delete calls onTapDelete for an own post',
      (tester) async {
    var deleteTaps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PostCard(
          post: _post(authorId: 'u1'),
          currentUserId: 'u1',
          onTapLike: () {},
          onTapComments: () {},
          onTapDelete: () => deleteTaps++,
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(deleteTaps, 1);
  });

  testWidgets('renders an image when imageUrl is set', (tester) async {
    // Real usage always places PostCard inside a scrollable (FeedScreen's
    // ListView, PostDetailScreen's ListView) -- wrap it here too, since a
    // bare Scaffold body gives it a bounded height and the image's 4:3
    // AspectRatio can legitimately overflow that on a wide/short viewport.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            PostCard(
              post: _post(imageUrl: 'https://example.supabase.co/posts/p1.jpg'),
              currentUserId: 'u1',
              onTapLike: () {},
              onTapComments: () {},
              onTapDelete: () {},
            ),
          ],
        ),
      ),
    ));
    // No real network access in the test environment -- expected and
    // irrelevant to what this test checks (that Image.network is wired up).
    tester.takeException();

    expect(find.byType(Image), findsOneWidget);
  });
}
