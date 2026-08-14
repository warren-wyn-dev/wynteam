import 'dart:typed_data';
import 'dart:ui' as ui;

/// Center-crops [bytes] to a square, encoded as PNG. No interactive
/// drag-to-reposition in this V0.1 round -- a deliberately scoped-down
/// first version (see .wyn/docs/design/wyn-005-drop.md, Screen 2 Design
/// Rules) rather than a missing feature. Uses only dart:ui (no extra
/// image-processing package).
Future<Uint8List> centerCropToSquare(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  final side = image.width < image.height ? image.width : image.height;
  final srcLeft = (image.width - side) / 2;
  final srcTop = (image.height - side) / 2;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(srcLeft, srcTop, side.toDouble(), side.toDouble()),
    ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    ui.Paint(),
  );

  final cropped = await recorder.endRecording().toImage(side, side);
  final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
