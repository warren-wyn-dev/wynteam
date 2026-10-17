import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// Glossy 3D, code-drawn bento box used as the Home hero illustration (the
/// repo has no food photo asset yet). Purely decorative: excluded from
/// semantics. Kept in its own widget so it can be swapped for a real photo
/// later without touching the hero card.
class ZokyBentoIllustration extends StatelessWidget {
  const ZokyBentoIllustration({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: const _BentoPainter(),
      ),
    );
  }
}

/// Draws in a 100x100 design space scaled to the canvas: a lacquered box
/// in 3/4 view (black lid rim, red front and side faces, little feet) with
/// rice, salmon, tamagoyaki and greens. Same light as the 3D icons: from
/// the top-left, soft shade bottom-right, soft drop shadow.
///
/// The top face is drawn flat in a 100x62 "box space" and mapped onto the
/// screen with an affine transform ([_ex] across, [_ey] towards the
/// viewer), so the compartments foreshorten consistently.
class _BentoPainter extends CustomPainter {
  const _BentoPainter();

  static const double _w = 100; // box width (box space)
  static const double _d = 62; // box depth (box space)
  static const double _h = 16; // face height (screen space)
  static const Offset _origin = Offset(22, 29); // back-left corner
  static const Offset _ex = Offset(0.64, 0); // per box-space x unit
  static const Offset _ey = Offset(-0.12, 0.36); // per box-space y unit

  static Offset _map(double x, double y) => _origin + _ex * x + _ey * y;

  static final Float64List _topMatrix = Float64List.fromList([
    _ex.dx, _ex.dy, 0, 0, //
    _ey.dx, _ey.dy, 0, 0, //
    0, 0, 1, 0, //
    _origin.dx, _origin.dy, 0, 1, //
  ]);

  static const Color _lacquerTop = Color(0xFF4B3742);
  static const Color _lacquerBottom = Color(0xFF150B10);
  static const Color _trim = Color(0xFF1A0F14);
  static const Color _redLight = Color(0xFFEC3049);
  static const Color _red = Color(0xFFC8183A);
  static const Color _redDeep = Color(0xFF8C0C26);
  static const Color _sideLight = Color(0xFFAA1530);
  static const Color _sideDark = Color(0xFF64081B);
  static const Color _floor = Color(0xFF7A0E24);
  static const Color _cellTop = Color(0xFFB0193A);
  static const Color _cellBottom = Color(0xFFD42542);

  static Paint _linear(Rect r, List<Color> colors, {bool vertical = true}) =>
      Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: vertical ? Alignment.topCenter : Alignment.topLeft,
          end: vertical ? Alignment.bottomCenter : Alignment.bottomRight,
          colors: colors,
        ).createShader(r);

  static Path _quad(Offset a, Offset b, Offset c, Offset d) => Path()
    ..moveTo(a.dx, a.dy)
    ..lineTo(b.dx, b.dy)
    ..lineTo(c.dx, c.dy)
    ..lineTo(d.dx, d.dy)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);
    canvas.scale(u);

    final br = _map(_w, 0);
    final fl = _map(0, _d);
    final fr = _map(_w, _d);
    const down = Offset(0, _h);

    // Soft ground shadow (pink-tinted so it sits on the brand disc).
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(51, 72.5), width: 84, height: 10),
      Paint()
        ..color = const Color(0x597A0A2E)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.6),
    );

    // Little feet under the three visible bottom corners.
    final foot = Paint()..color = _trim;
    for (final c in [fl + down, fr + down, br + down]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(c.dx - (c == fl + down ? -2 : 8), c.dy - 1, 6, 4),
          const Radius.circular(1.5),
        ),
        foot,
      );
    }

    // Right side face (in shade) and front face (lit), each with a black
    // lacquer trim along the bottom.
    final side = _quad(br, fr, fr + down, br + down);
    canvas.drawPath(
      side,
      _linear(side.getBounds(), const [_sideLight, _sideDark]),
    );
    final front = _quad(fl, fr, fr + down, fl + down);
    canvas.drawPath(
      front,
      _linear(front.getBounds(), const [_redLight, _red, _redDeep]),
    );
    const trimH = Offset(0, 3.2);
    canvas.drawPath(
      _quad(fl + down - trimH, fr + down - trimH, fr + down, fl + down),
      Paint()..color = _trim,
    );
    canvas.drawPath(
      _quad(fr + down - trimH, br + down - trimH, br + down, fr + down),
      Paint()..color = const Color(0xFF12080C),
    );
    // Specular streak along the upper front face.
    final streak = _quad(
      fl + const Offset(3, 2.2),
      fr + const Offset(-3, 2.2),
      fr + const Offset(-3, 5.2),
      fl + const Offset(3, 5.2),
    );
    canvas.drawPath(
      streak,
      _linear(streak.getBounds(), const [Color(0x8CFFFFFF), Color(0x00FFFFFF)]),
    );
    // Shade toward the right end of the front face (light from the left).
    canvas.drawPath(
      front,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0x00000000), Color(0x00000000), Color(0x40000000)],
          stops: [0, 0.6, 1],
        ).createShader(front.getBounds()),
    );

    // Top face in box space.
    canvas.save();
    canvas.transform(_topMatrix);
    _paintTop(canvas);
    canvas.restore();

    // Crisp lit edge where the lid meets the front face.
    canvas.drawLine(
      fl + const Offset(1.2, 0.2),
      fr + const Offset(-1.2, 0.2),
      Paint()
        ..color = const Color(0x59FFFFFF)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _paintTop(Canvas canvas) {
    RRect rr(double l, double t, double r, double b, double radius) =>
        RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));
    const box = Rect.fromLTWH(0, 0, _w, _d);

    // Black lacquer lid rim with a lit back-left edge.
    canvas.drawRRect(
      rr(0, 0, _w, _d, 7),
      _linear(box, const [_lacquerTop, _lacquerBottom], vertical: false),
    );
    canvas.drawRRect(
      rr(1.2, 1.2, _w - 1.2, _d - 1.2, 6),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x8CFFFFFF), Color(0x00FFFFFF)],
          stops: [0, 0.55],
        ).createShader(box),
    );

    // Tray floor, then the four compartments; the far wall of each is
    // darker (it faces the viewer, away from the light).
    canvas.drawRRect(rr(5, 4.5, 95, 57.5, 5), Paint()..color = _floor);
    const cells = [
      Rect.fromLTRB(6.5, 6, 48, 56),
      Rect.fromLTRB(51, 6, 93.5, 29.5),
      Rect.fromLTRB(51, 32.5, 71, 56),
      Rect.fromLTRB(74, 32.5, 93.5, 56),
    ];
    for (final c in cells) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(c, const Radius.circular(4)),
        _linear(c, const [_cellTop, _cellBottom]),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(c.left, c.top, c.right, c.top + 5),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0x52000000),
      );
    }

    _paintRice(canvas, rr);
    _paintSalmon(canvas, rr);
    _paintTamago(canvas, rr);
    _paintGreens(canvas);
  }

  void _paintRice(
    Canvas canvas,
    RRect Function(double, double, double, double, double) rr,
  ) {
    const top = Rect.fromLTRB(9, 8.5, 45.5, 50);
    // Mound: shaded front lip, then the lit top.
    canvas.drawRRect(
      rr(9, 12, 45.5, 54.5, 7),
      Paint()..color = const Color(0xFFE2D5C6),
    );
    canvas.drawRRect(
      rr(top.left, top.top, top.right, top.bottom, 7),
      _linear(top, const [Color(0xFFFFFFFF), Color(0xFFF4ECE2)]),
    );
    final grain = Paint()..color = const Color(0x1F8C6A4A);
    for (final p in const [
      Offset(15, 16),
      Offset(21, 41),
      Offset(39, 18),
      Offset(14, 32),
      Offset(39, 42),
      Offset(33, 13),
    ]) {
      canvas.drawOval(Rect.fromCenter(center: p, width: 3, height: 2), grain);
    }
    final sesame = Paint()..color = const Color(0xFF3B2A2A);
    for (final p in const [
      Offset(17, 22),
      Offset(36, 38),
      Offset(40, 27),
      Offset(19, 44),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 2.4, height: 1.6),
        sesame,
      );
    }
    // Umeboshi: glossy red sphere.
    const plum = Offset(27, 29);
    canvas.drawCircle(
      plum + const Offset(1, 3),
      6.5,
      Paint()
        ..color = const Color(0x40600010)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(
      plum,
      6.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.4, -0.5),
          colors: [Color(0xFFFF5A73), Color(0xFFC4133A)],
        ).createShader(Rect.fromCircle(center: plum, radius: 6.5)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: plum + const Offset(-2.2, -2.6),
        width: 3.6,
        height: 2.4,
      ),
      Paint()..color = const Color(0xCCFFFFFF),
    );
  }

  void _paintSalmon(
    Canvas canvas,
    RRect Function(double, double, double, double, double) rr,
  ) {
    final stripe = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = const Color(0xD9FFE1D2);
    for (var i = 0; i < 3; i++) {
      final l = 54.0 + i * 13;
      final slice = Rect.fromLTRB(l, 8.5, l + 11.5, 26.5);
      canvas.drawRRect(
        rr(l, 11, l + 11.5, 28.5, 3.5),
        Paint()..color = const Color(0xFFD9512C),
      );
      canvas.drawRRect(
        rr(slice.left, slice.top, slice.right, slice.bottom, 3.5),
        _linear(slice, const [Color(0xFFFFA07A), Color(0xFFF26A3D)]),
      );
      for (final y in const [13.5, 19.0, 24.0]) {
        canvas.drawLine(Offset(l + 2.2, y + 1.5), Offset(l + 9, y - 1), stripe);
      }
      canvas.drawOval(
        Rect.fromLTWH(l + 1.8, 9.6, 4, 2.4),
        Paint()..color = const Color(0x99FFFFFF),
      );
    }
  }

  void _paintTamago(
    Canvas canvas,
    RRect Function(double, double, double, double, double) rr,
  ) {
    final layer = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFE59A12);
    for (final t in const [34.5, 44.5]) {
      final block = Rect.fromLTRB(53.5, t, 68.5, t + 7.5);
      canvas.drawRRect(
        rr(53.5, t + 2, 68.5, t + 10, 2.5),
        Paint()..color = const Color(0xFFD98A0B),
      );
      canvas.drawRRect(
        rr(block.left, block.top, block.right, block.bottom, 2.5),
        _linear(block, const [Color(0xFFFFE27A), Color(0xFFFFBE2E)]),
      );
      canvas.drawLine(Offset(55.5, t + 3), Offset(66.5, t + 3), layer);
      canvas.drawLine(Offset(55.5, t + 5.4), Offset(66.5, t + 5.4), layer);
      canvas.drawOval(
        Rect.fromLTWH(55, t + 0.8, 5, 1.6),
        Paint()..color = const Color(0xB3FFFFFF),
      );
    }
  }

  void _paintGreens(Canvas canvas) {
    void ball(Offset c, double r, Color light, Color dark) {
      canvas.drawCircle(
        c + Offset(0.6, r * 0.5),
        r,
        Paint()
          ..color = const Color(0x40000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.45, -0.5),
            colors: [light, dark],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    ball(
      const Offset(80, 41),
      5.6,
      const Color(0xFF6FCB6B),
      const Color(0xFF237A3A),
    );
    ball(
      const Offset(88, 44),
      4.8,
      const Color(0xFF8BDB72),
      const Color(0xFF2E8A45),
    );
    ball(
      const Offset(79.5, 50.5),
      4.6,
      const Color(0xFFA8E07E),
      const Color(0xFF4A9C3E),
    );
    ball(
      const Offset(88.5, 51.5),
      4.4,
      const Color(0xFFFF7A6E),
      const Color(0xFFD0202E),
    );
    canvas.drawOval(
      Rect.fromLTWH(86.4, 48.6, 2.4, 1.6),
      Paint()..color = const Color(0xD9FFFFFF),
    );
    canvas.drawOval(
      Rect.fromLTWH(77.5, 37.2, 2.6, 1.6),
      Paint()..color = const Color(0x8CFFFFFF),
    );
  }

  @override
  bool shouldRepaint(_BentoPainter oldDelegate) => false;
}
