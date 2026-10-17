import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Glyphs of the ZOKY 3D icon set ("ZOKY Glossy 3D", design 7.1).
enum Zoky3DGlyph {
  /// Favorites heart.
  heart,

  /// Single 4-point sparkle star.
  sparkle,

  /// White arrow on a glossy pink sphere (end of a call-to-action).
  arrowRight,

  /// Rounded 5-point star (review rating), usually [Zoky3DPalette.gold].
  star,

  /// House with a door notch (nav หน้าหลัก).
  home,

  /// Receipt with a zigzag tear-off edge and text lines (nav ออเดอร์).
  receipt,

  /// Round speech bubble with a tail bottom-left (nav ข้อความ).
  chat,

  /// Head and shoulders (nav บัญชี).
  person,
}

/// How a [Zoky3DIcon] is rendered. Both styles use the same glyph path, so a
/// line icon and its glossy twin line up exactly (e.g. when a nav tab
/// switches between them).
enum Zoky3DIconStyle {
  /// Filled body with the shared 3D lighting.
  glossy,

  /// Minimal outline: the glyph path stroked ~1.8px (at 24) with round caps
  /// and joins, in a single flat color.
  line,
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

  /// Rating gold (around [ZokyColors.rating] #F5A623), same lighting.
  static const Zoky3DPalette gold = Zoky3DPalette(
    top: Color(0xFFFFD45C),
    bottom: Color(0xFFF59E0B),
    shade: Color(0xFFB45309),
    shadow: Color(0xFFC2700A),
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
    this.style = Zoky3DIconStyle.glossy,
    this.lineColor = defaultLineColor,
    this.semanticLabel,
  });

  /// Secondary gray (#6B6B76, ZokyColors.neutral600): 5.26:1 on white.
  static const Color defaultLineColor = Color(0xFF6B6B76);

  final Zoky3DGlyph glyph;
  final double size;
  final Zoky3DPalette palette;
  final Zoky3DIconStyle style;

  /// Stroke color of [Zoky3DIconStyle.line]; ignored when glossy.
  final Color lineColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = CustomPaint(
      size: Size.square(size),
      painter: Zoky3DIconPainter(
        glyph: glyph,
        palette: palette,
        style: style,
        lineColor: lineColor,
      ),
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
  const Zoky3DIconPainter({
    required this.glyph,
    required this.palette,
    this.style = Zoky3DIconStyle.glossy,
    this.lineColor = Zoky3DIcon.defaultLineColor,
  });

  final Zoky3DGlyph glyph;
  final Zoky3DPalette palette;
  final Zoky3DIconStyle style;
  final Color lineColor;

  /// Glyphs designed to switch between line and glossy (nav tabs).
  static const Set<Zoky3DGlyph> _lineTwins = {
    Zoky3DGlyph.home,
    Zoky3DGlyph.receipt,
    Zoky3DGlyph.chat,
    Zoky3DGlyph.person,
  };

  /// Glossy scale of those glyphs, compensating the line stroke's outset.
  static const double glossyTwinScale = 1.1;

  /// Stroke width of [Zoky3DIconStyle.line] relative to the icon size
  /// (1.8px at 24, 1.95px at 26).
  static const double lineWidth = 0.075;

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

  /// 5-point star with softly rounded tips, centered a little high so the
  /// drop shadow fits below.
  static Path starPath(double s) {
    const n = 5;
    const outer = 0.46;
    const inner = 0.21;
    const cx = 0.5;
    const cy = 0.50;
    final pts = <Offset>[];
    for (var i = 0; i < n * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / n;
      pts.add(Offset((cx + r * math.cos(a)) * s, (cy + r * math.sin(a)) * s));
    }
    // Round each corner: line to a point just before it, curve through it.
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final prev = pts[(i - 1 + pts.length) % pts.length];
      final next = pts[(i + 1) % pts.length];
      final k = i.isEven ? 0.16 : 0.10;
      final a = Offset.lerp(p, prev, k)!;
      final b = Offset.lerp(p, next, k)!;
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(p.dx, p.dy, b.dx, b.dy);
    }
    return path..close();
  }

  static Path spherePath(double s) =>
      Path()..addOval(Rect.fromLTWH(0.06 * s, 0.04 * s, 0.88 * s, 0.88 * s));

  static Path arrowPath(double s) => Path()
    ..moveTo(0.31 * s, 0.48 * s)
    ..lineTo(0.67 * s, 0.48 * s)
    ..moveTo(0.52 * s, 0.33 * s)
    ..lineTo(0.67 * s, 0.48 * s)
    ..lineTo(0.52 * s, 0.63 * s);

  /// Closed polygon through [pts] (unit coordinates, scaled by [s]) whose
  /// corners are rounded by [radii] (unit, 0 = sharp), clamped to half of
  /// the shorter neighbouring edge.
  static Path _roundedPolygon(
    List<Offset> pts,
    List<double> radii,
    double s,
  ) {
    final path = Path();
    final n = pts.length;
    for (var i = 0; i < n; i++) {
      final p = pts[i] * s;
      final prev = pts[(i - 1 + n) % n] * s;
      final next = pts[(i + 1) % n] * s;
      final r = math.min(
        radii[i] * s,
        math.min((p - prev).distance, (next - p).distance) / 2,
      );
      final a = r <= 0 ? p : p + (prev - p) / (prev - p).distance * r;
      final b = r <= 0 ? p : p + (next - p) / (next - p).distance * r;
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      if (r > 0) path.quadraticBezierTo(p.dx, p.dy, b.dx, b.dy);
    }
    return path..close();
  }

  /// House outline with the door as a notch in the bottom edge, so the
  /// same path strokes like a minimal line house and fills like a solid
  /// one with a door cut out.
  static Path homePath(double s) => _roundedPolygon(
    const [
      Offset(0.16, 0.86),
      Offset(0.16, 0.45),
      Offset(0.50, 0.14),
      Offset(0.84, 0.45),
      Offset(0.84, 0.86),
      Offset(0.61, 0.86),
      Offset(0.61, 0.62),
      Offset(0.39, 0.62),
      Offset(0.39, 0.86),
    ],
    const [0.08, 0.06, 0.07, 0.06, 0.08, 0, 0.035, 0.035, 0],
    s,
  );

  /// Receipt sheet: rounded top, zigzag tear-off bottom.
  static Path receiptPath(double s) => _roundedPolygon(
    const [
      Offset(0.20, 0.11),
      Offset(0.80, 0.11),
      Offset(0.80, 0.88),
      Offset(0.70, 0.81),
      Offset(0.60, 0.88),
      Offset(0.50, 0.81),
      Offset(0.40, 0.88),
      Offset(0.30, 0.81),
      Offset(0.20, 0.88),
    ],
    const [0.08, 0.08, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02, 0.02],
    s,
  );

  /// The receipt's three text lines (open strokes).
  static Path receiptLinesPath(double s) => Path()
    ..moveTo(0.36 * s, 0.32 * s)
    ..lineTo(0.64 * s, 0.32 * s)
    ..moveTo(0.36 * s, 0.46 * s)
    ..lineTo(0.64 * s, 0.46 * s)
    ..moveTo(0.36 * s, 0.60 * s)
    ..lineTo(0.53 * s, 0.60 * s);

  /// Round bubble with a short tail pointing bottom-left (Lucide
  /// MessageCircle proportions).
  static Path chatPath(double s) {
    const cx = 0.5;
    const cy = 0.48;
    const r = 0.36;
    const start = 153 * math.pi / 180; // left side, above the tail
    const end = 117 * math.pi / 180; // bottom, right of the tail
    final rect = Rect.fromCircle(center: Offset(cx * s, cy * s), radius: r * s);
    return Path()
      ..moveTo(
        (cx + r * math.cos(start)) * s,
        (cy + r * math.sin(start)) * s,
      )
      ..arcTo(rect, start, 2 * math.pi - (start - end), false)
      ..lineTo(0.12 * s, 0.88 * s)
      ..close();
  }

  /// Head circle and a rounded shoulders dome (two closed sub-paths).
  static Path personPath(double s) => Path()
    ..addOval(
      Rect.fromCircle(center: Offset(0.5 * s, 0.30 * s), radius: 0.165 * s),
    )
    ..moveTo(0.22 * s, 0.88 * s)
    ..quadraticBezierTo(0.17 * s, 0.88 * s, 0.17 * s, 0.83 * s)
    ..cubicTo(0.17 * s, 0.69 * s, 0.31 * s, 0.60 * s, 0.5 * s, 0.60 * s)
    ..cubicTo(0.69 * s, 0.60 * s, 0.83 * s, 0.69 * s, 0.83 * s, 0.83 * s)
    ..quadraticBezierTo(0.83 * s, 0.88 * s, 0.78 * s, 0.88 * s)
    ..close();

  /// Body (filled or stroked) of [glyph].
  static Path bodyPath(Zoky3DGlyph glyph, double s) => switch (glyph) {
    Zoky3DGlyph.heart => heartPath(s),
    Zoky3DGlyph.sparkle => sparklePath(s),
    Zoky3DGlyph.star => starPath(s),
    Zoky3DGlyph.arrowRight => spherePath(s),
    Zoky3DGlyph.home => homePath(s),
    Zoky3DGlyph.receipt => receiptPath(s),
    Zoky3DGlyph.chat => chatPath(s),
    Zoky3DGlyph.person => personPath(s),
  };

  /// Open strokes drawn on top of the body (white and embossed when
  /// glossy), or null.
  static Path? detailPath(Zoky3DGlyph glyph, double s) => switch (glyph) {
    Zoky3DGlyph.arrowRight => arrowPath(s),
    Zoky3DGlyph.receipt => receiptLinesPath(s),
    _ => null,
  };

  void _paintLine(Canvas canvas, double s) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lineWidth * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = lineColor;
    canvas.drawPath(bodyPath(glyph, s), paint);
    final detail = detailPath(glyph, s);
    if (detail != null) canvas.drawPath(detail, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    if (style == Zoky3DIconStyle.line) {
      _paintLine(canvas, s);
      canvas.restore();
      return;
    }
    if (_lineTwins.contains(glyph)) {
      // A stroke adds half its width outside the path; grow the filled
      // twin by the same amount so line and glossy share one optical size.
      const k = glossyTwinScale;
      canvas.translate(s / 2, s / 2);
      canvas.scale(k);
      canvas.translate(-s / 2, -s / 2);
    }
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
      case Zoky3DGlyph.star:
        _paintBody(
          canvas,
          starPath(s),
          s,
          palette,
          highlight: Rect.fromCenter(
            center: Offset(0.40 * s, 0.36 * s),
            width: 0.20 * s,
            height: 0.12 * s,
          ),
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
        _paintEmbossed(
          canvas,
          arrowPath(s),
          s,
          width: 0.11,
          shaderRect: Rect.fromLTWH(0, 0.30 * s, s, 0.36 * s),
        );
      case Zoky3DGlyph.home:
        _paintBody(
          canvas,
          homePath(s),
          s,
          palette,
          highlight: Rect.fromCenter(
            center: Offset(0.35 * s, 0.38 * s),
            width: 0.24 * s,
            height: 0.09 * s,
          ),
          highlightAngle: -0.72,
        );
      case Zoky3DGlyph.receipt:
        _paintBody(
          canvas,
          receiptPath(s),
          s,
          palette,
          highlight: Rect.fromCenter(
            center: Offset(0.34 * s, 0.20 * s),
            width: 0.20 * s,
            height: 0.08 * s,
          ),
        );
        _paintEmbossed(
          canvas,
          receiptLinesPath(s),
          s,
          width: 0.075,
          shaderRect: Rect.fromLTWH(0, 0.30 * s, s, 0.32 * s),
        );
      case Zoky3DGlyph.chat:
        _paintBody(
          canvas,
          chatPath(s),
          s,
          palette,
          highlight: Rect.fromCenter(
            center: Offset(0.32 * s, 0.28 * s),
            width: 0.26 * s,
            height: 0.12 * s,
          ),
        );
      case Zoky3DGlyph.person:
        _paintBody(
          canvas,
          personPath(s),
          s,
          palette,
          highlight: Rect.fromCenter(
            center: Offset(0.43 * s, 0.23 * s),
            width: 0.14 * s,
            height: 0.08 * s,
          ),
        );
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

  /// White embossed strokes on a glossy body (arrow, receipt lines).
  void _paintEmbossed(
    Canvas canvas,
    Path arrow,
    double s, {
    required double width,
    required Rect shaderRect,
  }) {
    Paint stroke(double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // Embossed: darker copy just below, then the white glyph.
    canvas.drawPath(
      arrow.shift(Offset(0, 0.035 * s)),
      stroke(width * s)
        ..color = Zoky3DPalette.white.shadow.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _blur(s, 0.012)),
    );
    canvas.drawPath(
      arrow,
      stroke(width * s)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Zoky3DPalette.white.top, Zoky3DPalette.white.bottom],
        ).createShader(shaderRect),
    );
  }

  @override
  bool shouldRepaint(Zoky3DIconPainter oldDelegate) =>
      oldDelegate.glyph != glyph ||
      oldDelegate.palette != palette ||
      oldDelegate.style != style ||
      oldDelegate.lineColor != lineColor;
}
