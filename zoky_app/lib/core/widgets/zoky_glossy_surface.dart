import 'package:flutter/widgets.dart';

import '../design/zoky_colors.dart';

/// "ZOKY Glossy 3D" surface recipe (design system section "Glossy 3D",
/// PROPOSED): the logo's look -- a vertical pink gradient, a soft white gloss
/// band across the top with a curved lower edge, a 1px inner light rim and a
/// soft pink drop shadow. Shared by the Home header (Phase 1), the hero card
/// (Phase 2) and the small white glossy controls inside them, so every phase
/// is drawn from one recipe.
abstract final class ZokyGloss {
  /// Brand surface: the same stops as the logo-matched header.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      ZokyColors.headerTop,
      ZokyColors.headerMid,
      ZokyColors.headerBottom,
    ],
    stops: [0, 0.35, 1],
  );

  /// White glossy control (heart button, pill, search button). Text on it
  /// is [ZokyColors.brandDeep]: 5.15:1 on white, 4.70:1 on [whiteBottom].
  static const Color whiteBottom = Color(0xFFFFF1F6);
  static const LinearGradient white = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ZokyColors.neutral0, whiteBottom],
  );

  /// Translucent white disc/panel that sits on the brand surface.
  static const LinearGradient frost = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x57FFFFFF), Color(0x24FFFFFF)],
  );

  /// Peak opacity of the top gloss band (fades to 0 at its lower edge).
  static const double glossOpacity = 0.35;

  /// Inner light rim: white ~25% at the top fading to ~8% at the bottom.
  static const Color rimTop = Color(0x40FFFFFF);
  static const Color rimBottom = Color(0x14FFFFFF);

  /// Soft pink drop shadow (#EE226E @ 25%, blur 24, y 10).
  static const List<BoxShadow> brandShadow = [
    BoxShadow(color: Color(0x40EE226E), offset: Offset(0, 10), blurRadius: 24),
  ];

  /// Smaller pink shadow for white controls (#EE226E @ 22%).
  static const List<BoxShadow> controlShadow = [
    BoxShadow(color: Color(0x38EE226E), offset: Offset(0, 4), blurRadius: 12),
  ];

  /// Rim for white controls: bright top, soft pink bottom edge (bevel).
  static const Color controlRimTop = Color(0xFFFFFFFF);
  static const Color controlRimBottom = Color(0x66F9C0DE);
}

/// Paints the glossy recipe inside a rounded rect: optional [gradient] base,
/// a top gloss band [glossHeight] tall (absolute logical px, so callers can
/// keep it above small text), and an optional 1px inner rim.
class ZokyGlossPainter extends CustomPainter {
  const ZokyGlossPainter({
    this.gradient = ZokyGloss.brand,
    this.borderRadius = BorderRadius.zero,
    required this.glossHeight,
    this.glossOpacity = ZokyGloss.glossOpacity,
    this.glossInset = 4,
    this.rimTop = ZokyGloss.rimTop,
    this.rimBottom = ZokyGloss.rimBottom,
    this.rim = true,
  });

  /// Base fill; null paints only the gloss and rim (e.g. over an [Ink]).
  final Gradient? gradient;
  final BorderRadius borderRadius;
  final double glossHeight;
  final double glossOpacity;
  final double glossInset;
  final Color rimTop;
  final Color rimBottom;
  final bool rim;

  /// The gloss band: follows the top corners, lower edge bows upward and
  /// rises to the right like the logo's highlight.
  static Path glossPath(Size size, double height, double inset, double r) {
    final w = size.width;
    final h = height.clamp(0.0, size.height);
    final radius = (r - inset).clamp(0.0, w / 2);
    return Path()
      ..moveTo(inset, h)
      ..lineTo(inset, inset + radius)
      ..quadraticBezierTo(inset, inset, inset + radius, inset)
      ..lineTo(w - inset - radius, inset)
      ..quadraticBezierTo(w - inset, inset, w - inset, inset + radius)
      ..lineTo(w - inset, h * 0.72)
      ..quadraticBezierTo(w * 0.55, h * 0.50, inset, h)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    canvas.save();
    canvas.clipRRect(rrect);
    if (gradient != null) {
      canvas.drawRect(rect, Paint()..shader = gradient!.createShader(rect));
    }
    if (glossHeight > 0 && glossOpacity > 0) {
      final band = glossPath(
        size,
        glossHeight,
        glossInset,
        borderRadius.topLeft.x,
      );
      final bandRect = Rect.fromLTRB(0, glossInset, size.width, glossHeight);
      canvas.drawPath(
        band,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ZokyColors.neutral0.withValues(alpha: glossOpacity),
              ZokyColors.neutral0.withValues(alpha: 0),
            ],
          ).createShader(bandRect),
      );
    }
    canvas.restore();
    if (rim) {
      canvas.drawRRect(
        rrect.deflate(0.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [rimTop, rimBottom],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(ZokyGlossPainter oldDelegate) =>
      oldDelegate.gradient != gradient ||
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.glossHeight != glossHeight ||
      oldDelegate.glossOpacity != glossOpacity ||
      oldDelegate.glossInset != glossInset ||
      oldDelegate.rimTop != rimTop ||
      oldDelegate.rimBottom != rimBottom ||
      oldDelegate.rim != rim;
}

/// Brand glossy surface (header, hero card and future brand cards).
class ZokyGlossySurface extends StatelessWidget {
  const ZokyGlossySurface({
    super.key,
    this.gradient = ZokyGloss.brand,
    this.borderRadius = BorderRadius.zero,
    required this.glossHeight,
    this.glossOpacity = ZokyGloss.glossOpacity,
    this.glossInset = 4,
    this.rim = true,
    this.shadow = true,
    this.child,
  });

  final Gradient gradient;
  final BorderRadius borderRadius;
  final double glossHeight;
  final double glossOpacity;

  /// Gap between the gloss band and the surface edge (0 = full bleed).
  final double glossInset;
  final bool rim;
  final bool shadow;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget content = CustomPaint(
      painter: ZokyGlossPainter(
        gradient: gradient,
        borderRadius: borderRadius,
        glossHeight: glossHeight,
        glossOpacity: glossOpacity,
        glossInset: glossInset,
        rim: rim,
      ),
      child: child,
    );
    // Square surfaces (the header) are not clipped so children may overlap
    // their edge (the header's white sheet sits 1px past the bottom).
    if (borderRadius != BorderRadius.zero) {
      content = ClipRRect(borderRadius: borderRadius, child: content);
    }
    if (!shadow) return content;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: ZokyGloss.brandShadow,
      ),
      child: content,
    );
  }
}
