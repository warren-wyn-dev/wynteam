import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset, Rect;

/// Pure pan/zoom-to-crop math for [ProfilePhotoCropScreen] (WYN-104). Kept
/// entirely separate from image decoding/rendering (like
/// square_crop.dart/image_dimensions.dart's own split of concerns) so the
/// positioning math itself is unit-testable with plain numbers -- no
/// `ui.instantiateImageCodec`, no widget tree. This matters in this
/// sandbox specifically: decoding real image bytes *through the widget
/// tree* (Image/ImageProvider) hangs under AutomatedTestWidgetsFlutterBinding
/// (see .wyn/company/DECISIONS.md, 2026-09-02, "พบข้อจำกัดใหม่ของ sandbox"),
/// so the crop screen's actual positioning correctness (Acceptance
/// Criterion 2 -- "รูปที่ crop ตรงกับตำแหน่ง/ซูมที่ปรับจริง") is proven
/// here with plain `test()` instead of a `testWidgets()` gesture
/// simulation that would need to render a real decoded image.
///
/// Coordinate model: the crop viewport is a `viewportSize`x`viewportSize`
/// square (the circle preview's bounding box). The picked image is drawn
/// inside it at [scale] (1.0 = the image's shorter side exactly fills the
/// viewport, matching Product spec's "1.0x = fit วงกลมพอดี ไม่ให้ซูมออก
/// จนเห็นขอบว่าง"), with its top-left corner at [offset] relative to the
/// viewport's own top-left. `offset` is always <= 0 on both axes once
/// clamped -- the image is always at least as big as the viewport, so it
/// only ever needs to move up/left to reveal more of itself, never down/
/// right past its own edge.

/// The real pixel dimensions of the picked image, decoded once so the
/// crop screen knows how to fit/center it -- same dart:ui-only shape as
/// drop's `decodeImageDimensions` (app/lib/features/drop/data/
/// image_dimensions.dart), duplicated here rather than imported across
/// features (Profile and Drop are deliberately independent features in
/// this codebase, same posture as edit_profile_screen.dart's own
/// _UsernameStatus doc comment re: not sharing with Auth).
Future<(int width, int height)> decodeCropImageDimensions(
    Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return (frame.image.width, frame.image.height);
}

/// Display pixels of the picked image per one original-image pixel, at
/// zoom level 1.0 -- i.e. the factor that makes the image's shorter
/// dimension exactly equal [viewportSize].
double baseCropScaleFactor({
  required int originalWidth,
  required int originalHeight,
  required double viewportSize,
}) {
  final shorterSide =
      originalWidth < originalHeight ? originalWidth : originalHeight;
  return viewportSize / shorterSide;
}

/// The image's displayed (on-screen) width/height at the given [scale],
/// in the same display-pixel space as [offset]/`viewportSize`.
(double width, double height) cropDisplaySize({
  required int originalWidth,
  required int originalHeight,
  required double viewportSize,
  required double scale,
}) {
  final factor = baseCropScaleFactor(
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        viewportSize: viewportSize,
      ) *
      scale;
  return (originalWidth * factor, originalHeight * factor);
}

/// The offset that centers the image in the viewport at the given
/// [scale] -- the starting position before the user drags, and also
/// what "reset" would return to.
Offset centeredCropOffset({
  required int originalWidth,
  required int originalHeight,
  required double viewportSize,
  required double scale,
}) {
  final (displayWidth, displayHeight) = cropDisplaySize(
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    viewportSize: viewportSize,
    scale: scale,
  );
  return Offset(
    (viewportSize - displayWidth) / 2,
    (viewportSize - displayHeight) / 2,
  );
}

/// Clamps [offset] so the image always fully covers the viewport --
/// dragging can never reveal empty space at any edge (Product spec Edge
/// Case 2's "rubber-band/bounded"), and re-clamps correctly after a
/// zoom change shrinks the valid range.
Offset clampCropOffset({
  required Offset offset,
  required int originalWidth,
  required int originalHeight,
  required double viewportSize,
  required double scale,
}) {
  final (displayWidth, displayHeight) = cropDisplaySize(
    originalWidth: originalWidth,
    originalHeight: originalHeight,
    viewportSize: viewportSize,
    scale: scale,
  );
  // displayWidth/Height are always >= viewportSize (scale >= 1.0), so
  // these mins are always <= 0.
  final minDx = viewportSize - displayWidth;
  final minDy = viewportSize - displayHeight;
  return Offset(
    offset.dx.clamp(minDx, 0.0),
    offset.dy.clamp(minDy, 0.0),
  );
}

/// The square region of the *original* image (in that image's own pixel
/// coordinates, ready to hand straight to `Canvas.drawImageRect`'s
/// `src` rect) that's currently visible inside the crop viewport, given
/// the user's current [scale]/[offset]. This is the function the "done"
/// button's crop math actually depends on -- see [cropToCircleSquare].
Rect computeCropSourceRect({
  required int originalWidth,
  required int originalHeight,
  required double viewportSize,
  required double scale,
  required Offset offset,
}) {
  final factor = baseCropScaleFactor(
        originalWidth: originalWidth,
        originalHeight: originalHeight,
        viewportSize: viewportSize,
      ) *
      scale;
  final left = -offset.dx / factor;
  final top = -offset.dy / factor;
  final side = viewportSize / factor;
  return Rect.fromLTWH(left, top, side, side);
}

/// Crops [bytes] to [sourceRect] (in the source image's own pixel
/// coordinates, e.g. from [computeCropSourceRect]), encoded as PNG.
/// Output is a plain square raster, not a real circle with alpha --
/// deliberately, per Product spec's "ป้องกันปัญหาพื้นหลังโปร่งใสไม่
/// รองรับทุกที่ที่ใช้รูปนี้" (the circle is a visual clip wherever
/// avatars render, same as it already was before this task). Same
/// dart:ui-only approach as [square_crop.dart]'s `centerCropToSquare` --
/// no extra image-processing package.
Future<Uint8List> cropToCircleSquare({
  required Uint8List bytes,
  required Rect sourceRect,
}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;

  // Defensive clamp against floating-point rounding at the extremes of
  // pan/zoom (e.g. panned all the way to an edge) -- computeCropSourceRect
  // should already keep this within bounds, but a source rect that spills
  // even a fraction of a pixel past the real image extent is worth
  // guarding against explicitly rather than trusting upstream math alone.
  final maxLeft = (image.width - sourceRect.width).clamp(0.0, double.infinity);
  final maxTop = (image.height - sourceRect.height).clamp(0.0, double.infinity);
  final clampedRect = ui.Rect.fromLTWH(
    sourceRect.left.clamp(0.0, maxLeft),
    sourceRect.top.clamp(0.0, maxTop),
    sourceRect.width,
    sourceRect.height,
  );

  final side = sourceRect.width.round();
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    clampedRect,
    ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    ui.Paint(),
  );

  final cropped = await recorder.endRecording().toImage(side, side);
  final byteData = await cropped.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
