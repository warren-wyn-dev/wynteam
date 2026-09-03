import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/core/widgets/network_thumbnail.dart';

void main() {
  group('decodeWidthFor', () {
    test('scales the painted width by the device pixel ratio', () {
      // A 3-column grid tile on a 390px-wide phone at 3x.
      expect(decodeWidthFor(130, devicePixelRatio: 3), 390);
    });

    test('a 1x screen decodes at the logical width', () {
      expect(decodeWidthFor(130, devicePixelRatio: 1), 130);
    });

    test('rounds rather than truncating', () {
      expect(decodeWidthFor(130.4, devicePixelRatio: 2.75), 359);
    });

    test('returns null for an unbounded width, so the image decodes at '
        'full size exactly as it did before', () {
      expect(decodeWidthFor(double.infinity, devicePixelRatio: 3), isNull);
    });

    test('returns null for a zero or negative width', () {
      expect(decodeWidthFor(0, devicePixelRatio: 3), isNull);
      expect(decodeWidthFor(-5, devicePixelRatio: 3), isNull);
    });

    test('never asks for a 0-wide decode on a sub-pixel box', () {
      expect(decodeWidthFor(0.1, devicePixelRatio: 1), 1);
    });

    test('maxLogicalWidth caps a box that is wider than the image needs '
        'to be sharp at', () {
      expect(decodeWidthFor(400, devicePixelRatio: 2, maxLogicalWidth: 100),
          200);
    });

    test('maxLogicalWidth does not upscale a box narrower than the cap', () {
      expect(decodeWidthFor(50, devicePixelRatio: 2, maxLogicalWidth: 100),
          100);
    });
  });

  group('NetworkThumbnail', () {
    testWidgets('decodes at the size the tile is actually painted at, not '
        'the size the photo was uploaded at', (tester) async {
      await tester.pumpWidget(const MediaQuery(
        data: MediaQueryData(devicePixelRatio: 2),
        child: Directionality(
          textDirection: TextDirection.ltr,
          // Centered so the SizedBox actually gets to pick its own size
          // -- the root view hands its child tight screen-sized
          // constraints, which a bare SizedBox has to obey.
          child: Center(
            child: SizedBox(
              width: 120,
              height: 120,
              child: NetworkThumbnail(
                imageUrl: 'https://example.supabase.co/drop-images/a.jpg',
              ),
            ),
          ),
        ),
      ));
      tester.takeException();

      expect(tester.widget<Image>(find.byType(Image)).width, isNull);
      final image = tester.widget<Image>(find.byType(Image)).image;
      expect(image, isA<ResizeImage>());
      expect((image as ResizeImage).width, 240);
    });

    testWidgets('shows a broken-image icon when the load fails, rather than '
        'an empty hole in the grid', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 120,
            height: 120,
            child: NetworkThumbnail(
              imageUrl: 'https://example.supabase.co/drop-images/missing.jpg',
            ),
          ),
        ),
      ));

      await tester.pump();
      tester.takeException();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });
  });
}
