import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:wyn/features/drop/data/image_dimensions.dart';

/// Same synthetic-PNG fixture as square_crop_test.dart's identically
/// named helper -- a solid-color WxH rectangle so this can be tested
/// without a real picked file.
Future<Uint8List> _rectanglePng(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF2D6CDF),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void main() {
  test('WYN-093: reports the exact width/height of a landscape image',
      () async {
    final bytes = await _rectanglePng(1600, 900);
    final (width, height) = await decodeImageDimensions(bytes);
    expect(width, 1600);
    expect(height, 900);
  });

  test('WYN-093: reports the exact width/height of a portrait image',
      () async {
    final bytes = await _rectanglePng(900, 1600);
    final (width, height) = await decodeImageDimensions(bytes);
    expect(width, 900);
    expect(height, 1600);
  });

  test('WYN-093: reports the exact width/height of a square image',
      () async {
    final bytes = await _rectanglePng(500, 500);
    final (width, height) = await decodeImageDimensions(bytes);
    expect(width, 500);
    expect(height, 500);
  });
}
