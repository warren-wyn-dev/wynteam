import 'package:flutter/material.dart';

/// The ZOKY primary mark (Founder-approved brighter, no-shadow version):
/// a PNG render of design-reference/zoky/zoky-logo.svg (design 2.1: never
/// redraw, recolor or frame it). Minimum in-app size 28 (design 2.3).
class ZokyLogo extends StatelessWidget {
  const ZokyLogo({
    super.key,
    this.size = 40,
    this.excludeFromSemantics = false,
  });

  static const String assetPath = 'assets/images/zoky_logo.png';

  final double size;

  /// Set when a visible "ZOKY" text label is already next to the logo.
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    assert(size >= 28, 'Logo minimum size is 28 (design 2.3)');
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: excludeFromSemantics ? null : 'ZOKY',
      excludeFromSemantics: excludeFromSemantics,
      // Decode at display size: the asset is 512px.
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    );
  }
}
