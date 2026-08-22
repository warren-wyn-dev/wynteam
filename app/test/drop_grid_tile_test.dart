import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/widgets/drop_grid_tile.dart';

import 'support/fake_supabase_session.dart';

Drop _drop({int likeCount = 7}) => Drop(
      id: 'd1',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d1.jpg',
      createdAt: DateTime.now(),
      likeCount: likeCount,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
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
}
