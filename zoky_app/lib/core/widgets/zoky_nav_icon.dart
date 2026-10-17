import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../design/zoky_colors.dart';
import 'zoky_3d_icon.dart';

/// Icon treatment of the bottom nav tabs.
///
/// [appleSoft3d] is the shipped look (Founder chose "D2" 2026-10-17 after
/// asking for an Apple style); the other two stay available for reviews.
enum ZokyNavIconStyle {
  /// Gray custom line icon, glossy 3D pink when selected ([Zoky3DIcon]).
  classic3d,

  /// iOS tab bar convention with the MIT CupertinoIcons font (an SF
  /// Symbols look-alike; no Apple assets): gray outline glyph, flat
  /// brand-deep pink filled glyph when selected.
  apple,

  /// [apple], but the selected filled glyph gets the ZOKY 3D light: pink
  /// vertical gradient, top-left specular highlight, bottom-right shade
  /// and a small soft drop shadow (shipped default).
  appleSoft3d,
}

/// Outline / filled CupertinoIcons pair of one nav destination.
@immutable
class ZokyAppleNavIcons {
  const ZokyAppleNavIcons(this.outline, this.fill);

  final IconData outline;
  final IconData fill;

  static const home = ZokyAppleNavIcons(
    CupertinoIcons.house,
    CupertinoIcons.house_fill,
  );
  static const homeAlt = ZokyAppleNavIcons(
    CupertinoIcons.house_alt,
    CupertinoIcons.house_alt_fill,
  );
  static const orders = ZokyAppleNavIcons(
    CupertinoIcons.doc_text,
    CupertinoIcons.doc_text_fill,
  );
  static const ordersBag = ZokyAppleNavIcons(
    CupertinoIcons.bag,
    CupertinoIcons.bag_fill,
  );
  static const ordersList = ZokyAppleNavIcons(
    CupertinoIcons.square_list,
    CupertinoIcons.square_list_fill,
  );
  static const messages = ZokyAppleNavIcons(
    CupertinoIcons.chat_bubble,
    CupertinoIcons.chat_bubble_fill,
  );
  static const messagesPair = ZokyAppleNavIcons(
    CupertinoIcons.chat_bubble_2,
    CupertinoIcons.chat_bubble_2_fill,
  );
  static const messagesDots = ZokyAppleNavIcons(
    CupertinoIcons.ellipses_bubble,
    CupertinoIcons.ellipses_bubble_fill,
  );
  static const account = ZokyAppleNavIcons(
    CupertinoIcons.person,
    CupertinoIcons.person_fill,
  );
  static const accountCircle = ZokyAppleNavIcons(
    CupertinoIcons.person_crop_circle,
    CupertinoIcons.person_crop_circle_fill,
  );

  /// Default pair of a nav glyph, or null for non-nav glyphs. In the Apple
  /// styles [Zoky3DGlyph.chat] draws [ZokyNavIcon]'s own wide bubble
  /// instead unless a pair (e.g. [messages]) is passed explicitly.
  static ZokyAppleNavIcons? forGlyph(Zoky3DGlyph glyph) => switch (glyph) {
    Zoky3DGlyph.home => home,
    Zoky3DGlyph.receipt => orders,
    Zoky3DGlyph.chat => messages,
    Zoky3DGlyph.person => account,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is ZokyAppleNavIcons &&
      other.outline == outline &&
      other.fill == fill;

  @override
  int get hashCode => Object.hash(outline, fill);
}

/// One nav tab icon in a [ZokyNavIconStyle]. Decorative: the tab button
/// carries the label.
class ZokyNavIcon extends StatelessWidget {
  const ZokyNavIcon(
    this.glyph, {
    super.key,
    required this.selected,
    this.style = ZokyNavIconStyle.appleSoft3d,
    this.size = 26,
    this.appleIcons,
    this.tiled = false,
    this.lineColor = ZokyColors.neutral600,
  });

  /// Flat selected color: brand deep, 4.58:1 on the blush highlight
  /// (#FFEDF4) and the same color as the selected label.
  static const Color appleSelectedColor = ZokyColors.actionPrimary;

  /// Soft 3D gradient (top -> bottom): every stop >= 3.24:1 on the blush
  /// highlight, so the glyph keeps non-text contrast without its sheen.
  static const List<Color> soft3dGradient = [
    ZokyColors.brandLight,
    ZokyColors.brandDeep,
  ];

  /// Outline stroke of the custom-painted glyphs as a fraction of the icon
  /// size, matched to the CupertinoIcons outlines (~1.8pt at 26pt).
  static const double strokeFraction = 0.068;

  /// Identifies the custom wide message bubble (variant M1).
  static const Key bubbleKey = ValueKey('ZokyNavIcon.bubble');

  /// Identifies the custom symmetric house (Founder reference 2026-10-17).
  static const Key houseKey = ValueKey('ZokyNavIcon.house');

  /// Identifies the rounded-square tile (variant M2 / all-tiles).
  static const Key tileKey = ValueKey('ZokyNavIcon.tile');

  final Zoky3DGlyph glyph;
  final bool selected;
  final ZokyNavIconStyle style;
  final double size;

  /// Overrides the CupertinoIcons pair of the Apple styles (alternates).
  final ZokyAppleNavIcons? appleIcons;

  /// Apple styles only: draw the glyph inside an app-icon-like squircle
  /// tile (PROPOSED messages variant M2). Pink glossy tile with a white
  /// glyph when selected; gray outlined tile and glyph otherwise.
  final bool tiled;

  /// Unselected gray (#6B6B76: 5.26:1 on white).
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    final pair = appleIcons ?? ZokyAppleNavIcons.forGlyph(glyph);
    if (style == ZokyNavIconStyle.classic3d || pair == null) {
      return Zoky3DIcon(
        glyph,
        size: size,
        style: selected ? Zoky3DIconStyle.glossy : Zoky3DIconStyle.line,
        lineColor: lineColor,
      );
    }
    // Custom-painted defaults (no font glyph matches the Founder's refs).
    final shape = appleIcons != null
        ? null
        : switch (glyph) {
            Zoky3DGlyph.home => _housePath,
            Zoky3DGlyph.chat => _bubblePath,
            _ => null,
          };
    final Widget icon;
    if (tiled) {
      icon = _NavTile(
        key: tileKey,
        size: size,
        selected: selected,
        flat: style == ZokyNavIconStyle.apple,
        lineColor: lineColor,
        shape: shape,
        glyph: selected ? pair.fill : pair.outline,
      );
    } else if (shape != null) {
      icon = KeyedSubtree(
        key: glyph == Zoky3DGlyph.chat ? bubbleKey : houseKey,
        child: _painted(shape),
      );
    } else if (!selected) {
      icon = Icon(pair.outline, size: size, color: lineColor);
    } else if (style == ZokyNavIconStyle.apple) {
      icon = Icon(pair.fill, size: size, color: appleSelectedColor);
    } else {
      icon = _Soft3dGlyph(
        size: size,
        body: (color) => Icon(pair.fill, size: size, color: color),
        shadow: Icon(
          pair.fill,
          size: size,
          color: const Color(0x00000000),
          shadows: [
            Shadow(
              color: _Soft3dGlyph.shadowColor,
              offset: Offset(0, size * 0.06),
              blurRadius: size * 0.10,
            ),
          ],
        ),
      );
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Center(child: icon),
      ),
    );
  }

  Widget _painted(_ShapeBuilder shape) {
    Widget paint(Color color, {bool stroke = false}) => CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(
        shape: shape,
        color: color,
        strokeWidth: stroke ? size * strokeFraction : null,
      ),
    );
    if (!selected) return paint(lineColor, stroke: true);
    if (style == ZokyNavIconStyle.apple) return paint(appleSelectedColor);
    return _Soft3dGlyph(
      size: size,
      body: paint,
      shadow: Transform.translate(
        offset: Offset(0, size * 0.06),
        child: CustomPaint(
          size: Size.square(size),
          painter: _GlyphPainter(
            shape: shape,
            color: _Soft3dGlyph.shadowColor,
            blurSigma: Shadow.convertRadiusToSigma(size * 0.10),
          ),
        ),
      ),
    );
  }
}

/// Path of a custom glyph fitted to [Rect] (the stroke-inset icon square).
typedef _ShapeBuilder = Path Function(Rect r);

/// Closed polygon with corner i rounded by a quadratic curve of radii[i]
/// (clamped to half of the shorter adjacent edge).
Path _roundedPolygon(List<Offset> points, List<double> radii) {
  final path = Path();
  final n = points.length;
  for (var i = 0; i < n; i++) {
    final prev = points[(i - 1 + n) % n];
    final cur = points[i];
    final next = points[(i + 1) % n];
    final inLen = (cur - prev).distance;
    final outLen = (next - cur).distance;
    final r = [radii[i], inLen / 2, outLen / 2].reduce((a, b) => a < b ? a : b);
    final start = cur + (prev - cur) * (r / inLen);
    final end = cur + (next - cur) * (r / outLen);
    if (i == 0) {
      path.moveTo(start.dx, start.dy);
    } else {
      path.lineTo(start.dx, start.dy);
    }
    path.quadraticBezierTo(cur.dx, cur.dy, end.dx, end.dy);
  }
  return path..close();
}

/// Original minimal symmetric house (Founder reference 2026-10-17): one
/// pentagon, pointed roof, straight walls, flat floor, no chimney or door,
/// fully rounded corners. Coordinates are fractions of the icon square.
Path _housePath(Rect r) {
  Offset p(double x, double y) =>
      Offset(r.left + x * r.width, r.top + y * r.height);
  return _roundedPolygon(
    [p(0.5, 0.08), p(0.91, 0.45), p(0.91, 0.90), p(0.09, 0.90), p(0.09, 0.45)],
    [
      for (final k in [0.09, 0.08, 0.12, 0.12, 0.08]) k * r.width,
    ],
  );
}

/// Original wide speech bubble (inspired by, not traced from, chat app
/// icons): a soft ellipse ~1.33:1 whose left side flows, through a soft
/// crease, into a small tail curling to the bottom-left. One continuous
/// outline (no union seams). Coordinates are fractions of the icon square.
Path _bubblePath(Rect r) {
  Offset p(double x, double y) =>
      Offset(r.left + x * r.width, r.top + y * r.height);
  const cx = 0.5, cy = 0.45, rx = 0.46, ry = 0.345;
  const leave = 150 * math.pi / 180; // tail's outer edge leaves here
  const join = 100 * math.pi / 180; // tail's inner edge joins here
  final oval = Rect.fromLTRB(
    r.left + (cx - rx) * r.width,
    r.top + (cy - ry) * r.height,
    r.left + (cx + rx) * r.width,
    r.top + (cy + ry) * r.height,
  );
  Offset onOval(double t) => p(cx + rx * math.cos(t), cy + ry * math.sin(t));
  // Unit tangent direction (increasing angle) scaled to fractions.
  Offset tangent(double t, double k) =>
      Offset(-rx * math.sin(t) * k * r.width, ry * math.cos(t) * k * r.height);
  final tip = p(0.06, 0.905);
  final l = onOval(leave);
  final b = onOval(join);
  final c2 = l - tangent(leave, 0.28);
  final c3 = b + tangent(join, 0.25);
  final c1 = p(0.135, 0.87);
  final c4 = p(0.15, 0.90);
  return Path()
    ..moveTo(tip.dx, tip.dy)
    ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, l.dx, l.dy)
    ..arcTo(oval, leave, 2 * math.pi - (leave - join), false)
    ..cubicTo(c3.dx, c3.dy, c4.dx, c4.dy, tip.dx, tip.dy)
    ..close();
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({
    required this.shape,
    required this.color,
    this.strokeWidth,
    this.blurSigma,
  });

  final _ShapeBuilder shape;
  final Color color;

  /// Outline when set, filled otherwise.
  final double? strokeWidth;
  final double? blurSigma;

  @override
  void paint(Canvas canvas, Size size) {
    final w = strokeWidth;
    final paint = Paint()
      ..isAntiAlias = true
      ..color = color;
    if (w != null) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeJoin = StrokeJoin.round;
    }
    if (blurSigma != null) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma!);
    }
    final rect = (Offset.zero & size).deflate((w ?? 0) / 2);
    canvas.drawPath(shape(rect), paint);
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.blurSigma != blurSigma;
}

/// App-icon-like tile: continuous-corner rounded square (iOS superellipse
/// look) holding a white glyph when selected, gray outlines otherwise.
class _NavTile extends StatelessWidget {
  const _NavTile({
    super.key,
    required this.size,
    required this.selected,
    required this.flat,
    required this.lineColor,
    required this.glyph,
    this.shape,
  });

  final double size;
  final bool selected;

  /// Flat brand-deep tile (the [ZokyNavIconStyle.apple] style).
  final bool flat;
  final Color lineColor;

  /// Font glyph inside the tile, unless [shape] (a custom glyph) is set.
  final IconData glyph;
  final _ShapeBuilder? shape;

  /// Tile side and corner radius as fractions of the icon size.
  static const double side = 0.92;
  static const double radius = 0.25;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFFFFFFFF) : lineColor;
    final custom = shape;
    final inner = size * (custom == _bubblePath ? 0.66 : 0.58);
    final Widget content = custom != null
        ? CustomPaint(
            size: Size.square(inner),
            painter: _GlyphPainter(
              shape: custom,
              color: color,
              strokeWidth: selected
                  ? null
                  : size * ZokyNavIcon.strokeFraction * 0.85,
            ),
          )
        : Icon(glyph, size: inner, color: color);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _TilePainter(
              selected: selected,
              flat: flat,
              lineColor: lineColor,
              strokeWidth: size * ZokyNavIcon.strokeFraction,
            ),
          ),
          Padding(
            // Optical center: the bubble's tail makes it sit low.
            padding: EdgeInsets.only(
              bottom: custom == _bubblePath ? size * 0.02 : 0,
            ),
            child: content,
          ),
        ],
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  const _TilePainter({
    required this.selected,
    required this.flat,
    required this.lineColor,
    required this.strokeWidth,
  });

  final bool selected;
  final bool flat;
  final Color lineColor;
  final double strokeWidth;

  RSuperellipse _shape(Rect r) => RSuperellipse.fromRectAndRadius(
    r,
    Radius.circular(r.width * _NavTile.radius / _NavTile.side),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width * _NavTile.side;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: s,
      height: s,
    );
    if (!selected) {
      canvas.drawRSuperellipse(
        _shape(rect.deflate(strokeWidth / 2)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..color = lineColor,
      );
      return;
    }
    final shape = _shape(rect);
    if (flat) {
      canvas.drawRSuperellipse(
        shape,
        Paint()..color = ZokyNavIcon.appleSelectedColor,
      );
      return;
    }
    // Small soft drop shadow, then the pink body, bottom shade, top gloss.
    canvas.drawRSuperellipse(
      _shape(rect.shift(Offset(0, s * 0.06))),
      Paint()
        ..color = _Soft3dGlyph.shadowColor
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          Shadow.convertRadiusToSigma(s * 0.10),
        ),
    );
    canvas.drawRSuperellipse(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: ZokyNavIcon.soft3dGradient,
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRSuperellipse(shape);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment(-0.2, -0.2),
          end: Alignment.bottomRight,
          colors: [Color(0x00AF1341), Color(0x4D991636)],
        ).createShader(rect),
    );
    final gloss = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height * 0.55,
    );
    canvas.drawRect(
      gloss,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
        ).createShader(gloss),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TilePainter old) =>
      old.selected != selected ||
      old.flat != flat ||
      old.lineColor != lineColor ||
      old.strokeWidth != strokeWidth;
}

/// A filled glyph lit like [Zoky3DIcon]: light from the top-left. [body]
/// paints the glyph's shape in the given color (masked by each layer).
class _Soft3dGlyph extends StatelessWidget {
  const _Soft3dGlyph({
    required this.size,
    required this.body,
    required this.shadow,
  });

  static const Color shadowColor = Color(0x52C2185B);

  final double size;
  final Widget Function(Color color) body;
  final Widget shadow;

  Widget _layer(Shader Function(Rect) shader) => ShaderMask(
    shaderCallback: shader,
    blendMode: BlendMode.srcIn,
    child: body(const Color(0xFFFFFFFF)),
  );

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Small soft drop shadow, offset down.
        shadow,
        // 2. Body: vertical pink gradient.
        _layer(
          (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: ZokyNavIcon.soft3dGradient,
          ).createShader(r),
        ),
        // 3. Soft inner shade bottom-right.
        _layer(
          (r) => const LinearGradient(
            begin: Alignment(-0.2, -0.2),
            end: Alignment.bottomRight,
            colors: [Color(0x00AF1341), Color(0x66991636)],
          ).createShader(r),
        ),
        // 4. Specular highlight top-left (halo + brighter core).
        _layer(
          (r) => const RadialGradient(
            center: Alignment(-0.42, -0.58),
            radius: 0.55,
            colors: [Color(0xCCFFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
            stops: [0, 0.35, 1],
          ).createShader(r),
        ),
      ],
    );
  }
}
