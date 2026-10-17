import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../domain/deal_models.dart';

/// Code-drawn "ZOKY Glossy 3D" food art for a deal card (the repo has no
/// food photos). Same light as Zoky3DIcon and the bento hero: from the
/// top-left, gradient bodies, specular highlights, soft shade bottom-right
/// and a soft ground shadow. Purely decorative (excluded from semantics);
/// its own widget so a real photo can replace it later.
class ZokyDealIllustration extends StatelessWidget {
  const ZokyDealIllustration({
    super.key,
    required this.art,
    required this.size,
  });

  final ZokyDealArt art;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: ZokyDealArtPainter(art),
      ),
    );
  }
}

/// Paints one [ZokyDealArt] in a 100x100 design space scaled to the canvas.
class ZokyDealArtPainter extends CustomPainter {
  const ZokyDealArtPainter(this.art);

  final ZokyDealArt art;

  static Paint _linear(
    Rect r,
    List<Color> colors, {
    Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
    List<double>? stops,
  }) => Paint()
    ..isAntiAlias = true
    ..shader = LinearGradient(
      begin: begin,
      end: end,
      colors: colors,
      stops: stops,
    ).createShader(r);

  static Paint _radial(Rect r, List<Color> colors, {List<double>? stops}) =>
      Paint()
        ..isAntiAlias = true
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 0.9,
          colors: colors,
          stops: stops,
        ).createShader(r);

  static Paint _blur(Color color, double sigma) => Paint()
    ..color = color
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma);

  static void _groundShadow(Canvas canvas, Offset c, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: c, width: w, height: h),
      _blur(const Color(0x407A0A2E), 2.6),
    );
  }

  /// Soft white specular blob, rotated like the 3D icons' highlight.
  static void _specular(
    Canvas canvas,
    Offset c,
    double w,
    double h, {
    double angle = -0.45,
    double alpha = 0.7,
  }) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawOval(
      r,
      _blur(Color.fromRGBO(255, 255, 255, alpha), math.max(0.4, w * 0.12)),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-w * 0.1, 0),
        width: w * 0.42,
        height: h * 0.42,
      ),
      Paint()..color = Color.fromRGBO(255, 255, 255, math.min(1, alpha + 0.2)),
    );
    canvas.restore();
  }

  /// Craggy blob (fried chicken batter): an ellipse [rx] x [ry] turned by
  /// [angle], with a bumpy edge, smoothed with quadratics. Deterministic
  /// per [seed].
  static Path _blob(
    Offset c,
    double rx,
    double ry,
    int seed, {
    double angle = 0,
    double crag = 0.09,
  }) {
    const n = 20;
    final rnd = math.Random(seed);
    final pts = <Offset>[];
    for (var i = 0; i < n; i++) {
      final t = 2 * math.pi * i / n;
      final k = 1 + crag * (rnd.nextDouble() * 2 - 1);
      final local = Offset(math.cos(t) * rx * k, math.sin(t) * ry * k);
      pts.add(
        c +
            Offset(
              local.dx * math.cos(angle) - local.dy * math.sin(angle),
              local.dx * math.sin(angle) + local.dy * math.cos(angle),
            ),
      );
    }
    final path = Path();
    Offset mid(int i) => (pts[i % n] + pts[(i + 1) % n]) / 2;
    path.moveTo(mid(0).dx, mid(0).dy);
    for (var i = 1; i <= n; i++) {
      final p = pts[i % n];
      final m = mid(i);
      path.quadraticBezierTo(p.dx, p.dy, m.dx, m.dy);
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    if (u <= 0) return;
    canvas.save();
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);
    canvas.scale(u);
    switch (art) {
      case ZokyDealArt.bubbleTea:
        _bubbleTea(canvas);
      case ZokyDealArt.friedChicken:
        _friedChicken(canvas);
      case ZokyDealArt.burger:
        _burger(canvas);
      case ZokyDealArt.noodleBowl:
        _noodleBowl(canvas);
    }
    canvas.restore();
  }

  // Bubble milk tea: clear cup, milk tea, pearls, dome lid, pink straw.
  void _bubbleTea(Canvas canvas) {
    _groundShadow(canvas, const Offset(51, 93), 46, 7);
    final cup = Path()
      ..moveTo(29, 32)
      ..lineTo(71, 32)
      ..lineTo(65.5, 87)
      ..quadraticBezierTo(65, 91, 61, 91)
      ..lineTo(39, 91)
      ..quadraticBezierTo(35, 91, 34.5, 87)
      ..close();
    final cupRect = cup.getBounds();

    // Straw behind the lid, poking out top-right.
    final straw = Path()
      ..moveTo(53, 44)
      ..lineTo(63, 3);
    canvas.drawPath(
      straw,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          colors: [Color(0xFFFF6BAA), Color(0xFFE5135D)],
        ).createShader(const Rect.fromLTRB(49, 0, 67, 44)),
    );
    canvas.drawLine(
      const Offset(57.2, 33),
      const Offset(61.6, 6),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xB3FFFFFF),
    );

    canvas.save();
    canvas.clipPath(cup);
    // Milk tea: lit top-left, deeper bottom-right.
    canvas.drawPath(
      cup,
      _linear(
        cupRect,
        const [Color(0xFFF6E0C0), Color(0xFFE2B482), Color(0xFFC98B52)],
        stops: const [0, 0.55, 1],
      ),
    );
    canvas.drawRect(
      cupRect,
      _linear(
        cupRect,
        const [Color(0x00000000), Color(0x00000000), Color(0x408A4A1E)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: const [0, 0.55, 1],
      ),
    );
    // Pearls along the bottom.
    const pearls = [
      Offset(39, 87),
      Offset(46, 88),
      Offset(53, 87.5),
      Offset(60, 87),
      Offset(42.5, 81.5),
      Offset(49.5, 82),
      Offset(56.5, 81.5),
      Offset(63, 82),
      Offset(37.5, 82),
      Offset(46, 76.5),
      Offset(53, 76),
      Offset(60, 76.5),
    ];
    for (final p in pearls) {
      final r = Rect.fromCircle(center: p, radius: 3.5);
      canvas.drawCircle(
        p,
        3.5,
        _radial(r, const [Color(0xFF7A5040), Color(0xFF2A160E)]),
      );
      canvas.drawCircle(
        p + const Offset(-1.1, -1.2),
        0.9,
        Paint()..color = const Color(0xCCFFFFFF),
      );
    }
    // Clear plastic: glossy streak left, shade right.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(33.5, 36, 38, 84),
        const Radius.circular(3),
      ),
      _linear(const Rect.fromLTRB(33, 36, 38, 84), const [
        Color(0xA6FFFFFF),
        Color(0x1AFFFFFF),
      ]),
    );
    canvas.restore();
    canvas.drawPath(
      cup,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66FFFFFF),
    );

    // Dome lid: translucent with a bright rim and highlight.
    final dome = Path()
      ..moveTo(27, 32)
      ..cubicTo(28, 14, 72, 14, 73, 32)
      ..close();
    canvas.drawPath(
      dome,
      _linear(dome.getBounds(), const [Color(0x8CFFFFFF), Color(0x40FFE0EC)]),
    );
    canvas.drawPath(
      dome,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xCCFFFFFF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTRB(26, 30, 74, 35),
        const Radius.circular(2.5),
      ),
      _linear(const Rect.fromLTRB(26, 30, 74, 35), const [
        Color(0xFFFFFFFF),
        Color(0xFFF3D3E0),
      ]),
    );
    _specular(canvas, const Offset(38, 23), 12, 5, alpha: 0.75);
  }

  // Fried chicken: a crispy drumstick and two craggy pieces on a plate,
  // with a red chili at the back (like the mockup photo).
  void _friedChicken(Canvas canvas) {
    _groundShadow(canvas, const Offset(51, 86), 86, 12);
    // Plate.
    const plate = Rect.fromLTRB(7, 62, 95, 89);
    canvas.drawOval(
      plate,
      _linear(plate, const [Color(0xFFFFFFFF), Color(0xFFE9DCE2)]),
    );
    canvas.drawOval(
      const Rect.fromLTRB(19, 65.5, 83, 85),
      _linear(const Rect.fromLTRB(19, 65, 83, 85), const [
        Color(0xFFEDE1E6),
        Color(0xFFFFFFFF),
      ]),
    );

    void piece(Path body, Offset c, double r, int seed) {
      final bounds = body.getBounds();
      canvas.drawPath(
        body.shift(const Offset(1.5, 3)),
        _blur(const Color(0x597A3A0A), 2),
      );
      canvas.drawPath(
        body,
        _radial(
          bounds,
          const [Color(0xFFFFCF73), Color(0xFFE48C24), Color(0xFFA14C0C)],
          stops: const [0, 0.5, 1],
        ),
      );
      canvas.save();
      canvas.clipPath(body);
      // Crispy batter: bumps with a lit top-left and a shaded bottom-right.
      final rnd = math.Random(seed);
      for (var i = 0; i < 46; i++) {
        final a = rnd.nextDouble() * 2 * math.pi;
        final d = math.sqrt(rnd.nextDouble()) * r;
        final p = c + Offset.fromDirection(a, d);
        final s = 0.8 + rnd.nextDouble() * 1.5;
        canvas.drawCircle(
          p + Offset(s * 0.3, s * 0.35),
          s,
          Paint()..color = const Color(0x38803404),
        );
        canvas.drawCircle(
          p,
          s * 0.75,
          Paint()..color = const Color(0x40FFE6A8),
        );
      }
      // Inner shade bottom-right.
      canvas.drawCircle(
        c + Offset(r * 0.6, r * 0.65),
        r * 0.95,
        _blur(const Color(0x4D7A2E04), r * 0.3),
      );
      canvas.restore();
      _specular(
        canvas,
        c + Offset(-r * 0.4, -r * 0.45),
        r * 0.55,
        r * 0.26,
        alpha: 0.55,
      );
    }

    // Drumstick: bone (behind) poking out top-right of a teardrop.
    final bone = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFE6D6C2)],
      ).createShader(const Rect.fromLTRB(50, 30, 72, 52));
    canvas.drawLine(const Offset(52, 50), const Offset(65, 37), bone);
    for (final k in const [Offset(63.5, 33.5), Offset(68.5, 38)]) {
      final r = Rect.fromCircle(center: k, radius: 3.8);
      canvas.drawCircle(
        k,
        3.8,
        _radial(r, const [Color(0xFFFFFFFF), Color(0xFFDCCAB3)]),
      );
    }
    const back = Offset(70, 61);
    piece(_blob(back, 15, 11.5, 5, angle: -0.2), back, 14, 5);
    const stick = Offset(42, 60);
    piece(_blob(stick, 21, 13, 9, angle: -0.75), stick, 19, 9);
    const front = Offset(59, 72);
    piece(_blob(front, 14, 10, 13, angle: 0.15), front, 13, 13);
    // Red chili on the front of the plate.
    final chili = Path()
      ..moveTo(16, 74)
      ..quadraticBezierTo(24, 82, 38, 81);
    canvas.drawPath(
      chili,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF5A4E), Color(0xFFB8141E)],
        ).createShader(const Rect.fromLTRB(13, 71, 41, 85)),
    );
    canvas.drawLine(
      const Offset(21, 77.6),
      const Offset(30, 80.2),
      Paint()
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xB3FFFFFF),
    );
    canvas.drawLine(
      const Offset(38, 81),
      const Offset(43, 79),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF3E9A2E),
    );
  }

  // Cheeseburger: sesame bun, lettuce, tomato, cheese drip, patty.
  void _burger(Canvas canvas) {
    _groundShadow(canvas, const Offset(51, 90), 74, 9);
    // Bottom bun.
    final bottom = RRect.fromLTRBAndCorners(
      18,
      73,
      82,
      87,
      topLeft: const Radius.circular(4),
      topRight: const Radius.circular(4),
      bottomLeft: const Radius.circular(9),
      bottomRight: const Radius.circular(9),
    );
    canvas.drawRRect(
      bottom,
      _linear(bottom.outerRect, const [Color(0xFFF2AE55), Color(0xFFC06A1C)]),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(22, 74.5, 60, 77, const Radius.circular(1.5)),
      Paint()..color = const Color(0x59FFFFFF),
    );
    // Patty.
    final patty = RRect.fromLTRBR(15, 62, 85, 75, const Radius.circular(6.5));
    canvas.drawRRect(
      patty,
      _linear(patty.outerRect, const [
        Color(0xFF8A4A2A),
        Color(0xFF5A2A14),
        Color(0xFF3E1C0C),
      ]),
    );
    final grill = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x4DFFD3B0);
    for (var x = 22.0; x < 80; x += 7) {
      canvas.drawLine(Offset(x, 65.5), Offset(x + 3, 64.5), grill);
    }
    // Cheese with drips.
    final cheese = Path()
      ..moveTo(16, 58)
      ..lineTo(84, 58)
      ..lineTo(84, 63)
      ..lineTo(74, 63)
      ..quadraticBezierTo(71, 71, 68, 63)
      ..lineTo(44, 63)
      ..quadraticBezierTo(40.5, 73, 37, 63)
      ..lineTo(16, 63)
      ..close();
    canvas.drawPath(
      cheese,
      _linear(cheese.getBounds(), const [Color(0xFFFFE066), Color(0xFFF5A900)]),
    );
    // Tomato.
    canvas.drawRRect(
      RRect.fromLTRBR(19, 54, 81, 59, const Radius.circular(2.5)),
      _linear(const Rect.fromLTRB(19, 54, 81, 59), const [
        Color(0xFFFF6B5A),
        Color(0xFFD42A2A),
      ]),
    );
    // Lettuce: wavy edge hanging over.
    final lettuce = Path()..moveTo(13, 53);
    for (var i = 0; i < 9; i++) {
      final x0 = 13 + i * 8.4;
      lettuce.quadraticBezierTo(x0 + 4.2, 61, x0 + 8.4, 53);
    }
    lettuce
      ..lineTo(87, 49)
      ..lineTo(13, 49)
      ..close();
    canvas.drawPath(
      lettuce,
      _linear(lettuce.getBounds(), const [
        Color(0xFFA6E36E),
        Color(0xFF3E9A2E),
      ]),
    );
    // Top bun dome.
    final top = Path()
      ..moveTo(15, 51)
      ..cubicTo(14, 26, 33, 17, 50, 17)
      ..cubicTo(67, 17, 86, 26, 85, 51)
      ..quadraticBezierTo(85, 54, 81, 54)
      ..lineTo(19, 54)
      ..quadraticBezierTo(15, 54, 15, 51)
      ..close();
    final topRect = top.getBounds();
    canvas.drawPath(
      top,
      _radial(
        topRect,
        const [Color(0xFFFFCB7E), Color(0xFFEB9036), Color(0xFFB65C16)],
        stops: const [0, 0.6, 1],
      ),
    );
    canvas.save();
    canvas.clipPath(top);
    canvas.drawCircle(
      const Offset(76, 50),
      26,
      _blur(const Color(0x338A3A06), 7),
    );
    canvas.restore();
    // Sesame seeds.
    const seeds = [
      (Offset(36, 30), 0.6),
      (Offset(50, 25), -0.2),
      (Offset(63, 31), -0.7),
      (Offset(43, 38), 0.3),
      (Offset(57, 39), -0.4),
      (Offset(29, 42), 0.9),
      (Offset(71, 42), -0.9),
    ];
    for (final (p, a) in seeds) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(a);
      canvas.drawOval(
        const Rect.fromLTRB(-2.2, -1.1, 2.2, 1.3),
        Paint()..color = const Color(0x40793A0A),
      );
      canvas.drawOval(
        const Rect.fromLTRB(-2.2, -1.4, 2.2, 1),
        Paint()..color = const Color(0xFFFFF4DA),
      );
      canvas.restore();
    }
    _specular(canvas, const Offset(34, 27), 16, 6.5, alpha: 0.7);
  }

  // Ramen bowl: glossy pink bowl, broth, noodles, egg, chashu, scallion,
  // chopsticks resting at the back.
  void _noodleBowl(Canvas canvas) {
    _groundShadow(canvas, const Offset(51, 90), 66, 9);
    // Chopsticks behind the bowl.
    final wood = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFFE8B57A), Color(0xFF9C6430)],
      ).createShader(const Rect.fromLTRB(54, 6, 94, 50));
    canvas.drawLine(const Offset(58, 48), const Offset(86, 8), wood);
    canvas.drawLine(const Offset(64, 49), const Offset(94, 13), wood);

    // Bowl body.
    final bowl = Path()
      ..moveTo(10, 50)
      ..cubicTo(11, 73, 29, 85, 50, 85)
      ..cubicTo(71, 85, 89, 73, 90, 50)
      ..close();
    canvas.drawRRect(
      RRect.fromLTRBR(37, 82, 63, 89, const Radius.circular(3)),
      _linear(const Rect.fromLTRB(37, 82, 63, 89), const [
        Color(0xFFD1104F),
        Color(0xFF9E0E3E),
      ]),
    );
    canvas.drawPath(
      bowl,
      _linear(bowl.getBounds(), const [Color(0xFFFF6BAA), Color(0xFFE5135D)]),
    );
    canvas.save();
    canvas.clipPath(bowl);
    canvas.drawCircle(
      const Offset(80, 82),
      30,
      _blur(const Color(0x669E0E3E), 8),
    );
    // White band like the logo's smile.
    canvas.drawPath(
      Path()
        ..moveTo(14, 60)
        ..quadraticBezierTo(50, 72, 86, 60)
        ..lineTo(85, 63.5)
        ..quadraticBezierTo(50, 75.5, 15, 63.5)
        ..close(),
      Paint()..color = const Color(0xD9FFFFFF),
    );
    canvas.restore();
    _specular(canvas, const Offset(24, 62), 12, 5, angle: 0.9, alpha: 0.65);

    // Rim and broth.
    const rim = Rect.fromLTRB(9.5, 41, 90.5, 59);
    canvas.drawOval(
      rim,
      _linear(rim, const [Color(0xFFFFC2DA), Color(0xFFFF7FB2)]),
    );
    const broth = Rect.fromLTRB(14, 43.5, 86, 57);
    canvas.drawOval(
      broth,
      _linear(broth, const [Color(0xFFF7B868), Color(0xFFD9772E)]),
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(broth));
    // Noodles: wavy golden strands.
    final noodle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFE39A);
    for (var row = 0; row < 3; row++) {
      final y = 50.5 + row * 2.4;
      final p = Path()..moveTo(18, y);
      for (var x = 18.0; x < 84; x += 6) {
        p.quadraticBezierTo(x + 3, y - 2.2, x + 6, y);
      }
      canvas.drawPath(p, noodle);
    }
    canvas.restore();
    // Chashu slice.
    const pork = Rect.fromLTRB(52, 43.5, 74, 52);
    canvas.drawOval(
      pork,
      _linear(pork, const [Color(0xFFF7C1A6), Color(0xFFC9714E)]),
    );
    canvas.drawOval(
      pork.deflate(2.2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x80FFFFFF),
    );
    // Half egg.
    const egg = Rect.fromLTRB(25, 43, 45, 53.5);
    canvas.drawOval(
      egg.shift(const Offset(0.5, 1.2)),
      _blur(const Color(0x407A3A06), 1),
    );
    canvas.drawOval(
      egg,
      _linear(egg, const [Color(0xFFFFFFFF), Color(0xFFF1E6DA)]),
    );
    final yolk = Rect.fromCenter(
      center: const Offset(35.5, 48.2),
      width: 9,
      height: 6,
    );
    canvas.drawOval(
      yolk,
      _radial(yolk, const [Color(0xFFFFC13A), Color(0xFFE5791A)]),
    );
    canvas.drawOval(
      const Rect.fromLTRB(28.5, 44.5, 33, 46.3),
      Paint()..color = const Color(0xE6FFFFFF),
    );
    // Scallion rings.
    final green = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0xFF3FA544);
    for (final p in const [
      Offset(48, 53),
      Offset(77, 52),
      Offset(21, 51),
      Offset(70, 54.5),
      Offset(80.5, 48.5),
    ]) {
      canvas.drawCircle(p, 1.6, green);
    }
  }

  @override
  bool shouldRepaint(ZokyDealArtPainter oldDelegate) => oldDelegate.art != art;
}
