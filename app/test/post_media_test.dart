import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/post_media.dart';

void main() {
  group('postImageAspectRatio', () {
    test('returns a photo\'s own ratio when it is inside the bounds', () {
      // A plain 3:2 landscape and a 4:5 portrait both render whole.
      expect(postImageAspectRatio(3000, 2000), closeTo(1.5, 0.0001));
      expect(postImageAspectRatio(1080, 1350), closeTo(0.8, 0.0001));
    });

    test('clamps a photo more portrait than 4:5 to 4:5', () {
      // A 9:16 phone-screenshot shape (0.5625) would otherwise be tall
      // enough to fill a whole viewport on its own.
      expect(postImageAspectRatio(1080, 1920), minPostImageAspectRatio);
    });

    test('clamps a photo more landscape than 1.91:1 to 1.91:1', () {
      expect(postImageAspectRatio(3000, 500), maxPostImageAspectRatio);
    });

    test('falls back to a square when the dimensions are not known', () {
      // Every Drop uploaded before WYN-093 added these columns.
      expect(postImageAspectRatio(null, null), 1);
      expect(postImageAspectRatio(1080, null), 1);
      expect(postImageAspectRatio(null, 1080), 1);
    });

    test('falls back to a square rather than dividing by a bad dimension', () {
      expect(postImageAspectRatio(1080, 0), 1);
      expect(postImageAspectRatio(1080, -5), 1);
      expect(postImageAspectRatio(0, 1080), 1);
    });
  });

  group('PostImageFrame', () {
    testWidgets('lays a portrait photo out at its own ratio, not a square',
        (tester) async {
      // The Beta3 defect this exists to catch: Drop Detail used to
      // render every photo into AspectRatio(1) with BoxFit.cover, so a
      // 4:5 portrait lost its top and bottom on the one screen whose
      // job is showing it.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostImageFrame(
            imageUrl: 'https://example.supabase.co/drops/portrait.jpg',
            imageWidth: 1080,
            imageHeight: 1350,
          ),
        ),
      ));
      tester.takeException();

      final aspectRatio =
          tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio;
      expect(aspectRatio, closeTo(0.8, 0.0001));
    });

    testWidgets('never lets a photo grow past its share of the viewport',
        (tester) async {
      // 600 logical pixels tall by default in flutter_test; a 4:5
      // portrait at the full 800 width would want 1000.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: PostImageFrame(
            imageUrl: 'https://example.supabase.co/drops/portrait.jpg',
            imageWidth: 1080,
            imageHeight: 1350,
            maxHeightFraction: 0.75,
          ),
        ),
      ));
      tester.takeException();

      expect(
        tester.getSize(find.byType(AspectRatio)).height,
        lessThanOrEqualTo(0.75 * 600),
      );
    });
  });

  group('PostImage', () {
    testWidgets('decodes to the size it is painted at, not the size it was '
        'uploaded at', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            height: 390,
            child: PostImage(
              imageUrl: 'https://example.supabase.co/drops/d1.jpg',
            ),
          ),
        ),
      ));
      tester.takeException();

      // 390 logical pixels at the test environment's DPR of 3 -- a
      // memory bound, never a sharpness tradeoff: the photo is still
      // decoded at full physical resolution for the box it lands in.
      // Without it a 1600x1600 upload decodes in full regardless,
      // ~10MB of bitmap per photo, several photos alive at once in a
      // feed.
      final devicePixelRatio =
          tester.view.devicePixelRatio;
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as ResizeImage).width,
        (390 * devicePixelRatio).round(),
      );
    });
  });
}
