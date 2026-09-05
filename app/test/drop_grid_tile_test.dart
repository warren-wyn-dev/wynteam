import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/widgets/drop_grid_tile.dart';

import 'support/fake_supabase_session.dart';

Drop _drop({int likeCount = 7, int? imageCount}) => Drop(
      id: 'd1',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d1.jpg',
      createdAt: DateTime.now(),
      likeCount: likeCount,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
      imageCount: imageCount,
    );

void main() {
  // WYN-026: DropGridTile now reads Supabase.instance.client to compare
  // the current user against the Drop's author (report affordance), so
  // it needs a fake session the same way every other widget that reads
  // auth.currentUser does -- see support/fake_supabase_session.dart.
  setUpAll(() async {
    await initFakeSupabaseSession(userId: 'me');
  });

  testWidgets('announces author and like count as one semantics label',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [DropGridTile(drop: _drop(likeCount: 7), onTap: () {})],
        ),
      ),
    ));
    tester.takeException();

    expect(
      find.bySemanticsLabel('รูปของ @namfah, ถูกใจ 7 ครั้ง'),
      findsOneWidget,
    );
  });

  testWidgets('tapping the tile calls onTap exactly once', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [DropGridTile(drop: _drop(), onTap: () => taps++)],
        ),
      ),
    ));
    tester.takeException();

    await tester.tap(find.byType(DropGridTile));
    expect(taps, 1);
  });

  group('author overlay (opt-in, for SearchDropResultsTab)', () {
    testWidgets('off by default -- no @username visible on the tile',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [DropGridTile(drop: _drop(), onTap: () {})],
          ),
        ),
      ));
      tester.takeException();

      expect(find.text('@namfah'), findsNothing);
    });

    testWidgets('showAuthor: true shows the author\'s @username on the tile',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              DropGridTile(drop: _drop(), onTap: () {}, showAuthor: true),
            ],
          ),
        ),
      ));
      tester.takeException();

      expect(find.text('@namfah'), findsOneWidget);
    });
  });

  group('multi-image indicator (WYN-071)', () {
    testWidgets('a single-image Drop shows no stacked-photos icon',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [DropGridTile(drop: _drop(imageCount: 1), onTap: () {})],
          ),
        ),
      ));
      tester.takeException();

      expect(find.byIcon(Icons.filter_none), findsNothing);
    });

    testWidgets('a multi-image Drop shows the stacked-photos icon',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [DropGridTile(drop: _drop(imageCount: 5), onTap: () {})],
          ),
        ),
      ));
      tester.takeException();

      expect(find.byIcon(Icons.filter_none), findsOneWidget);
    });
  });
}
