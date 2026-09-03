import 'package:flutter/material.dart';

/// Decodes [imageUrl] at the size it is actually painted at, instead of
/// at the size it was uploaded at.
///
/// Wynos compresses every uploaded photo to 1600x1600 (WYN-103), which
/// is right for Detail and the feed's hero image -- but a 3-column grid
/// tile is around 130 logical pixels wide. A plain `Image.network` still
/// decodes the full 1600x1600 into memory there: 1600 * 1600 * 4 bytes
/// is ~10MB of bitmap per tile to paint ~0.07MB worth of pixels, so one
/// page of a profile grid could hold hundreds of megabytes of decoded
/// image it never shows. `cacheWidth` makes the decoder downsample
/// instead, which cuts both the memory and the decode time.
///
/// The size comes from a [LayoutBuilder] rather than a caller-supplied
/// number so it cannot drift out of step with the layout, and is scaled
/// by the device pixel ratio so the image is still decoded at full
/// physical resolution -- this is a memory fix, never a sharpness
/// tradeoff. When width is unbounded (e.g. inside an unconstrained Row)
/// it falls back to full-size decoding, exactly as before.
///
/// Also carries the placeholder pair every grid was missing: a neutral
/// block while loading (rather than a white flash during a fast scroll)
/// and a broken-image icon on failure (rather than an empty hole).
class NetworkThumbnail extends StatelessWidget {
  const NetworkThumbnail({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.maxDecodeWidth,
  });

  final String imageUrl;
  final BoxFit fit;

  /// Optional upper bound in logical pixels, for a thumbnail whose box
  /// is much wider than the image ever needs to be sharp at.
  final double? maxDecodeWidth;

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Image.network(
          imageUrl,
          fit: fit,
          cacheWidth: decodeWidthFor(
            constraints.maxWidth,
            devicePixelRatio: devicePixelRatio,
            maxLogicalWidth: maxDecodeWidth,
          ),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
          errorBuilder: (context, error, stackTrace) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: Icon(Icons.broken_image_outlined, size: 20),
            ),
          ),
        );
      },
    );
  }
}

/// The `cacheWidth` to decode an image at when it will be painted
/// [logicalWidth] wide on a [devicePixelRatio] screen, or null (decode
/// at full size, Flutter's default) when there is no useful bound --
/// an unbounded or zero width.
///
/// Split out from [NetworkThumbnail] so the arithmetic that decides how
/// much memory an image costs is testable on its own, without a widget
/// tree or a network image.
int? decodeWidthFor(
  double logicalWidth, {
  required double devicePixelRatio,
  double? maxLogicalWidth,
}) {
  if (!logicalWidth.isFinite || logicalWidth <= 0) return null;
  final bounded = maxLogicalWidth == null
      ? logicalWidth
      : (logicalWidth < maxLogicalWidth ? logicalWidth : maxLogicalWidth);
  // Never below 1: a sub-pixel box would otherwise ask for a 0-wide
  // decode, which Flutter rejects.
  final physical = (bounded * devicePixelRatio).round();
  return physical < 1 ? 1 : physical;
}
