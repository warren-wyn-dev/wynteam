import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/post_media.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/presentation/widgets/drop_image_gallery.dart';
import 'package:wyn/features/drop/presentation/widgets/drop_image_viewer.dart';

import 'support/recording_drop_repository.dart';

Drop _drop({required int imageCount}) => Drop(
      id: 'd1',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d1_0.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
      imageCount: imageCount,
    );

void main() {
  // Constructed in setUp, not inline inside a testWidgets body -- see
  // RecordingDiscoveryRepository's own doc comment on why (the
  // GoTrue auto-refresh timer a fresh SupabaseClient starts would
  // otherwise get attributed to that one test's FakeAsync zone and
  // trip flutter_test's `!timersPending` invariant at teardown).
  late RecordingDropRepository singleImageRepo;
  late RecordingDropRepository multiImageRepo;
  late RecordingDropRepository tapRepo;
  late RecordingDropRepository failedFetchRepo;

  setUp(() {
    singleImageRepo = RecordingDropRepository();
    multiImageRepo = RecordingDropRepository()
      ..dropImagesById = {
        'd1': [
          'https://example.supabase.co/drops/d1_0.jpg',
          'https://example.supabase.co/drops/d1_1.jpg',
          'https://example.supabase.co/drops/d1_2.jpg',
        ],
      };
    tapRepo = RecordingDropRepository()
      ..dropImagesById = {
        'd1': [
          'https://example.supabase.co/drops/d1_0.jpg',
          'https://example.supabase.co/drops/d1_1.jpg',
        ],
      };
    failedFetchRepo = RecordingDropRepository()
      ..fetchDropImagesError = Exception('network');
  });

  testWidgets('a single-image Drop renders one image and no page counter',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropImageGallery(
          drop: _drop(imageCount: 1),
          dropRepository: singleImageRepo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      ),
    ));
    tester.takeException();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('1/1'), findsNothing);
  });

  testWidgets(
      'a multi-image Drop fetches the full list and shows a page counter',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropImageGallery(
          drop: _drop(imageCount: 3),
          dropRepository: multiImageRepo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets('tapping a multi-image gallery opens the full-screen viewer',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropImageGallery(
          drop: _drop(imageCount: 2),
          dropRepository: tapRepo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // Beta3: the row is a PostImageCarousel now, not a PageView -- the
    // same card row the Home feed shows. Tapping it still opens the
    // full-screen viewer.
    await tester.tap(find.byType(PostImageCarousel));
    // A lone tap on a GestureDetector that also has onDoubleTap is
    // deliberately held for kDoubleTapTimeout to see if a second tap
    // follows (see DoubleTapLike.onTap's doc comment) -- pumpAndSettle
    // alone doesn't advance that bare Timer since no frame is scheduled
    // while waiting on it.
    await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(DropImageViewer), findsOneWidget);
  });

  testWidgets(
      'a failed fetchDropImages falls back to showing just the first image',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropImageGallery(
          drop: _drop(imageCount: 4),
          dropRepository: failedFetchRepo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('1/4'), findsNothing);
  });
  testWidgets(
      'Beta3: a portrait Drop is laid out at its own ratio, not cropped '
      'into a square', (tester) async {
    // The defect: Detail forced every photo into AspectRatio(1) with
    // BoxFit.cover, so a 4:5 portrait -- which the feed renders whole
    // -- lost its top and bottom the instant the post was opened.
    final portrait = Drop(
      id: 'd1',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d1_0.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
      imageCount: 1,
      imageWidth: 1080,
      imageHeight: 1350,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropImageGallery(
          drop: portrait,
          dropRepository: singleImageRepo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      ),
    ));
    tester.takeException();

    expect(
      tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
      closeTo(0.8, 0.0001),
    );
  });

  testWidgets(
      'Beta3: a Drop that already carries its image list costs no image '
      'request of its own', (tester) async {
    // The feed batch-loads every multi-image Drop of a page in one
    // query and hands the list down, so opening one of those posts
    // should not ask the server for the same URLs again.
    final withUrls = Drop(
      id: 'd1',
      authorId: 'someone-else',
      authorUsername: 'namfah',
      imageUrl: 'https://example.supabase.co/drops/d1_0.jpg',
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
      imageCount: 3,
      imageUrls: const [
        'https://example.supabase.co/drops/d1_0.jpg',
        'https://example.supabase.co/drops/d1_1.jpg',
        'https://example.supabase.co/drops/d1_2.jpg',
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DropImageGallery(
          drop: withUrls,
          dropRepository: multiImageRepo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      ),
    ));
    tester.takeException();

    expect(multiImageRepo.fetchDropImagesCalls, 0);
    // ...and the carousel is fully built on the first frame, rather
    // than swapping a single image for one a moment later.
    expect(find.text('1/3'), findsOneWidget);
  });

  testWidgets(
      'Beta3: several photos are a row of cards with the next one peeking, '
      'the same row the Home feed shows', (tester) async {
    // Founder, 2026-09-03: "รูปต้องเรียงกันเป็นการ์ดนะ แล้วก็รูปที่ 2 ก็
    // โผล่นิดเดียว". Detail used to be a full-bleed PageView, one photo
    // at a time -- so a post that reads as a card row in the feed
    // became something else entirely the moment you opened it.
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          child: DropImageGallery(
            drop: _drop(imageCount: 3),
            dropRepository: multiImageRepo,
            onLike: () {},
            onDropChanged: (_) {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    tester.takeException();

    // Not a PageView any more.
    expect(find.byType(PageView), findsNothing);
    expect(find.byType(PostImageCarousel), findsOneWidget);

    // Card one occupies 82% of the row, so the next card starts inside
    // the viewport and shows only a sliver of itself -- "โผล่นิดเดียว".
    final cards = tester.widgetList<ClipRRect>(
      find.descendant(
        of: find.byType(PostImageCarousel),
        matching: find.byType(ClipRRect),
      ),
    );
    expect(cards.length, greaterThanOrEqualTo(2));

    final firstCard = tester.getRect(
      find.descendant(
        of: find.byType(PostImageCarousel),
        matching: find.byType(ClipRRect),
      ).first,
    );
    expect(firstCard.width, closeTo(400 * postCardWidthFraction, 0.5));
    // 4:5 portrait card.
    expect(
      firstCard.width / firstCard.height,
      closeTo(postCardAspectRatio, 0.01),
    );
    // The peek: what is left of the row after card one and the gap --
    // a sliver, not a second full photo.
    final peek = 400 - firstCard.width - 8;
    expect(peek, greaterThan(0));
    expect(peek, lessThan(firstCard.width / 3));
  });

}
