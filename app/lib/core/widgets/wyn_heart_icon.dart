import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';

/// The heart WYN draws wherever a Like is shown -- WYN-108.
///
/// `design-reference/01-home.tsx` imports its heart from `lucide-react`,
/// but the app was built with Material's `Icons.favorite`, which is a
/// visibly different shape: wider shoulders, a shallower notch, a
/// rounder point. Nobody chose that -- it is simply what you get when a
/// design drawn with one icon set is implemented with another. Founder,
/// 2026-09-04, looking at the two side by side: "รูปหัวใจ ทำสวยๆหน่อย",
/// then picking the reference's own shape.
///
/// Drawn rather than shipped as an asset: the app has no SVG package and
/// this is one icon, so a `CustomPainter` over the reference path costs
/// nothing at runtime and adds no dependency -- the same reasoning
/// ProfilePhotoCropScreen used when it hand-rolled pan/zoom instead of
/// taking on `crop_your_image`.
///
/// Colour is the caller's: [WynColors.iconIdle] at rest,
/// [WynColors.iconLikeActive] once liked. This widget only knows the
/// shape.
class WynHeartIcon extends StatelessWidget {
  const WynHeartIcon({
    super.key,
    required this.filled,
    required this.size,
    required this.color,
    this.strokeWidth = 1.5,
    this.shadows = const [],
  });

  /// Solid when the viewer has liked this, outline when they have not.
  final bool filled;

  final double size;
  final Color color;

  /// Outline weight, in the reference's own 24-unit coordinate space --
  /// so it scales with [size] exactly as the SVG's `stroke-width` does,
  /// rather than getting heavier on a small icon and thinner on a large
  /// one.
  final double strokeWidth;

  /// Drawn under the heart, same as [Icon.shadows] did.
  ///
  /// Only the double-tap burst uses this: a white heart thrown over an
  /// arbitrary photo is invisible on a pale one without it, which is why
  /// the reference gives that heart a `drop-shadow` of its own.
  final List<Shadow> shadows;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WynHeartPainter(
          filled: filled,
          color: color,
          strokeWidth: strokeWidth,
          shadows: shadows,
        ),
      ),
    );
  }
}

class _WynHeartPainter extends CustomPainter {
  const _WynHeartPainter({
    required this.filled,
    required this.color,
    required this.strokeWidth,
    required this.shadows,
  });

  final bool filled;
  final Color color;
  final double strokeWidth;
  final List<Shadow> shadows;

  /// The reference's own coordinate space. Every number below is read
  /// straight off lucide's heart path, converted from SVG's relative
  /// commands to absolute points:
  ///
  ///   M20.84 4.61 a5.5 5.5 0 0 0-7.78 0 L12 5.67 l-1.06-1.06
  ///   a5.5 5.5 0 0 0-7.78 7.78 l1.06 1.06 L12 21.23 l7.78-7.78
  ///   l1.06-1.06 a5.5 5.5 0 0 0 0-7.78 z
  ///
  /// The three arcs are the two lobes and the right shoulder, all
  /// radius 5.5, all `largeArc: false, clockwise: false` -- SVG's
  /// `0 0` flag pair.
  static const double _viewBox = 24;
  static const Radius _lobe = Radius.circular(5.5);

  static Path _heartPath() => Path()
    ..moveTo(20.84, 4.61)
    ..arcToPoint(const Offset(13.06, 4.61),
        radius: _lobe, largeArc: false, clockwise: false)
    ..lineTo(12, 5.67)
    ..lineTo(10.94, 4.61)
    ..arcToPoint(const Offset(3.16, 12.39),
        radius: _lobe, largeArc: false, clockwise: false)
    ..lineTo(4.22, 13.45)
    ..lineTo(12, 21.23)
    ..lineTo(19.78, 13.45)
    ..lineTo(20.84, 12.39)
    ..arcToPoint(const Offset(20.84, 4.61),
        radius: _lobe, largeArc: false, clockwise: false)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    final path = _heartPath();
    canvas.save();
    canvas.scale(scale);

    for (final shadow in shadows) {
      canvas.save();
      // Offsets and blur are given in logical pixels, but the canvas is
      // scaled to the 24-unit space, so they have to come back out of it
      // to land where the caller meant.
      canvas.translate(shadow.offset.dx / scale, shadow.offset.dy / scale);
      canvas.drawPath(
        path,
        Paint()
          ..color = shadow.color
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            Shadow.convertRadiusToSigma(shadow.blurRadius) / scale,
          ),
      );
      canvas.restore();
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..isAntiAlias = true
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        // Scaling the canvas scales the stroke with it, which is what
        // makes this behave like the SVG's own stroke-width.
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WynHeartPainter oldDelegate) =>
      oldDelegate.filled != filled ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      !listEquals(oldDelegate.shadows, shadows);
}
