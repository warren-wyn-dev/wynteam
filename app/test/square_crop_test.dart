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
}
