import 'package:flutter/material.dart';

/// The ZOKY wordmark-only logo (white "Zoky" + map pin + smile on a
/// transparent background), shown from the Founder's original PNG pixels.
///
/// Design 2.1: never redraw, recolor, tint or stretch it, and only place it
/// on the brand pink. The aspect ratio is always preserved
/// ([BoxFit.contain]); callers only choose the width.
class ZokyWordmark extends StatelessWidget {
  const ZokyWordmark({super.key, required this.width});

  static const String assetPath = 'assets/images/zoky_wordmark.png';

  /// Pixel size of the asset (1066x590).
  static const double aspectRatio = 1066 / 590;

  final double width;

  @override
  Widget build(BuildContext context) {
    final height = width / aspectRatio;
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'ZOKY',
      // Decode at display size (never above the 1066px source) to save
      // memory; downscaling only, no upscaling.
      cacheWidth: (width * MediaQuery.devicePixelRatioOf(context))
          .round()
          .clamp(1, 1066),
    );
  }
}
