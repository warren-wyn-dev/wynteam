// QA-WYN-110-002: HomeDropCard's action row (heart/comment/repost/eye)
// overflowed the available width by 3px at 320px screens, even with
// like/comment counts at 0 (not a long-number problem) -- see
// .wyn/tasks/bugs/WYN-110-homedropcard-320px-action-row-overflow.md.
// Found while QA was testing WYN-110's scroll mechanism, but pre-dates it
// and is unrelated to it (this file, home_drop_card.dart, was untouched
// by that change). This is the dedicated, no-scroll/no-NestedScrollView
// widget test QA's bug report asked for.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/square_crop.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';

import 'support/recording_drop_repository.dart';

HomeFeedItem _item({int likeCount = 0, int commentCount = 0}) => HomeFeedItem(
      id: 'd1',
      contentType: HomeContentType.drop,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      createdAt: DateTime.now(),
      caption: 'hello',
      imageUrl: 'https://example.supabase.co/drops/d1_0.jpg',
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: false,
      savedByMe: false,
      imageCount: 1,
      aspectRatio: DropAspectRatio.portrait,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required double width,
}) async {
  final size = Size(width, 844);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  ));
}

void main() {
  late RecordingDropRepository repo;

  setUp(() {
    repo = RecordingDropRepository();
  });

  Widget card(HomeFeedItem item) => HomeDropCard(
        item: item,
        dropRepository: repo,
        onTap: () {},
        onToggleLike: () {},
        onToggleSave: () {},
        onOpenProfile: () {},
        onToggleRedrop: () {},
        onQuoteRedrop: () {},
      );

  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    testWidgets(
        'QA-WYN-110-002: at ${width}px, zero-count action row does not '
        'overflow', (tester) async {
      await _pump(tester, card(_item()), width: width);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'QA-WYN-110-002: at ${width}px, a 5-digit like/comment count does '
        'not overflow either', (tester) async {
      await _pump(
        tester,
        card(_item(likeCount: 12345, commentCount: 9876)),
        width: width,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }
}
