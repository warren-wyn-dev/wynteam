import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Glyphs of the ZOKY 3D icon set ("ZOKY Glossy 3D", PROPOSED).
enum Zoky3DGlyph {
  /// Favorites heart.
  heart,

  /// Single 4-point sparkle star.
  sparkle,

  /// White arrow on a glossy pink sphere (end of a call-to-action).
  arrowRight,
}

/// Lighting palette of a 3D icon: vertical body gradient (top -> bottom),
/// inner shade color (bottom-right) and drop shadow color.
@immutable
class Zoky3DPalette {
  const Zoky3DPalette({
    required this.top,
    required this.bottom,
    required this.shade,
    required this.shadow,
  });

  final Color top;
  final Color bottom;
  final Color shade;
  final Color shadow;

  /// Brand pink, a little brighter than the logo so it pops on white.
  static const Zoky3DPalette pink = Zoky3DPalette(
    top: Color(0xFFFF6BAA),
    bottom: Color(0xFFE5135D),
    shade: Color(0xFF9E0E3E),
    shadow: Color(0xFFC2185B),
  );

  /// White glyph (e.g. the arrow drawn on the pink sphere).
  static const Zoky3DPalette white = Zoky3DPalette(
    top: Color(0xFFFFFFFF),
    bottom: Color(0xFFFFE0EC),
    shade: Color(0xFFE48AAE),
    shadow: Color(0xFF8E0F38),
  );
}

/// Custom-painted 3D icon with one consistent light: from the top-left,
/// vertical gradient body, specular highlight blob top-left, soft inner
/// shade bottom-right and a small soft drop shadow. No assets, no emoji.
///
/// Decorative by default (excluded from semantics, the parent control
/// carries the label); pass [semanticLabel] when the icon stands alone.
class Zoky3DIcon extends StatelessWidget {
  const Zoky3DIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.palette = Zoky3DPalette.pink,
    this.semanticLabel,
  });

  final Zoky3DGlyph glyph;
  final double size;
  final Zoky3DPalette palette;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: Zoky3DIconPainter(glyph: glyph, palette: palette),
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: icon);
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: icon,
    );
  }
}

/// Paints a [Zoky3DGlyph]; public so it can be reused in other painters
/// and tested directly.
class Zoky3DIconPainter extends CustomPainter {
  const Zoky3DIconPainter({required this.glyph, required this.palette});

  final Zoky3DGlyph glyph;
  final Zoky3DPalette palette;

  /// Heart in a unit square (the point is the lowest pixel).
  static Path heartPath(double s) => Path()
    ..moveTo(0.5 * s, 0.87 * s)
    ..cubicTo(0.20 * s, 0.67 * s, 0.05 * s, 0.50 * s, 0.07 * s, 0.33 * s)
    ..cubicTo(0.09 * s, 0.17 * s, 0.22 * s, 0.10 * s, 0.33 * s, 0.11 * s)
    ..cubicTo(0.42 * s, 0.12 * s, 0.47 * s, 0.17 * s, 0.5 * s, 0.23 * s)
    ..cubicTo(0.53 * s, 0.17 * s, 0.58 * s, 0.12 * s, 0.67 * s, 0.11 * s)
    ..cubicTo(0.78 * s, 0.10 * s, 0.91 * s, 0.17 * s, 0.93 * s, 0.33 * s)
    ..cubicTo(0.95 * s, 0.50 * s, 0.80 * s, 0.67 * s, 0.5 * s, 0.87 * s)
    ..close();

  /// 4-point star with concave sides (the mockup's single sparkle).
  static Path sparklePath(double s) {
    const a = 0.40; // control point offset: lower = slimmer arms
    const b = 1 - a;
    return Path()
      ..moveTo(0.5 * s, 0.05 * s)
      ..quadraticBezierTo(b * s, a * s, 0.95 * s, 0.5 * s)
      ..quadraticBezierTo(b * s, b * s, 0.5 * s, 0.95 * s)
      ..quadraticBezierTo(a * s, b * s, 0.05 * s, 0.5 * s)
      ..quadraticBezierTo(a * s, a * s, 0.5 * s, 0.05 * s)
      ..close();
  }

  static Path spherePath(double s) =>
      Path()..addOval(Rect.fromLTWH(0.06 * s, 0.04 * s, 0.88 * s, 0.88 * s));

  static Path arrowPath(double s) => Path()
    ..moveTo(0.31 * s, 0.48 * s)
    ..lineTo(0.67 * s, 0.48 * s)
    ..moveTo(0.52 * s, 0.33 * s)
    ..lineTo(0.67 * s, 0.48 * s)
    ..lineTo(0.52 * s, 0.63 * s);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    switch (glyph) {
      case Zoky3DGlyph.heart:
        _paintBody(
          canvas,
          heartPath(s),
          s,
          palette,
          highlight: Rect.fromCenter(
            center: Offset(0.29 * s, 0.27 * s),
            width: 0.24 * s,
            height: 0.13 * s,
          ),
        );
      case Zoky3DGlyph.sparkle:
        _paintBody(
          canvas,
          sparklePath(s),
          s,
          palette,
          highlight: Rect.fromCenter(
            center: Offset(0.43 * s, 0.38 * s),
            width: 0.12 * s,
            height: 0.20 * s,
          ),
          highlightAngle: 0.5,
        );
      case Zoky3DGlyph.arrowRight:
        _paintBody(
          canvas,
          spherePath(s),
          s,
          palette,
          highlight: Rect.fromCenter(
            center: Offset(0.34 * s, 0.22 * s),
            width: 0.36 * s,
            height: 0.16 * s,
          ),
        );
        _paintArrow(canvas, s);
    }
    canvas.restore();
  }

  /// [outer] with [hole] cut out. Uses the even-odd fill rule instead of
  /// Path.combine, which renders identically on every backend (CanvasKit
  /// included) for these simple, non-self-intersecting glyphs.
  static Path _outside(Rect outer, Path hole) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(outer)
    ..addPath(hole, Offset.zero);

  static double _blur(double s, double k) => math.max(0.4, s * k);

  void _paintBody(
    Canvas canvas,
    Path body,
    double s,
    Zoky3DPalette p, {
    required Rect highlight,
    double highlightAngle = -0.45,
  }) {
    final bounds = body.getBounds();

    // 1. Small soft drop shadow, offset down (light from the top-left).
    canvas.drawPath(
      body.shift(Offset(0.02 * s, 0.06 * s)),
      Paint()
        ..color = p.shadow.withValues(alpha: 0.30)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blur(s, 0.04)),
    );

    // 2. Body: vertical gradient.
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.top, p.bottom],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(body);

    // 3. Soft inner shade bottom-right: everything outside the body moved
    //    up-left, blurred, so a crescent of shade hugs the lower-right edge.
    final outer = Rect.fromLTWH(-s, -s, 3 * s, 3 * s);
    final crescent = _outside(outer, body.shift(Offset(-0.07 * s, -0.08 * s)));
    canvas.drawPath(
      crescent,
      Paint()
        ..color = p.shade.withValues(alpha: 0.38)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blur(s, 0.045)),
    );

    // 4. Thin top-left light edge (same trick, opposite side, white).
    final rimLight = _outside(outer, body.shift(Offset(0.03 * s, 0.04 * s)));
    canvas.drawPath(
      rimLight,
      Paint()
        ..color = const Color(0x8CFFFFFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blur(s, 0.02)),
    );
    canvas.restore();

    // 5. Specular highlight blob top-left: soft halo + brighter core.
    canvas.save();
    canvas.clipPath(body);
    canvas.translate(highlight.center.dx, highlight.center.dy);
    canvas.rotate(highlightAngle);
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: highlight.width,
      height: highlight.height,
    );
    canvas.drawOval(
      local,
      Paint()
        ..color = const Color(0xB3FFFFFF)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blur(s, 0.025)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-local.width * 0.12, 0),
        width: local.width * 0.45,
        height: local.height * 0.45,
      ),
      Paint()..color = const Color(0xE6FFFFFF),
    );
    canvas.restore();
  }

  void _paintArrow(Canvas canvas, double s) {
    final arrow = arrowPath(s);
    Paint stroke(double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Embossed: darker copy just below, then the white glyph.
    canvas.drawPath(
      arrow.shift(Offset(0, 0.035 * s)),
      stroke(0.11 * s)
        ..color = Zoky3DPalette.white.shadow.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blur(s, 0.012)),
    );
    canvas.drawPath(
      arrow,
      stroke(0.11 * s)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Zoky3DPalette.white.top, Zoky3DPalette.white.bottom],
        ).createShader(Rect.fromLTWH(0, 0.30 * s, s, 0.36 * s)),
    );
  }

  @override
  bool shouldRepaint(Zoky3DIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.palette != palette;
}
