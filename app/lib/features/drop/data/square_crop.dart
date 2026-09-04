import 'dart:typed_data';
import 'dart:ui' as ui;

/// The aspect ratios a Drop's photos can be posted at -- WYN-109.
///
/// Before this, every photo posted through the app was silently
/// center-cropped to a square on upload and then cropped a second time
/// by the feed's 4:5 card row, and the poster controlled neither cut.
/// Founder, 2026-09-04: "อยากให้โพสรูป ได้หลายอัตราส่วน" and, on whether a
/// post's photos may differ from each other, "อัตราส่วน 4:5 เท่ากัน" --
/// hence one ratio for the whole post, defaulting to the one the feed
/// already draws.
///
/// The wire values are what the `drops.image_aspect_ratio` column's
/// CHECK constraint admits, so this enum and that constraint have to be
/// changed together.
enum DropAspectRatio {
  /// Keep the photo's own shape. The feed already knows how to render
  /// this (WYN-093 clamps a photo to between 4:5 and 1.91:1) -- it just
  /// never saw one, because everything arrived square.
  original('original', null),
  square('1:1', 1),
  portrait('4:5', 4 / 5),
  landscape('16:9', 16 / 9);

  const DropAspectRatio(this.wireValue, this.ratio);

  /// The value stored in `drops.image_aspect_ratio`.
  final String wireValue;

  /// Width over height, or null for [original], which has no single
  /// value -- it is whatever the photo already is.
  final double? ratio;

  /// What the poster chose, from a stored row. Null (a Drop posted
  /// before WYN-109) reads as [portrait]: those photos are squares
  /// rendered in a 4:5 card, which is what they will keep looking like.
  /// An unrecognised value is treated the same way rather than throwing
  /// -- a feed that fails to render because of one unexpected string is
  /// worse than one that shows the photo at the shape it already had.
  static DropAspectRatio fromWire(String? value) => values.firstWhere(
        (r) => r.wireValue == value,
        orElse: () => DropAspectRatio.portrait,
      );

  /// The default for a new post.
  static const DropAspectRatio initial = DropAspectRatio.portrait;
}

/// Center-crops [bytes] to [aspectRatio] (width over height), encoded as
/// PNG. Takes the largest region of that shape that fits inside the
/// image, centered -- so nothing is ever scaled up and no edge is ever
/// left empty.
///
/// This is the fallback for a photo the poster did not open the cropper
/// for. When they did, the cropper's own region wins (see
/// `cropToSourceRect`); this only decides what happens when they said
/// nothing.
Future<Uint8List> centerCropToRatio(
  Uint8List bytes,
  double aspectRatio,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  // Fit the target shape inside the source: bounded by width for a
  // frame wider than the photo, by height otherwise.
  var cropWidth = image.width.toDouble();
  var cropHeight = cropWidth / aspectRatio;
  if (cropHeight > image.height) {
    cropHeight = image.height.toDouble();
    cropWidth = cropHeight * aspectRatio;
  }

  final srcLeft = (image.width - cropWidth) / 2;
  final srcTop = (image.height - cropHeight) / 2;
  final outWidth = cropWidth.round();
  final outHeight = cropHeight.round();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    ui.Rect.fromLTWH(srcLeft, srcTop, cropWidth, cropHeight),
    ui.Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
    ui.Paint(),
  );

  final cropped =
      await recorder.endRecording().toImage(outWidth, outHeight);
  final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// Center-crops [bytes] to a square, encoded as PNG.
///
/// Kept as the 1:1 case of [centerCropToRatio] rather than deleted: it
/// is what this file was, it is still exactly what a poster who picks
/// "1:1" asks for, and its own tests describe the behaviour every other
/// ratio is now measured against.
Future<Uint8List> centerCropToSquare(Uint8List bytes) =>
    centerCropToRatio(bytes, 1);
