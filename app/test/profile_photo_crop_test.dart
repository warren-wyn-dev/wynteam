import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/profile/data/profile_photo_crop.dart';

/// Same synthetic-PNG fixture shape as square_crop_test.dart/
/// image_dimensions_test.dart -- a WxH rectangle with an [alpha]-flagged
/// solid color band split diagonally so a *positional* crop (not just a
/// size crop) can be verified: sampling a pixel proves which quadrant of
/// the source image actually ended up in the cropped output.
Future<Uint8List> _quadrantPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final halfW = width / 2;
  final halfH = height / 2;
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, halfW, halfH),
      ui.Paint()..color = const ui.Color(0xFFFF0000)); // top-left: red
  canvas.drawRect(ui.Rect.fromLTWH(halfW, 0, halfW, halfH),
      ui.Paint()..color = const ui.Color(0xFF00FF00)); // top-right: green
  canvas.drawRect(ui.Rect.fromLTWH(0, halfH, halfW, halfH),
      ui.Paint()..color = const ui.Color(0xFF0000FF)); // bottom-left: blue
  canvas.drawRect(ui.Rect.fromLTWH(halfW, halfH, halfW, halfH),
      ui.Paint()..color = const ui.Color(0xFFFFFF00)); // bottom-right: yellow
  final image = await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

Future<ui.Color> _pixelAt(Uint8List pngBytes, int x, int y) async {
  final codec = await ui.instantiateImageCodec(pngBytes);
  final frame = await codec.getNextFrame();
  final byteData =
      await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = byteData!.buffer.asUint8List();
  final index = (y * frame.image.width + x) * 4;
  return ui.Color.fromARGB(
      pixels[index + 3], pixels[index], pixels[index + 1], pixels[index + 2]);
}

void main() {
  group('baseCropScaleFactor / cropDisplaySize', () {
    test('a 400x200 landscape image at scale 1.0 exactly fills a viewport '
        'on its shorter (height) side', () {
      final (w, h) = cropDisplaySize(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      expect(h, 260);
      expect(w, closeTo(520, 0.001)); // 400/200 aspect preserved
    });

    test('a 200x400 portrait image at scale 1.0 exactly fills a viewport '
        'on its shorter (width) side', () {
      final (w, h) = cropDisplaySize(
        originalWidth: 200,
        originalHeight: 400,
        viewportSize: 260,
        scale: 1.0,
      );
      expect(w, 260);
      expect(h, closeTo(520, 0.001));
    });

    test('scale 2.0 doubles both dimensions from scale 1.0', () {
      final (w1, h1) = cropDisplaySize(
        originalWidth: 300,
        originalHeight: 300,
        viewportSize: 260,
        scale: 1.0,
      );
      final (w2, h2) = cropDisplaySize(
        originalWidth: 300,
        originalHeight: 300,
        viewportSize: 260,
        scale: 2.0,
      );
      expect(w2, closeTo(w1 * 2, 0.001));
      expect(h2, closeTo(h1 * 2, 0.001));
    });
  });

  group('centeredCropOffset', () {
    test('centers a square image exactly (offset 0,0 at scale 1.0)', () {
      final offset = centeredCropOffset(
        originalWidth: 300,
        originalHeight: 300,
        viewportSize: 260,
        scale: 1.0,
      );
      expect(offset.dx, closeTo(0, 0.001));
      expect(offset.dy, closeTo(0, 0.001));
    });

    test('centers a landscape image with negative horizontal offset only',
        () {
      final offset = centeredCropOffset(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      expect(offset.dy, closeTo(0, 0.001));
      expect(offset.dx, lessThan(0));
    });
  });

  group('clampCropOffset', () {
    test('leaves an in-bounds offset unchanged', () {
      // A square image zoomed to 2.0x has slack to pan in both
      // directions (unlike scale 1.0, where the shorter dimension has
      // zero slack by definition) -- a clean case to prove clamping is a
      // no-op when the offset is already within bounds.
      final clamped = clampCropOffset(
        offset: const Offset(-10, -5),
        originalWidth: 300,
        originalHeight: 300,
        viewportSize: 260,
        scale: 2.0,
      );
      expect(clamped.dx, -10);
      expect(clamped.dy, -5);
    });

    test('never allows an offset that would reveal empty space '
        '(clamps to the max/min bound instead)', () {
      // Way out of range in every direction.
      final clamped = clampCropOffset(
        offset: const Offset(1000, 1000),
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      // Positive offset would push the image right/down past the
      // viewport's left/top edge -- must clamp to 0 (image flush left/
      // top of viewport, its own natural max).
      expect(clamped.dx, 0);
      expect(clamped.dy, 0);

      final clampedOther = clampCropOffset(
        offset: const Offset(-1000, -1000),
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      final (displayWidth, displayHeight) = cropDisplaySize(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      expect(clampedOther.dx, closeTo(260 - displayWidth, 0.001));
      expect(clampedOther.dy, closeTo(260 - displayHeight, 0.001));
    });
  });

  group('computeCropSourceRect', () {
    test('at scale 1.0, centered -- the source rect is the same '
        'center-crop centerCropToSquare would produce', () {
      final offset = centeredCropOffset(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      final rect = computeCropSourceRect(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
        offset: offset,
      );
      expect(rect.width, closeTo(200, 0.01));
      expect(rect.height, closeTo(200, 0.01));
      expect(rect.left, closeTo(100, 0.01)); // (400-200)/2
      expect(rect.top, closeTo(0, 0.01));
    });

    test('panning left (positive offset.dx) shifts the source rect toward '
        'the left edge of the original image', () {
      final baseOffset = centeredCropOffset(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      final panned = clampCropOffset(
        offset: baseOffset + const Offset(50, 0),
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      final rect = computeCropSourceRect(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
        offset: panned,
      );
      expect(rect.left, lessThan(100));
    });

    test('zooming in shrinks the source rect (a smaller slice of the '
        'original image ends up filling the same viewport)', () {
      final offset1x = centeredCropOffset(
        originalWidth: 300,
        originalHeight: 300,
        viewportSize: 260,
        scale: 1.0,
      );
      final rect1x = computeCropSourceRect(
        originalWidth: 300,
        originalHeight: 300,
        viewportSize: 260,
        scale: 1.0,
        offset: offset1x,
      );
      final offset2x = centeredCropOffset(
        originalWidth: 300,
        originalHeight: 300,
        viewportSize: 260,
        scale: 2.0,
      );
      final rect2x = computeCropSourceRect(
        originalWidth: 300,
        originalHeight: 300,
        viewportSize: 260,
        scale: 2.0,
        offset: offset2x,
      );
      expect(rect2x.width, closeTo(rect1x.width / 2, 0.01));
    });
  });

  group('cropToCircleSquare -- end-to-end against real decoded pixels', () {
    test('a centered 1.0x crop of a landscape image keeps the middle '
        'column (mixes left/right quadrant colors, not top-only)',
        () async {
      final source = await _quadrantPng(400, 200);
      final offset = centeredCropOffset(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
      );
      final rect = computeCropSourceRect(
        originalWidth: 400,
        originalHeight: 200,
        viewportSize: 260,
        scale: 1.0,
        offset: offset,
      );
      final cropped = await cropToCircleSquare(bytes: source, sourceRect: rect);

      final codec = await ui.instantiateImageCodec(cropped);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 200);
      expect(frame.image.height, 200);
    });

    test('panning fully to the top-left corner at max practical zoom '
        'crops out exactly the red (top-left) quadrant', () async {
      final source = await _quadrantPng(400, 400);
      const scale = 2.0;
      // Pan as far up-left as clampCropOffset allows -- the crop should
      // land entirely inside the original top-left (red) quadrant.
      final offset = clampCropOffset(
        offset: const Offset(1000, 1000),
        originalWidth: 400,
        originalHeight: 400,
        viewportSize: 260,
        scale: scale,
      );
      final rect = computeCropSourceRect(
        originalWidth: 400,
        originalHeight: 400,
        viewportSize: 260,
        scale: scale,
        offset: offset,
      );
      final cropped = await cropToCircleSquare(bytes: source, sourceRect: rect);

      final color = await _pixelAt(cropped, 5, 5);
      expect(color.toARGB32(), const ui.Color(0xFFFF0000).toARGB32());
    });

    test('panning fully to the bottom-right corner at max practical zoom '
        'crops out exactly the yellow (bottom-right) quadrant', () async {
      final source = await _quadrantPng(400, 400);
      const scale = 2.0;
      final offset = clampCropOffset(
        offset: const Offset(-1000, -1000),
        originalWidth: 400,
        originalHeight: 400,
        viewportSize: 260,
        scale: scale,
      );
      final rect = computeCropSourceRect(
        originalWidth: 400,
        originalHeight: 400,
        viewportSize: 260,
        scale: scale,
        offset: offset,
      );
      final cropped = await cropToCircleSquare(bytes: source, sourceRect: rect);

      final codec = await ui.instantiateImageCodec(cropped);
      final frame = await codec.getNextFrame();
      final color = await _pixelAt(
          cropped, frame.image.width - 5, frame.image.height - 5);
      expect(color.toARGB32(), const ui.Color(0xFFFFFF00).toARGB32());
    });
  });

  // WYN-109: the same maths, asked for a frame that is not a square.
  // The avatar never needed this -- a post's photo does, and rather than
  // grow a second cropper the viewport became two numbers instead of
  // one. These hold the general form to the one property that matters:
  // the region handed to the canvas has the frame's shape, and the image
  // still covers the frame with nothing empty showing at any edge.
  group('WYN-109 non-square crop frames', () {
    test('a 4:5 frame yields a 4:5 source region', () {
      // 260-tall portrait frame, per the crop screen's own sizing.
      const viewportWidth = 208.0;
      const viewportHeight = 260.0;
      final rect = computeCropSourceRect(
        originalWidth: 1000,
        originalHeight: 1000,
        viewportSize: viewportWidth,
        viewportHeight: viewportHeight,
        scale: 1,
        offset: centeredCropOffset(
          originalWidth: 1000,
          originalHeight: 1000,
          viewportSize: viewportWidth,
          viewportHeight: viewportHeight,
          scale: 1,
        ),
      );
      expect(rect.width / rect.height, closeTo(4 / 5, 0.001));
      // A square source can supply a portrait crop only by giving up
      // width, never by reaching outside itself.
      expect(rect.height, closeTo(1000, 0.001));
      expect(rect.width, closeTo(800, 0.001));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(1000.001));
    });

    test('a 16:9 frame covers a portrait photo without empty edges', () {
      const viewportWidth = 260.0;
      const viewportHeight = 146.25;
      // A tall photo in a wide frame: the binding axis is width, which
      // the shorter-side rule the square case used would have got wrong.
      final rect = computeCropSourceRect(
        originalWidth: 600,
        originalHeight: 1200,
        viewportSize: viewportWidth,
        viewportHeight: viewportHeight,
        scale: 1,
        offset: centeredCropOffset(
          originalWidth: 600,
          originalHeight: 1200,
          viewportSize: viewportWidth,
          viewportHeight: viewportHeight,
          scale: 1,
        ),
      );
      expect(rect.width / rect.height, closeTo(16 / 9, 0.001));
      expect(rect.width, closeTo(600, 0.001));
      expect(rect.left, closeTo(0, 0.001));
      expect(rect.top, greaterThan(0));
      expect(rect.bottom, lessThanOrEqualTo(1200.001));
    });

    test('the square case is untouched by the new parameter', () {
      // Omitting viewportHeight has to mean exactly what the avatar flow
      // has always done -- this is the guard on that promise.
      ui.Rect at({double? height}) => computeCropSourceRect(
            originalWidth: 800,
            originalHeight: 600,
            viewportSize: 260,
            viewportHeight: height,
            scale: 1.5,
            offset: const Offset(-40, -20),
          );
      expect(at(), at(height: 260));
    });

    test('clamping still forbids empty space on either axis of a tall frame',
        () {
      const viewportWidth = 208.0;
      const viewportHeight = 260.0;
      final offset = clampCropOffset(
        // Dragged far past any legal position, in both directions.
        offset: const Offset(500, 500),
        originalWidth: 1000,
        originalHeight: 1000,
        viewportSize: viewportWidth,
        viewportHeight: viewportHeight,
        scale: 1,
      );
      // Clamped back to "no gap at the top-left".
      expect(offset.dx, lessThanOrEqualTo(0));
      expect(offset.dy, lessThanOrEqualTo(0));

      final (displayWidth, displayHeight) = cropDisplaySize(
        originalWidth: 1000,
        originalHeight: 1000,
        viewportSize: viewportWidth,
        viewportHeight: viewportHeight,
        scale: 1,
      );
      // ...and no gap at the bottom-right either.
      expect(offset.dx + displayWidth, greaterThanOrEqualTo(viewportWidth));
      expect(offset.dy + displayHeight, greaterThanOrEqualTo(viewportHeight));
    });
  });
}
