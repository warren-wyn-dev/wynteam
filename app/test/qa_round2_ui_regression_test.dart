// QA round 2 (2026-09-04) -- written by AI QA & Security.
//
// The permanent regression tests that shipped with the four round-1
// fixes assert on the *text* of the source files (`source.contains(...)`)
// rather than on what the app draws. That catches a literal revert and
// nothing else: rename `_previewWidth`, or make it return 128 always,
// and those tests still pass while the defect is back. These measure
// what is actually rendered instead.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wyn/core/design/wyn_colors.dart';
import 'package:wyn/core/widgets/post_media.dart';
import 'package:wyn/core/widgets/wyn_heart_icon.dart';
import 'package:wyn/features/drop/data/drop.dart';
import 'package:wyn/features/drop/data/square_crop.dart';
import 'package:wyn/features/drop/presentation/widgets/drop_image_gallery.dart';
import 'package:wyn/features/home/data/home_feed_item.dart';
import 'package:wyn/features/home/presentation/widgets/home_explainer_banner.dart';
import 'package:wyn/features/home/presentation/widgets/home_drop_card.dart';
import 'package:wyn/features/home/presentation/widgets/home_feed_image_peek_carousel.dart';

import 'support/recording_drop_repository.dart';

Drop _drop({
  required int imageCount,
  DropAspectRatio aspectRatio = DropAspectRatio.portrait,
  int? imageWidth,
  int? imageHeight,
}) =>
    Drop(
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
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      aspectRatio: aspectRatio,
    );

HomeFeedItem _item({
  required DropAspectRatio aspectRatio,
  int imageCount = 3,
  int? imageWidth,
  int? imageHeight,
}) =>
    HomeFeedItem(
      id: 'd1',
      contentType: HomeContentType.drop,
      authorId: 'someone-else',
      authorUsername: 'namfah',
      createdAt: DateTime.now(),
      caption: 'hello',
      imageUrl: 'https://example.supabase.co/drops/d1_0.jpg',
      likeCount: 0,
      commentCount: 0,
      likedByMe: false,
      savedByMe: false,
      imageCount: imageCount,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      aspectRatio: aspectRatio,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(body: child),
    ),
  ));
}

void main() {
  late RecordingDropRepository repo;

  setUp(() {
    repo = RecordingDropRepository()
      ..dropImagesById = {
        'd1': [
          'https://example.supabase.co/drops/d1_0.jpg',
          'https://example.supabase.co/drops/d1_1.jpg',
          'https://example.supabase.co/drops/d1_2.jpg',
        ],
      };
  });

  // -----------------------------------------------------------------
  // B-109-2: the feed and the post must draw the same shape.
  // -----------------------------------------------------------------

  group('B-109-2 one post, one shape', () {
    for (final (name, ratio, expected) in <(String, DropAspectRatio, double)>[
      ('16:9', DropAspectRatio.landscape, 16 / 9),
      ('1:1', DropAspectRatio.square, 1.0),
      ('4:5', DropAspectRatio.portrait, 0.8),
    ]) {
      testWidgets('QA-R2-15 a $name post opens at $name, not 4:5',
          (tester) async {
        await _pump(
          tester,
          DropImageGallery(
            drop: _drop(imageCount: 3, aspectRatio: ratio),
            dropRepository: repo,
            onLike: () {},
            onDropChanged: (_) {},
          ),
        );
        await tester.pump();
        tester.takeException();

        final carousel = tester.widget<PostImageCarousel>(
          find.byType(PostImageCarousel),
        );
        expect(carousel.aspectRatio, closeTo(expected, 0.0001));
      });
    }

    testWidgets(
        'QA-R2-16 the feed carousel and the detail gallery agree exactly',
        (tester) async {
      await _pump(
        tester,
        HomeFeedImagePeekCarousel(
          item: _item(aspectRatio: DropAspectRatio.landscape),
          dropRepository: repo,
          onLike: () {},
        ),
      );
      await tester.pump();
      tester.takeException();
      final feedRatio = tester
          .widget<PostImageCarousel>(find.byType(PostImageCarousel))
          .aspectRatio;

      await _pump(
        tester,
        DropImageGallery(
          drop: _drop(imageCount: 3, aspectRatio: DropAspectRatio.landscape),
          dropRepository: repo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      );
      await tester.pump();
      tester.takeException();
      final detailRatio = tester
          .widget<PostImageCarousel>(find.byType(PostImageCarousel))
          .aspectRatio;

      expect(detailRatio, feedRatio);
      expect(detailRatio, closeTo(16 / 9, 0.0001));
    });

    testWidgets(
        'QA-R2-17 "ต้นฉบับ" falls back to the file\'s own shape in both '
        'places, not to a constant', (tester) async {
      // 1200x675 = 16:9 file posted as "original".
      await _pump(
        tester,
        DropImageGallery(
          drop: _drop(
            imageCount: 3,
            aspectRatio: DropAspectRatio.original,
            imageWidth: 1200,
            imageHeight: 675,
          ),
          dropRepository: repo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      );
      await tester.pump();
      tester.takeException();
      final detail = tester
          .widget<PostImageCarousel>(find.byType(PostImageCarousel))
          .aspectRatio;

      await _pump(
        tester,
        HomeFeedImagePeekCarousel(
          item: _item(
            aspectRatio: DropAspectRatio.original,
            imageWidth: 1200,
            imageHeight: 675,
          ),
          dropRepository: repo,
          onLike: () {},
        ),
      );
      await tester.pump();
      tester.takeException();
      final feed = tester
          .widget<PostImageCarousel>(find.byType(PostImageCarousel))
          .aspectRatio;

      expect(detail, feed);
      expect(detail, closeTo(postImageAspectRatio(1200, 675), 0.0001));
      expect(detail, isNot(closeTo(postCardAspectRatio, 0.0001)));
    });

    testWidgets(
        'QA-R2-18 a pre-WYN-109 post (no stored ratio, no dimensions) '
        'still draws exactly 4:5', (tester) async {
      await _pump(
        tester,
        DropImageGallery(
          drop: _drop(imageCount: 3), // aspectRatio defaults to portrait
          dropRepository: repo,
          onLike: () {},
          onDropChanged: (_) {},
        ),
      );
      await tester.pump();
      tester.takeException();
      expect(
        tester
            .widget<PostImageCarousel>(find.byType(PostImageCarousel))
            .aspectRatio,
        closeTo(postCardAspectRatio, 0.0001),
      );
    });
  });

  // -----------------------------------------------------------------
  // WYN-106 / WYN-107 / WYN-108 regressions re-measured.
  // -----------------------------------------------------------------

  testWidgets('QA-R2-19 WYN-106: the banner close button is still 44x44',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pump(tester, const HomeExplainerBanner(), size: const Size(360, 800));
    await tester.pumpAndSettle();

    final button = find.ancestor(
      of: find.byIcon(Icons.close),
      matching: find.byType(InkWell),
    );
    expect(button, findsOneWidget);
    final rect = tester.getRect(button);
    expect(rect.width, greaterThanOrEqualTo(44.0));
    expect(rect.height, greaterThanOrEqualTo(44.0));
    // The visible icon itself must not have grown with the hit box.
    expect(tester.widget<Icon>(find.byIcon(Icons.close)).size, 15.0);
    // ...and the hit box must not steal taps from the banner text.
    final text = tester.getRect(find.textContaining('WYN').first);
    expect(text.right, lessThanOrEqualTo(rect.left));
  });

  testWidgets(
      'QA-R2-20 WYN-108: a liked heart is still #F44336 and an idle one '
      'is still graphite -- neither reverted to sapphire', (tester) async {
    await _pump(
      tester,
      const Column(children: [
        WynHeartIcon(filled: true, size: 24, color: WynColors.iconLikeActive),
        WynHeartIcon(filled: false, size: 24, color: WynColors.iconIdle),
      ]),
    );
    final hearts =
        tester.widgetList<WynHeartIcon>(find.byType(WynHeartIcon)).toList();
    expect(hearts.first.color, const Color(0xFFF44336));
    expect(hearts.first.color, isNot(WynColors.sapphire));
    expect(hearts.last.color, WynColors.iconIdle);
  });

  testWidgets(
      'QA-R2-21 WYN-107: the Home card still opens its content column at '
      'x=78 on a 390 screen and the photo row still bleeds to the edge',
      (tester) async {
    await _pump(
      tester,
      HomeDropCard(
        item: _item(aspectRatio: DropAspectRatio.portrait, imageCount: 3),
        dropRepository: repo,
        onTap: () {},
        onToggleLike: () {},
        onToggleSave: () {},
        onOpenProfile: () {},
        onToggleRedrop: () {},
        onQuoteRedrop: () {},
        showViewCount: false,
      ),
    );
    await tester.pump();
    tester.takeException();

    final row = tester.getRect(find.byType(PostImageCarousel));
    expect(row.left, closeTo(78.0, 0.5));
    expect(row.right, closeTo(390.0, 0.5));
  });

  // -----------------------------------------------------------------
  // Responsive: 320/360/390/430 x textScale 1.0/1.3, with the shapes
  // WYN-109 newly makes possible.
  // -----------------------------------------------------------------

  for (final width in const [320.0, 360.0, 390.0, 430.0]) {
    for (final scale in const [1.0, 1.3]) {
      for (final ratio in DropAspectRatio.values) {
        testWidgets(
            'QA-R2-22 HomeDropCard at ${width.toInt()} x $scale, '
            '${ratio.wireValue}: no overflow', (tester) async {
          await _pump(
            tester,
            SingleChildScrollView(
              child: HomeDropCard(
                item: _item(aspectRatio: ratio, imageCount: 3),
                dropRepository: repo,
                onTap: () {},
                onToggleLike: () {},
                onToggleSave: () {},
                onOpenProfile: () {},
                onToggleRedrop: () {},
                onQuoteRedrop: () {},
                showViewCount: false,
              ),
            ),
            size: Size(width, 900),
            textScale: scale,
          );
          await tester.pump();
          final errors = tester.takeException();
          expect(
            errors?.toString() ?? '',
            isNot(contains('overflowed')),
          );
        });
      }
    }
  }
}
