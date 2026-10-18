import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Small UI glyphs drawn in code instead of taken from an icon font.
///
/// Why: Material icon glyphs come from a font that `flutter build web`
/// tree-shakes down to the code points the build uses. If a preview is
/// refreshed by copying only `main.dart.js`, the old font stays behind and
/// every icon added since renders as empty space (Founder's iPad preview,
/// 2026-10-18: ▾, the coupon ticket and the filter icon were blank). Painted
/// glyphs ship inside the code, so they can never go missing. Since
/// ZOKY-128 every icon on Home + Food (and their sheets/states) is painted.
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

  /// iOS back chevron (food header back on iOS/macOS).
  chevronLeft,

  /// Material back arrow (food header back on Android and others).
  arrowLeft,

  /// Small "›" after "ดูทั้งหมด". Same geometry and ink weight as the
  /// Material rounded chevron it replaces, so Home looks the same (only
  /// sub-pixel anti-aliasing differs).
  chevronRight,

  /// Magnifier (food search field).
  search,

  /// Clock face ("ปิดอยู่" label).
  clock,

  /// Filled disc with a cut-out check (selected address).
  checkCircle,

  /// Map pin (saved address).
  pin,

  /// Circled "i" (demo address note).
  info,

  /// Plus ("เพิ่มที่อยู่ใหม่").
  plus,

  /// Wi-Fi fan with a slash (offline states).
  wifiOff,

  /// Storefront with an awning (no stores state).
  store,

  /// Heart outline (favorites sheet).
  heart,

  /// Fork and knife (store cover without art).
  utensils,
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
      case ZokyLineGlyph.chevronLeft:
        final mark = Path()
          ..moveTo(15.2, 4.6)
          ..lineTo(7.8, 12)
          ..lineTo(15.2, 19.4);
        canvas.drawPath(mark, line..strokeWidth = 2.2);
      case ZokyLineGlyph.arrowLeft:
        final arrow = Path()
          ..moveTo(19.5, 12)
          ..lineTo(4.8, 12)
          ..moveTo(11, 5.8)
          ..lineTo(4.8, 12)
          ..lineTo(11, 18.2);
        canvas.drawPath(arrow, line..strokeWidth = 2);
      case ZokyLineGlyph.chevronRight:
        // Centre line of Material's chevron_right_rounded (24-unit grid);
        // stroke 1.8 matches the font glyph's rendered ink.
        final mark = Path()
          ..moveTo(10, 7.41)
          ..lineTo(14.59, 12)
          ..lineTo(10, 16.59);
        canvas.drawPath(mark, line..strokeWidth = 1.8);
      case ZokyLineGlyph.search:
        line.strokeWidth = 2.1;
        canvas.drawCircle(const Offset(10.5, 10.5), 6.3, line);
        canvas.drawLine(
          const Offset(15.3, 15.3),
          const Offset(19.8, 19.8),
          line,
        );
      case ZokyLineGlyph.clock:
        canvas.drawCircle(const Offset(12, 12), 8.6, line);
        final hands = Path()
          ..moveTo(12, 7.4)
          ..lineTo(12, 12)
          ..lineTo(15.2, 13.9);
        canvas.drawPath(hands, line);
      case ZokyLineGlyph.checkCircle:
        canvas.saveLayer(const Rect.fromLTWH(0, 0, 24, 24), Paint());
        canvas.drawCircle(const Offset(12, 12), 10, fill);
        final mark = Path()
          ..moveTo(7.4, 12.3)
          ..lineTo(10.5, 15.3)
          ..lineTo(16.6, 9.2);
        canvas.drawPath(
          mark,
          line
            ..strokeWidth = 2.2
            ..blendMode = BlendMode.clear,
        );
        canvas.restore();
      case ZokyLineGlyph.pin:
        final drop = Path()
          ..moveTo(12, 21)
          ..cubicTo(12, 21, 5.6, 15, 5.6, 9.8)
          ..arcToPoint(
            const Offset(18.4, 9.8),
            radius: const Radius.circular(6.4),
          )
          ..cubicTo(18.4, 15, 12, 21, 12, 21)
          ..close();
        canvas.drawPath(drop, line);
        canvas.drawCircle(const Offset(12, 9.8), 2.3, line);
      case ZokyLineGlyph.info:
        canvas.drawCircle(const Offset(12, 12), 8.6, line);
        canvas.drawLine(const Offset(12, 11), const Offset(12, 16.2), line);
        canvas.drawCircle(const Offset(12, 7.9), 1.2, fill);
      case ZokyLineGlyph.plus:
        line.strokeWidth = 2.1;
        canvas.drawLine(const Offset(12, 5), const Offset(12, 19), line);
        canvas.drawLine(const Offset(5, 12), const Offset(19, 12), line);
      case ZokyLineGlyph.wifiOff:
        const c = Offset(12, 18.6);
        for (final r in [4.6, 8.8]) {
          canvas.drawArc(
            Rect.fromCircle(center: c, radius: r),
            -math.pi * 3 / 4,
            math.pi / 2,
            false,
            line,
          );
        }
        canvas.drawCircle(c, 1.4, fill);
        canvas.drawLine(const Offset(4, 4), const Offset(20, 20), line);
      case ZokyLineGlyph.store:
        final awning = Path()
          ..moveTo(5.6, 4.4)
          ..lineTo(18.4, 4.4)
          ..lineTo(20.2, 9.2)
          ..lineTo(3.8, 9.2)
          ..close();
        canvas.drawPath(awning, line);
        final body = Path()
          ..moveTo(5.4, 9.2)
          ..lineTo(5.4, 19.6)
          ..lineTo(18.6, 19.6)
          ..lineTo(18.6, 9.2)
          ..moveTo(10, 19.6)
          ..lineTo(10, 14.6)
          ..lineTo(14, 14.6)
          ..lineTo(14, 19.6);
        canvas.drawPath(body, line);
      case ZokyLineGlyph.heart:
        final heart = Path()
          ..moveTo(12, 19.6)
          ..cubicTo(12, 19.6, 3.6, 14.4, 3.6, 9)
          ..cubicTo(3.6, 6.4, 5.5, 4.6, 7.9, 4.6)
          ..cubicTo(9.6, 4.6, 11.1, 5.5, 12, 7)
          ..cubicTo(12.9, 5.5, 14.4, 4.6, 16.1, 4.6)
          ..cubicTo(18.5, 4.6, 20.4, 6.4, 20.4, 9)
          ..cubicTo(20.4, 14.4, 12, 19.6, 12, 19.6)
          ..close();
        canvas.drawPath(heart, line);
      case ZokyLineGlyph.utensils:
        final fork = Path()
          ..moveTo(7.2, 3.6)
          ..lineTo(7.2, 20.4)
          ..moveTo(4.8, 3.6)
          ..lineTo(4.8, 8.2)
          ..quadraticBezierTo(4.8, 10.6, 7.2, 10.6)
          ..quadraticBezierTo(9.6, 10.6, 9.6, 8.2)
          ..lineTo(9.6, 3.6);
        canvas.drawPath(fork, line);
        final knife = Path()
          ..moveTo(16.8, 20.4)
          ..lineTo(16.8, 3.6)
          ..cubicTo(18.9, 4.6, 19.6, 8, 19.4, 12.4)
          ..lineTo(16.8, 12.4);
        canvas.drawPath(knife, line);
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
