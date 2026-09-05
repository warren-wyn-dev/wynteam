// WYN-109 follow-up (2026-09-05) -- while closing out the Founder's
// "หน้า Saved ยังวาด 4:5 ทุกรูป" note, closer reading found that note was
// wrong. SavedGridTile (ProfileSavedTab's 3-column grid) and DropGridTile
// (the Drop grid it mirrors) both force `AspectRatio(aspectRatio: 1)`
// unconditionally -- the same square-crop-in-a-grid convention Threads/
// Instagram use, applied consistently before WYN-109 ever existed. It was
// never reading `image_aspect_ratio` and never fell back to 4:5; it just
// never had an aspect ratio to read in the first place.
//
// This guards that reading: a post whose full-size card renders at 16:9
// must still tile as a square here. Anyone who "fixes" this later,
// mistaking it for the same gap B-109-2 was, breaks the grid.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/square_crop.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/saved/presentation/widgets/saved_grid_tile.dart';

HomeFeedItem _item({required DropAspectRatio aspectRatio}) => HomeFeedItem(
      id: 'd1',
      contentType: HomeContentType.drop,
      authorId: 'a1',
      authorUsername: 'namfah',
      createdAt: DateTime(2026, 1, 1),
      imageUrl: 'https://example.test/a.jpg',
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: true,
      aspectRatio: aspectRatio,
    );

void main() {
  testWidgets(
      'SavedGridTile stays square for a 16:9 post -- the Saved grid was '
      'never a 4:5 gap, it never reads aspectRatio at all', (tester) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 120,
        height: 300,
        child: SavedGridTile(
          item: _item(aspectRatio: DropAspectRatio.landscape),
          onTap: () {},
        ),
      ),
    ));

    final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));
    expect(aspectRatio.aspectRatio, 1);
  });
}
