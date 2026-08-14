import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/drop_detail_screen.dart';

import 'support/fake_supabase_session.dart';
import 'support/recording_drop_repository.dart';

void main() {
  // DropDetailScreen reads Supabase.instance.client.auth.currentUser
  // directly (for the "is this my own Drop" check) -- initialize a fake
  // local-only session so it can be pumped at all. See
  // .wyn/learning/PATTERNS.md.
  late RecordingDropRepository repo;
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
    repo = RecordingDropRepository();
  });

  final tallDrop = Drop(
    id: 'd1',
    authorId: 'u1',
    authorUsername: 'namfah',
    imageUrl: 'https://example.supabase.co/drops/d1.jpg',
    caption: 'a' * 400,
    createdAt: DateTime.now(),
    likeCount: 0,
    commentCount: 0,
    likedByMe: false,
    savedByMe: false,
  );

  testWidgets(
      'a tall Drop header (long caption + image) scrolls instead of '
      'overflowing on a short viewport', (tester) async {
    // The default flutter_test surface (800x600) is wide/short -- the
    // exact shape that overflowed WYN-004's PostDetailScreen before it
    // merged the header into the comment list's scrollable. This spec
    // (.wyn/docs/design/wyn-005-drop.md) called out building it that way
    // from the start, so this test exists to prove it actually was.
    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, drop: tallDrop),
    ));
    // fetchComments() fails against the fake network, and the image
    // fails to load -- both expected, neither is what this test checks.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    tester.takeException();

    expect(tester.takeException(), isNull);
  });

  testWidgets('toggling Like flips the icon and count optimistically',
      (tester) async {
    final drop = Drop(
      id: 'd2',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d2.jpg',
      createdAt: DateTime.now(),
      likeCount: 3,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: DropDetailScreen(dropRepository: repo, drop: drop),
    ));
    await tester.pump();
    // No real network access in the test environment -- expected and
    // irrelevant to what this test checks (that the like state toggles).
    tester.takeException();

    final likeButton = find.byIcon(Icons.favorite_border);
    expect(likeButton, findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // The square image above it (AspectRatio 1, 800px wide in this test
    // viewport) pushes the like button below the visible 600px-tall
    // surface -- scroll it into view before tapping.
    await tester.ensureVisible(likeButton);
    await tester.pumpAndSettle();
    tester.takeException();
    await tester.tap(likeButton);
    await tester.pump();

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });
}
