import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../design/zoky_colors.dart';

/// The four bottom nav destinations, each drawn as its own custom glyph
/// (design 9.8, Founder reference set 2026-10-17).
enum ZokyNavGlyph {
  /// House with an arched door (หน้าหลัก).
  home,

  /// Clipboard with three lines (ออเดอร์).
  orders,

  /// Round speech bubble with three dots (ข้อความ).
  messages,

  /// Head over a rounded body (บัญชี).
  account,
}

/// One nav tab icon: gray uniform outline, or the filled glyph with the
/// pink 3D light when [selected] (Founder Phase 5, 2026-10-17).
/// Decorative: the tab button carries the label.
class ZokyNavIcon extends StatelessWidget {
  const ZokyNavIcon(
    this.glyph, {
    super.key,
    required this.selected,
    this.size = 26,
    this.lineColor = ZokyColors.neutral600,
  });

  /// Soft 3D gradient (top -> bottom): every stop >= 3.24:1 on the blush
  /// highlight, so the glyph keeps non-text contrast without its sheen.
  static const List<Color> soft3dGradient = [
    ZokyColors.brandLight,
    ZokyColors.brandDeep,
  ];

  /// Outline stroke of the glyphs as a fraction of the icon size (~1.77pt
  /// at 26pt). Matches the Founder reference set (strokes 7.6% of the
  /// glyph height).
  static const double strokeFraction = 0.068;

  /// Identifies the icon of [glyph].
  static Key glyphKey(ZokyNavGlyph glyph) =>
      ValueKey('ZokyNavIcon.${glyph.name}');

  final ZokyNavGlyph glyph;
  final bool selected;
  final double size;

  /// Unselected gray (#6B6B76: 5.26:1 on white).
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        key: glyphKey(glyph),
        dimension: size,
        child: _icon(_RoundedGlyph.forGlyph(glyph)),
      ),
    );
  }

  Widget _icon(_RoundedGlyph g) {
    Widget paint(List<_PaintOp> ops, Color color, {double? blur}) =>
        CustomPaint(
          size: Size.square(size),
          painter: _RoundedPainter(ops, color, blurSigma: blur),
        );
    if (!selected) return paint(g.outline, lineColor);
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
}

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

/// A filled glyph lit like the ZOKY 3D icons: light from the top-left. [body]
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

/// Original glyphs of [ZokyNavIcon], drawn to match the icon
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

  /// Unselected outline glyph.
  final List<_PaintOp> outline;

  /// Selected filled silhouette, with cut-outs.
  final List<_PaintOp> filled;

  /// Inner marks repainted white over [filled] (lines, dots, clip slot).
  final List<_PaintOp> marks;

  static _RoundedGlyph forGlyph(ZokyNavGlyph glyph) => switch (glyph) {
    ZokyNavGlyph.home => house,
    ZokyNavGlyph.orders => clipboard,
    ZokyNavGlyph.messages => bubble,
    ZokyNavGlyph.account => person,
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
