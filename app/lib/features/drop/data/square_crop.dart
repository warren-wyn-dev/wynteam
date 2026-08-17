import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

/// JPEG quality used for the cropped square -- high enough to keep detail
/// sharp (per the Founder's brief) while still being meaningfully smaller
/// than a PNG re-encode of the same photo. See
/// .wyn/docs/design/wyn-025-drop-composer-polish.md, R1.
const _croppedJpegQuality = 90;

/// Center-crops [bytes] to a square, encoded as JPEG. No interactive
/// drag-to-reposition in this V0.1 round -- a deliberately scoped-down
/// first version (see .wyn/docs/design/wyn-005-drop.md, Screen 2 Design
/// Rules) rather than a missing feature.
///
/// The crop itself still uses dart:ui's Canvas (no extra package needed
/// for that part) -- only the final encode step uses package:image,
/// because dart:ui's ImageByteFormat has no JPEG option (only
/// png/rawRgba/rawStraightRgba/rawUnmodified). See WYN-025, R1.
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
  final byteData =
      await cropped.toByteData(format: ui.ImageByteFormat.rawRgba);
  final rgbaBytes = byteData!.buffer.asUint8List();

  final decoded = img.Image.fromBytes(
    width: side,
    height: side,
    bytes: rgbaBytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(decoded, quality: _croppedJpegQuality);
}
