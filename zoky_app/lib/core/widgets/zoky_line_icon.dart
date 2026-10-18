import 'package:flutter/widgets.dart';

/// Small UI glyphs drawn in code instead of taken from an icon font.
///
/// Why: Material icon glyphs come from a font that `flutter build web`
/// tree-shakes down to the code points the build uses. If a preview is
/// refreshed by copying only `main.dart.js`, the old font stays behind and
/// every icon added since renders as empty space (Founder's iPad preview,
/// 2026-10-18: ▾, the coupon ticket and the filter icon were blank). Painted
/// glyphs ship inside the code, so they can never go missing.
enum ZokyLineGlyph {
  /// Small filled ▾ after the header address (opens the address sheet).
  caretDown,

  /// Coupon ticket with side notches and a dashed tear line.
  ticket,

  /// Three slider lines with knobs ("ตัวกรอง").
  sliders,

  /// Delivery scooter with a box on the back ("จัดส่ง", free delivery).
  scooter,

  /// Shopping bag with a handle ("รับเองที่ร้าน").
  bag,

  /// Check mark (selected filter, collected coupon).
  check,

  /// Shopping trolley (floating cart button).
  cart,
}

/// One [ZokyLineGlyph] at [size] in [color] (rounded 24-unit line art,
/// stroke ~1.9 units). Decorative: the surrounding control carries the
/// label.
class ZokyLineIcon extends StatelessWidget {
  const ZokyLineIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    required this.color,
  });

  final ZokyLineGlyph glyph;
  final double size;
  final Color color;

  /// Identifies the painted box of [glyph] (tests).
  static Key keyFor(ZokyLineGlyph glyph) =>
      ValueKey('ZokyLineIcon.${glyph.name}');

  /// Stroke width on the 24-unit grid.
  static const double stroke = 1.9;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        key: keyFor(glyph),
        size: Size.square(size),
        painter: _LineGlyphPainter(glyph, color),
      ),
    );
  }
}

class _LineGlyphPainter extends CustomPainter {
  const _LineGlyphPainter(this.glyph, this.color);

  final ZokyLineGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final scale = size.shortestSide / 24;
    canvas.save();
    canvas.translate(
      (size.width - 24 * scale) / 2,
      (size.height - 24 * scale) / 2,
    );
    canvas.scale(scale);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = ZokyLineIcon.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    switch (glyph) {
      case ZokyLineGlyph.caretDown:
        // Rounded filled triangle (fill + stroke rounds its corners).
        final caret = Path()
          ..moveTo(7, 9.5)
          ..lineTo(17, 9.5)
          ..lineTo(12, 15)
          ..close();
        canvas.drawPath(caret, fill);
        canvas.drawPath(caret, line..strokeWidth = 1.6);
      case ZokyLineGlyph.ticket:
        canvas.drawPath(_ticket(), line);
        for (final y in [8.6, 12.0, 15.4]) {
          canvas.drawLine(Offset(15, y - 0.6), Offset(15, y + 0.6), line);
        }
      case ZokyLineGlyph.sliders:
        for (final (y, knob) in [(6.5, 15.5), (12.0, 8.5), (17.5, 13.5)]) {
          const r = 2.3;
          canvas.drawLine(Offset(3.5, y), Offset(knob - r, y), line);
          canvas.drawLine(Offset(knob + r, y), Offset(20.5, y), line);
          canvas.drawCircle(Offset(knob, y), r, line);
        }
      case ZokyLineGlyph.scooter:
        // Delivery box, body, steering column, handlebar, wheels.
        canvas.drawRRect(
          RRect.fromLTRBR(2.8, 5.2, 10.2, 11.2, const Radius.circular(1.4)),
          fill,
        );
        final body = Path()
          ..moveTo(3.2, 15.4)
          ..quadraticBezierTo(3.4, 13.1, 6, 13.1)
          ..lineTo(13.2, 13.1)
          ..lineTo(15.4, 6.6)
          ..moveTo(13.8, 6.4)
          ..lineTo(17.6, 6.4)
          ..moveTo(15.4, 6.6)
          ..lineTo(17.9, 15);
        canvas.drawPath(body, line);
        canvas.drawCircle(const Offset(6.4, 17.4), 2.4, line);
        canvas.drawCircle(const Offset(18.4, 17.4), 2.4, line);
      case ZokyLineGlyph.bag:
        final body = Path()
          ..moveTo(5.6, 8.2)
          ..lineTo(18.4, 8.2)
          ..lineTo(19.2, 19.2)
          ..quadraticBezierTo(19.3, 20.6, 17.9, 20.6)
          ..lineTo(6.1, 20.6)
          ..quadraticBezierTo(4.7, 20.6, 4.8, 19.2)
          ..close();
        canvas.drawPath(body, fill);
        canvas.drawPath(body, line);
        final handle = Path()
          ..moveTo(9, 10.6)
          ..lineTo(9, 6.6)
          ..arcToPoint(const Offset(15, 6.6), radius: const Radius.circular(3))
          ..lineTo(15, 10.6);
        canvas.drawPath(handle, line);
      case ZokyLineGlyph.check:
        final mark = Path()
          ..moveTo(5, 12.6)
          ..lineTo(9.8, 17.2)
          ..lineTo(19, 7.4);
        canvas.drawPath(mark, line..strokeWidth = 2.2);
      case ZokyLineGlyph.cart:
        final frame = Path()
          ..moveTo(2.6, 4.2)
          ..lineTo(5.2, 4.2)
          ..lineTo(7.8, 15)
          ..lineTo(17.6, 15)
          ..lineTo(19.8, 7.6)
          ..lineTo(6.2, 7.6);
        canvas.drawPath(frame, line);
        canvas.drawCircle(const Offset(9, 19), 1.6, fill);
        canvas.drawCircle(const Offset(16.6, 19), 1.6, fill);
    }
    canvas.restore();
  }

  /// Rounded ticket outline with a half-circle notch on each side.
  static Path _ticket() {
    const l = 3.0, t = 6.0, r = 21.0, b = 18.0, c = 2.0, n = 2.0;
    return Path()
      ..moveTo(l + c, t)
      ..lineTo(r - c, t)
      ..arcToPoint(const Offset(r, t + c), radius: const Radius.circular(c))
      ..lineTo(r, 12 - n)
      ..arcToPoint(
        const Offset(r, 12 + n),
        radius: const Radius.circular(n),
        clockwise: false,
      )
      ..lineTo(r, b - c)
      ..arcToPoint(const Offset(r - c, b), radius: const Radius.circular(c))
      ..lineTo(l + c, b)
      ..arcToPoint(const Offset(l, b - c), radius: const Radius.circular(c))
      ..lineTo(l, 12 + n)
      ..arcToPoint(
        const Offset(l, 12 - n),
        radius: const Radius.circular(n),
        clockwise: false,
      )
      ..lineTo(l, t + c)
      ..arcToPoint(const Offset(l + c, t), radius: const Radius.circular(c))
      ..close();
  }

  @override
  bool shouldRepaint(_LineGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
