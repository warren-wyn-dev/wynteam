import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_glossy_heart_button.dart';
import '../../../core/widgets/zoky_glossy_surface.dart';
import '../../../core/widgets/zoky_wordmark.dart';

/// Home Phase 1 header (Founder mockup "เฟส 1 Header + Logo"): the shared
/// "ZOKY Glossy 3D" brand surface ([ZokyGlossySurface], same gradient and
/// gloss as the hero card) running under the status bar, the original
/// wordmark on the left, a white glossy "ร้านโปรด" button with a 3D heart
/// on the right, soft lighter pink waves, and a white sheet with large
/// rounded top corners that joins the content below.
///
/// Status bar icons are light over the pink on iOS and Android (the region
/// only covers this header, so once it scrolls away the shell's dark style
/// applies again).
class ZokyHomeHeader extends StatelessWidget {
  const ZokyHomeHeader({super.key, required this.onFavorites});

  final VoidCallback onFavorites;

  /// Light status bar content over the pink header. statusBarBrightness is
  /// the iOS field (dark background -> light icons); the other two are
  /// Android.
  static const SystemUiOverlayStyle systemOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  );

  /// Radius of the white sheet that overlaps the bottom of the pink.
  static const double sheetRadius = ZokyRadius.xxlValue + 4;

  /// Visible circle of the heart button; the tap target is [tapTarget].
  static const double heartDiameter = 44;
  static const double tapTarget = ZokySizes.tapTargetAndroid;

  /// Wordmark width: ~36% of the screen, clamped so it stays compact on
  /// small phones and does not grow on tablets/landscape.
  static double wordmarkWidth(double screenWidth) =>
      (screenWidth * 0.36).clamp(124.0, 164.0);

  /// Minimum height of the logo row, so small phones keep a ~90pt header.
  static const double minRowHeight = 74;

  /// Gloss band from the top of the screen to just below the status bar:
  /// the same sheen recipe as the hero card, but held to [glossOpacity] so
  /// white status bar glyphs keep >= 3:1 over the swoosh (measured 3.0+:1
  /// at 375 and 430pt; the card can use the full 35% because its band
  /// only sits behind the white pill).
  static double glossHeight(double topInset) => topInset + 28;
  static const double glossOpacity = 0.07;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final logoWidth = wordmarkWidth(MediaQuery.sizeOf(context).width);
    final rowHeight = math.max(
      logoWidth / ZokyWordmark.aspectRatio,
      minRowHeight,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: ZokyGlossySurface(
        glossHeight: glossHeight(topInset),
        glossOpacity: glossOpacity,
        glossInset: 0,
        rim: false,
        shadow: false,
        child: CustomPaint(
          painter: const ZokyHeaderWavesPainter(),
          child: Stack(
            // Let the white sheet overlap 1px past the bottom (no hairline seam).
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  ZokySpacing.s10,
                  topInset + ZokySpacing.s3,
                  ZokySpacing.s10 - (tapTarget - heartDiameter) / 2,
                  ZokySpacing.s5 + sheetRadius,
                ),
                child: SizedBox(
                  height: rowHeight,
                  child: Row(
                    children: [
                      ZokyWordmark(width: logoWidth),
                      const Spacer(),
                      ZokyGlossyHeartButton(
                        label: ZokyStrings.favoriteStores,
                        onPressed: onFavorites,
                        diameter: heartDiameter,
                        tapTarget: tapTarget,
                      ),
                    ],
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: sheetRadius + 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ZokyColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(sheetRadius),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two soft, lighter pink waves over the glossy surface (decorative only).
/// Shared with the food landing page header.
class ZokyHeaderWavesPainter extends CustomPainter {
  const ZokyHeaderWavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Large soft swoosh sweeping in from the top right.
    final swoosh = Path()
      ..moveTo(w * 0.52, 0)
      ..cubicTo(w * 0.62, h * 0.38, w * 0.80, h * 0.58, w, h * 0.50)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(
      swoosh,
      Paint()..color = ZokyColors.neutral0.withValues(alpha: 0.10),
    );

    // Gentle wave across the lower half, behind the logo.
    final wave = Path()
      ..moveTo(0, h * 0.58)
      ..cubicTo(w * 0.30, h * 0.40, w * 0.62, h * 0.86, w, h * 0.66)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
      wave,
      Paint()..color = ZokyColors.neutral0.withValues(alpha: 0.08),
    );
  }

  @override
  bool shouldRepaint(ZokyHeaderWavesPainter oldDelegate) => false;
}
