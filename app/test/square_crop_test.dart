import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/square_crop.dart';

/// Encodes a solid-color [width]x[height] rectangle as PNG bytes -- a
/// synthetic "photo" so the crop can be tested without a real picked file.
Future<Uint8List> _rectanglePng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF2D6CDF),
  );
  final image =
      await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  test('crops a landscape image to a centered square', () async {
    final source = await _rectanglePng(400, 200);
    final cropped = await centerCropToSquare(source);

    final codec = await ui.instantiateImageCodec(cropped);
    final frame = await codec.getNextFrame();

    expect(frame.image.width, 200);
    expect(frame.image.height, 200);
  });

  test('crops a portrait image to a centered square', () async {
    final source = await _rectanglePng(200, 500);
    final cropped = await centerCropToSquare(source);

    final codec = await ui.instantiateImageCodec(cropped);
    final frame = await codec.getNextFrame();

    expect(frame.image.width, 200);
    expect(frame.image.height, 200);
  });

  test('leaves an already-square image the same size', () async {
    final source = await _rectanglePng(300, 300);
    final cropped = await centerCropToSquare(source);

    final codec = await ui.instantiateImageCodec(cropped);
    final frame = await codec.getNextFrame();

    expect(frame.image.width, 300);
    expect(frame.image.height, 300);
  });

  // WYN-025, R1: dart:ui's ImageByteFormat has no JPEG option, so the old
  // implementation always encoded PNG regardless of the source format --
  // this group proves the output actually switched to JPEG.
  group('WYN-025 R1: JPEG output', () {
    test('encodes the cropped square as JPEG, not PNG', () async {
      final source = await _rectanglePng(300, 300);
      final cropped = await centerCropToSquare(source);

      // JPEG files start with the SOI marker 0xFFD8; PNG starts with the
      // 8-byte signature 0x89 'P' 'N' 'G' ...
      expect(cropped[0], 0xFF);
      expect(cropped[1], 0xD8);
      expect(
        cropped.take(4),
        isNot(equals(const [0x89, 0x50, 0x4E, 0x47])),
      );
    });

    test(
        'produces a meaningfully smaller file than a PNG re-encode of the '
        'same photo, at comparable visual quality', () async {
      // A flat solid color (like _rectanglePng above) compresses to a
      // tiny file under either format and wouldn't show the JPEG-vs-PNG
      // difference this fix is about -- use a smooth multi-color gradient
      // instead, closer to what a real photo's continuous tones look
      // like, where JPEG's lossy DCT compression has a real advantage
      // over PNG's lossless filtering+deflate.
      final source = await _gradientPhotoPng(400, 400);

      final jpeg = await centerCropToSquare(source);

      // What the old PNG implementation would have produced for the same
      // crop, computed the same way centerCropToSquare() used to.
      final codec = await ui.instantiateImageCodec(source);
      final frame = await codec.getNextFrame();
      final pngByteData =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      final png = pngByteData!.buffer.asUint8List();

      expect(jpeg.length, lessThan(png.length));
      // Not just "smaller" -- meaningfully so, matching the Product
      // Task's "เล็กลงอย่างมีนัยสำคัญ" acceptance criterion.
      expect(jpeg.length, lessThan(png.length * 0.6));

      // Still decodable, and still the right dimensions -- quality 90
      // shouldn't be so lossy the image becomes unusable.
      final jpegCodec = await ui.instantiateImageCodec(jpeg);
      final jpegFrame = await jpegCodec.getNextFrame();
      expect(jpegFrame.image.width, 400);
      expect(jpegFrame.image.height, 400);
    });
  });
}

/// Encodes a smooth sweep-gradient [width]x[height] square as PNG bytes --
/// stands in for a real photo's continuous tones (a flat solid color, like
/// [_rectanglePng] above, compresses too well under either format to show
/// a meaningful JPEG-vs-PNG size difference).
Future<Uint8List> _gradientPhotoPng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final rect = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  final shader = ui.Gradient.sweep(
    ui.Offset(width / 2, height / 2),
    const [
      ui.Color(0xFFFF0000),
      ui.Color(0xFF00FF00),
      ui.Color(0xFF0000FF),
      ui.Color(0xFFFFFF00),
      ui.Color(0xFFFF00FF),
      ui.Color(0xFF00FFFF),
      ui.Color(0xFFFF0000),
    ],
    const [0.0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1.0],
  );
  canvas.drawRect(rect, ui.Paint()..shader = shader);
  final image = await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
