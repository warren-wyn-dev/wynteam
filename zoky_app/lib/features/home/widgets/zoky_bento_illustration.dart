import 'package:flutter/widgets.dart';

/// Flat, code-drawn bento box used as the Home hero illustration (the repo
/// has no food photo asset yet). Purely decorative: excluded from
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

/// Draws in a 100x100 design space scaled to the canvas: a 3/4-view
/// lacquered box (dark rim, red tray) with rice, salmon, tamago and greens.
class _BentoPainter extends CustomPainter {
  const _BentoPainter();

  static const Color _shadow = Color(0x33800A2E);
  static const Color _rim = Color(0xFF2A1B22);
  static const Color _rimFront = Color(0xFF1B1016);
  static const Color _rimHighlight = Color(0xFF4A3540);
  static const Color _tray = Color(0xFFB81D3C);
  static const Color _trayDark = Color(0xFF8E1430);
  static const Color _rice = Color(0xFFFFFCF7);
  static const Color _riceShade = Color(0xFFEFE7DC);
  static const Color _sesame = Color(0xFF3B2A2A);
  static const Color _plum = Color(0xFFE2304F);
  static const Color _salmon = Color(0xFFFF8A5C);
  static const Color _salmonStripe = Color(0xFFFFD2BC);
  static const Color _tamago = Color(0xFFFFC83D);
  static const Color _tamagoLine = Color(0xFFF2A81E);
  static const Color _green = Color(0xFF3FAE5A);
  static const Color _greenDark = Color(0xFF2B8A45);
  static const Color _tomato = Color(0xFFFF4D4D);
  static const Color _leaf = Color(0xFF8BD06A);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * u) / 2, (size.height - 100 * u) / 2);
    canvas.scale(u);

    final fill = Paint()..isAntiAlias = true;
    RRect rr(double l, double t, double r, double b, double radius) =>
        RRect.fromLTRBR(l, t, r, b, Radius.circular(radius));

    // Soft ground shadow.
    canvas.drawOval(const Rect.fromLTRB(12, 76, 88, 88), fill..color = _shadow);

    // Box: front face (depth), then top rim.
    canvas.drawRRect(rr(10, 30, 90, 82, 9), fill..color = _rimFront);
    canvas.drawRRect(rr(10, 24, 90, 74, 9), fill..color = _rim);
    // Thin highlight along the top edge of the rim.
    canvas.drawRRect(
      rr(11.5, 25.2, 88.5, 72.8, 8),
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _rimHighlight,
    );

    // Red tray with darker dividers showing through the gaps.
    canvas.drawRRect(rr(15, 28.5, 85, 69.5, 5), fill..color = _trayDark);

    // Compartments.
    const gap = 2.0;
    final riceRect = rr(15.5, 29, 49 - gap / 2, 69, 4.5);
    final salmonRect = rr(49 + gap / 2, 29, 84.5, 48.5 - gap / 2, 4.5);
    final tamagoRect = rr(
      49 + gap / 2,
      48.5 + gap / 2,
      66.5 - gap / 2,
      69,
      4.5,
    );
    final greensRect = rr(66.5 + gap / 2, 48.5 + gap / 2, 84.5, 69, 4.5);
    for (final rect in [riceRect, salmonRect, tamagoRect, greensRect]) {
      canvas.drawRRect(rect, fill..color = _tray);
    }

    // Rice: mound with a soft lower shade, sesame and a pickled plum.
    canvas.drawRRect(rr(18, 31.5, 46, 66.5, 4), fill..color = _riceShade);
    canvas.drawRRect(rr(18, 31.5, 46, 63.5, 4), fill..color = _rice);
    final sesame = Paint()
      ..isAntiAlias = true
      ..color = _sesame;
    for (final p in const [
      Offset(23, 38),
      Offset(28, 52),
      Offset(39, 37),
      Offset(24, 58),
      Offset(41, 57),
      Offset(35, 44),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(center: p, width: 1.8, height: 1.1),
        sesame,
      );
    }
    canvas.drawCircle(const Offset(32, 48), 5, fill..color = _plum);
    canvas.drawCircle(
      const Offset(30.4, 46.4),
      1.4,
      fill..color = const Color(0x66FFFFFF),
    );

    // Salmon: three slices with fat stripes.
    final stripe = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.1
      ..color = _salmonStripe;
    for (var i = 0; i < 3; i++) {
      final left = 52.5 + i * 10.4;
      canvas.drawRRect(rr(left, 32, left + 9, 45.5, 3), fill..color = _salmon);
      canvas.drawLine(Offset(left + 2, 36), Offset(left + 7, 34.5), stripe);
      canvas.drawLine(Offset(left + 2, 40.5), Offset(left + 7, 39), stripe);
    }

    // Tamago: two rolled-omelette blocks with layer lines.
    final layer = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _tamagoLine;
    for (final top in const [52.0, 60.0]) {
      canvas.drawRRect(
        rr(52.5, top, 63.5, top + 6.5, 2),
        fill..color = _tamago,
      );
      canvas.drawLine(Offset(54, top + 2.4), Offset(62, top + 2.4), layer);
      canvas.drawLine(Offset(54, top + 4.4), Offset(62, top + 4.4), layer);
    }

    // Greens: broccoli florets, a leaf and a cherry tomato.
    canvas.drawCircle(const Offset(73, 57), 4.4, fill..color = _greenDark);
    canvas.drawCircle(const Offset(78.5, 55), 3.8, fill..color = _green);
    canvas.drawCircle(const Offset(75.5, 61), 3.6, fill..color = _leaf);
    canvas.drawCircle(const Offset(80, 63.5), 3.2, fill..color = _tomato);
    canvas.drawCircle(
      const Offset(79, 62.5),
      0.9,
      fill..color = const Color(0x80FFFFFF),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BentoPainter oldDelegate) => false;
}
