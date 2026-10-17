import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import '../design/zoky_colors.dart';
import 'zoky_3d_icon.dart';

/// Icon treatment of the bottom nav tabs.
///
/// [rounded] is the shipped look (the icon set the Founder sent
/// 2026-10-17, "เอาแบบนี้"); the others stay available for reviews.
enum ZokyNavIconStyle {
  /// Gray custom line icon, glossy 3D pink when selected ([Zoky3DIcon]).
  classic3d,

  /// iOS tab bar convention with the MIT CupertinoIcons font (an SF
  /// Symbols look-alike; no Apple assets): gray outline glyph, flat
  /// brand-deep pink filled glyph when selected.
  apple,

  /// [apple], but the selected filled glyph gets the ZOKY 3D light: pink
  /// vertical gradient, top-left specular highlight, bottom-right shade
  /// and a small soft drop shadow ("D2", shipped before [rounded]).
  appleSoft3d,

  /// Original custom-painted rounded set (Founder reference 2026-10-17):
  /// house with a door, clipboard, bubble with three dots, person. Gray
  /// uniform outline; the selected glyph follows [ZokyNavSelectedGlyph].
  /// Glyphs without a rounded version, an explicit [ZokyNavIcon.appleIcons]
  /// pair or [ZokyNavIcon.tiled] render as [appleSoft3d] (shipped default).
  rounded,
}

/// Selected glyph of [ZokyNavIconStyle.rounded].
enum ZokyNavSelectedGlyph {
  /// Filled silhouette with the D2 pink 3D light; inner marks (lines,
  /// dots) white, the door cut out (shipped).
  filled3d,

  /// The gray outline glyph redrawn in flat brand-deep pink (alternate).
  outlinePink,
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
    this.style = ZokyNavIconStyle.rounded,
    this.selectedGlyph = ZokyNavSelectedGlyph.filled3d,
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
  /// size (~1.77pt at 26pt). Also matches the Founder reference set
  /// (strokes 7.6% of the glyph height).
  static const double strokeFraction = 0.068;

  /// Identifies the custom wide message bubble (variant M1).
  static const Key bubbleKey = ValueKey('ZokyNavIcon.bubble');

  /// Identifies the custom symmetric house (Founder reference 2026-10-17).
  static const Key houseKey = ValueKey('ZokyNavIcon.house');

  /// Identifies the rounded-square tile (variant M2 / all-tiles).
  static const Key tileKey = ValueKey('ZokyNavIcon.tile');

  /// Identifies a [ZokyNavIconStyle.rounded] glyph.
  static Key roundedKey(Zoky3DGlyph glyph) =>
      ValueKey('ZokyNavIcon.rounded.${glyph.name}');

  /// Whether [glyph] has a [ZokyNavIconStyle.rounded] version.
  static bool hasRounded(Zoky3DGlyph glyph) =>
      _RoundedGlyph.forGlyph(glyph) != null;

  final Zoky3DGlyph glyph;
  final bool selected;
  final ZokyNavIconStyle style;

  /// Selected treatment of the [ZokyNavIconStyle.rounded] glyphs.
  final ZokyNavSelectedGlyph selectedGlyph;
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
    final rounded = this.style == ZokyNavIconStyle.rounded && appleIcons == null
        ? _RoundedGlyph.forGlyph(glyph)
        : null;
    if (rounded != null && !tiled) {
      return ExcludeSemantics(
        child: SizedBox.square(
          key: roundedKey(glyph),
          dimension: size,
          child: _roundedIcon(rounded),
        ),
      );
    }
    final style = this.style == ZokyNavIconStyle.rounded
        ? ZokyNavIconStyle.appleSoft3d
        : this.style;
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

  Widget _roundedIcon(_RoundedGlyph g) {
    Widget paint(List<_PaintOp> ops, Color color, {double? blur}) =>
        CustomPaint(
          size: Size.square(size),
          painter: _RoundedPainter(ops, color, blurSigma: blur),
        );
    if (!selected) return paint(g.outline, lineColor);
    if (selectedGlyph == ZokyNavSelectedGlyph.outlinePink) {
      return paint(g.outline, appleSelectedColor);
    }
    return _Soft3dGlyph(
      size: size,
      body: (color) => paint(g.filled, color),
      shadow: Transform.translate(
        offset: Offset(0, size * 0.06),
        child: paint(
          g.filled,
          _Soft3dGlyph.shadowColor,
          blur: Shadow.convertRadiusToSigma(size * 0.10),
        ),
      ),
      overlay: g.marks.isEmpty ? null : paint(g.marks, const Color(0xFFFFFFFF)),
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
    this.overlay,
  });

  static const Color shadowColor = Color(0x52C2185B);

  final double size;
  final Widget Function(Color color) body;
  final Widget shadow;

  /// Painted unlit on top (e.g. white inner marks).
  final Widget? overlay;

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
        ?overlay,
      ],
    );
  }
}

/// One drawing step of a [_RoundedGlyph]: [path] (24-unit grid) filled
/// and/or stroked with the uniform outline; [cut] erases instead of paints.
@immutable
class _PaintOp {
  const _PaintOp(this.path, {this.fill = false, this.stroke = false})
    : cut = false;
  const _PaintOp.cut(this.path, {this.fill = false, this.stroke = false})
    : cut = true;

  final Path path;
  final bool fill;
  final bool stroke;
  final bool cut;
}

/// Original glyphs of [ZokyNavIconStyle.rounded], drawn to match the icon
/// set the Founder sent 2026-10-17 (shapes and proportions measured from
/// the reference, not traced). Coordinates are on a 24-unit grid and are
/// stroke centerlines; the outer glyph spans about 21 units.
@immutable
class _RoundedGlyph {
  const _RoundedGlyph({
    required this.outline,
    required this.filled,
    this.marks = const [],
  });

  /// Uniform outline: 1.62 of 24 (the reference measures 4.8px strokes on
  /// ~63px glyphs, 7.6% of the glyph height), round caps and joins.
  static const double stroke = 24 * ZokyNavIcon.strokeFraction;

  /// Unselected / outline-pink glyph.
  final List<_PaintOp> outline;

  /// Selected filled silhouette, with cut-outs.
  final List<_PaintOp> filled;

  /// Inner marks repainted white over [filled] (lines, dots, clip slot).
  final List<_PaintOp> marks;

  static _RoundedGlyph? forGlyph(Zoky3DGlyph glyph) => switch (glyph) {
    Zoky3DGlyph.home => house,
    Zoky3DGlyph.receipt => clipboard,
    Zoky3DGlyph.chat => bubble,
    Zoky3DGlyph.person => person,
    _ => null,
  };

  /// Symmetric house: soft rounded peak, short eaves, straight walls,
  /// rounded floor corners and an arched door notch at the bottom center.
  /// One continuous outline; filled, the door stays open.
  static final house = () {
    final path = _roundedPolygon(
      const [
        Offset(12, 1.0), // peak
        Offset(22.4, 11.9), // right eave tip
        Offset(20.1, 11.9), // right wall top
        Offset(20.1, 21.4), // right floor corner
        Offset(14.1, 21.4), // door right foot
        Offset(14.1, 14.7), // door top right
        Offset(9.9, 14.7), // door top left
        Offset(9.9, 21.4), // door left foot
        Offset(3.9, 21.4), // left floor corner
        Offset(3.9, 11.9), // left wall top
        Offset(1.6, 11.9), // left eave tip
      ],
      const [3.2, 0.9, 0.5, 2.4, 0.9, 2.1, 2.1, 0.9, 2.4, 0.5, 0.9],
    );
    return _RoundedGlyph(
      outline: [_PaintOp(path, stroke: true)],
      filled: [_PaintOp(path, fill: true, stroke: true)],
    );
  }();

  /// Clipboard: rounded board whose top edge stops at a rounded clip tab
  /// (top center), three short left-aligned lines inside. Filled, the clip
  /// is separated from the board by a gap and has a white slot.
  static final clipboard = () {
    const board = Rect.fromLTRB(3.7, 3.4, 20.3, 22.2);
    const r = Radius.circular(3.0);
    final clip = RRect.fromLTRBR(
      9.3,
      2.0,
      14.7,
      5.4,
      const Radius.circular(1.4),
    );
    final boardOpen = Path()
      ..moveTo(clip.left, board.top)
      ..lineTo(board.left + r.x, board.top)
      ..arcToPoint(
        Offset(board.left, board.top + r.y),
        radius: r,
        clockwise: false,
      )
      ..lineTo(board.left, board.bottom - r.y)
      ..arcToPoint(
        Offset(board.left + r.x, board.bottom),
        radius: r,
        clockwise: false,
      )
      ..lineTo(board.right - r.x, board.bottom)
      ..arcToPoint(
        Offset(board.right, board.bottom - r.y),
        radius: r,
        clockwise: false,
      )
      ..lineTo(board.right, board.top + r.y)
      ..arcToPoint(
        Offset(board.right - r.x, board.top),
        radius: r,
        clockwise: false,
      )
      ..lineTo(clip.right, board.top);
    final lines = Path()
      ..moveTo(8.4, 10.0)
      ..lineTo(12.6, 10.0)
      ..moveTo(8.4, 13.4)
      ..lineTo(15.6, 13.4)
      ..moveTo(8.4, 16.8)
      ..lineTo(13.9, 16.8);
    final clipPath = Path()..addRRect(clip);
    final slot = Path()
      ..addRRect(
        RRect.fromLTRBR(10.7, 3.15, 13.3, 4.25, const Radius.circular(0.55)),
      );
    final gap = Path()..addRRect(clip.inflate(stroke / 2 + 0.85));
    return _RoundedGlyph(
      outline: [
        _PaintOp(boardOpen, stroke: true),
        _PaintOp(clipPath, stroke: true),
        _PaintOp(lines, stroke: true),
      ],
      filled: [
        _PaintOp(
          Path()..addRRect(RRect.fromRectAndRadius(board, r)),
          fill: true,
          stroke: true,
        ),
        _PaintOp.cut(gap, fill: true),
        _PaintOp(clipPath, fill: true, stroke: true),
        _PaintOp.cut(slot, fill: true),
        _PaintOp.cut(lines, stroke: true),
      ],
      marks: [_PaintOp(slot, fill: true), _PaintOp(lines, stroke: true)],
    );
  }();

  /// Round speech bubble (ellipse ~1.09:1) with a short rounded tail at the
  /// bottom-left and three dots on its center line.
  static final bubble = () {
    const cx = 12.15, cy = 11.45, rx = 10.1, ry = 9.25;
    const leave = 140 * math.pi / 180; // tail's outer edge leaves here
    const join = 113 * math.pi / 180; // tail's inner edge joins here
    Offset on(double t) => Offset(cx + rx * math.cos(t), cy + ry * math.sin(t));
    const tip = Offset(2.0, 21.3);
    const tipRadius = 0.8;
    final l = on(leave);
    final j = on(join);
    final a = tip + (l - tip) * (tipRadius / (l - tip).distance);
    final b = tip + (j - tip) * (tipRadius / (j - tip).distance);
    final path = Path()
      ..moveTo(j.dx, j.dy)
      ..arcTo(
        Rect.fromCenter(
          center: const Offset(cx, cy),
          width: 2 * rx,
          height: 2 * ry,
        ),
        join,
        -(2 * math.pi - (leave - join)),
        false,
      )
      ..lineTo(a.dx, a.dy)
      ..quadraticBezierTo(tip.dx, tip.dy, b.dx, b.dy)
      ..close();
    final dots = Path();
    for (final x in const [cx - 4.7, cx, cx + 4.7]) {
      dots.addOval(Rect.fromCircle(center: Offset(x, cy), radius: 1.35));
    }
    return _RoundedGlyph(
      outline: [_PaintOp(path, stroke: true), _PaintOp(dots, fill: true)],
      filled: [
        _PaintOp(path, fill: true, stroke: true),
        _PaintOp.cut(dots, fill: true),
      ],
      marks: [_PaintOp(dots, fill: true)],
    );
  }();

  /// Person: circle head over a rounded-rectangle body (soft wide top
  /// corners, smaller bottom corners, flat bottom).
  static final person = () {
    final head = Path()
      ..addOval(Rect.fromCircle(center: const Offset(12, 6.75), radius: 4.35));
    final body = Path()
      ..addRRect(
        RRect.fromLTRBAndCorners(
          4.0,
          13.5,
          20.0,
          22.25,
          topLeft: const Radius.elliptical(5.2, 5.6),
          topRight: const Radius.elliptical(5.2, 5.6),
          bottomLeft: const Radius.circular(2.6),
          bottomRight: const Radius.circular(2.6),
        ),
      );
    return _RoundedGlyph(
      outline: [_PaintOp(head, stroke: true), _PaintOp(body, stroke: true)],
      filled: [
        _PaintOp(head, fill: true, stroke: true),
        _PaintOp(body, fill: true, stroke: true),
      ],
    );
  }();
}

/// Paints [_PaintOp]s scaled from the 24-unit grid to the icon size, in one
/// layer (so cuts erase only this glyph and translucent colors do not
/// double where fill and stroke overlap), optionally blurred.
class _RoundedPainter extends CustomPainter {
  const _RoundedPainter(this.ops, this.color, {this.blurSigma});

  final List<_PaintOp> ops;
  final Color color;
  final double? blurSigma;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    final matrix = Float64List.fromList([
      k, 0, 0, 0, //
      0, k, 0, 0, //
      0, 0, 1, 0, //
      0, 0, 0, 1, //
    ]);
    final layer = Paint()
      ..color = Color.fromARGB((color.a * 255).round(), 0, 0, 0);
    final sigma = blurSigma;
    if (sigma != null) {
      layer.imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    }
    canvas.saveLayer(null, layer);
    final opaque = color.withValues(alpha: 1);
    for (final op in ops) {
      final path = op.path.transform(matrix);
      final paint = Paint()
        ..isAntiAlias = true
        ..color = opaque
        ..blendMode = op.cut ? BlendMode.dstOut : BlendMode.srcOver;
      if (op.fill) canvas.drawPath(path, paint);
      if (op.stroke) {
        canvas.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = _RoundedGlyph.stroke * k
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoundedPainter old) =>
      old.ops != ops || old.color != color || old.blurSigma != blurSigma;
}
