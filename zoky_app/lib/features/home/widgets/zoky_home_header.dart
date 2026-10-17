import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/adaptive/zoky_icons.dart';
import '../../../core/design/zoky_colors.dart';
import '../../../core/design/zoky_tokens.dart';
import '../../../core/l10n/zoky_strings.dart';
import '../../../core/widgets/zoky_wordmark.dart';

/// Home Phase 1 header (Founder mockup "เฟส 1 Header + Logo"): brand pink
/// gradient running under the status bar, the original wordmark on the
/// left, a white circular "ร้านโปรด" heart button on the right, soft lighter
/// pink waves, and a white sheet with large rounded top corners that joins
/// the content below.
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
      child: CustomPaint(
        painter: const _HeaderBackgroundPainter(),
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
                    _FavoritesButton(onPressed: onFavorites),
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
    );
  }
}

class _FavoritesButton extends StatelessWidget {
  const _FavoritesButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: ZokyStrings.favoriteStores,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: ZokyHomeHeader.tapTarget,
            child: Center(
              child: Ink(
                width: ZokyHomeHeader.heartDiameter,
                height: ZokyHomeHeader.heartDiameter,
                decoration: const BoxDecoration(
                  color: ZokyColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x2E991636), // wine 18%
                      offset: Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  ZokyIcons.favorite,
                  size: ZokySizes.iconLg,
                  color: ZokyColors.brand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo "bg" gradient plus two soft, lighter pink waves (decorative only).
class _HeaderBackgroundPainter extends CustomPainter {
  const _HeaderBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            ZokyColors.headerTop,
            ZokyColors.headerMid,
            ZokyColors.headerBottom,
          ],
          stops: [0, 0.35, 1],
        ).createShader(rect),
    );

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
  bool shouldRepaint(_HeaderBackgroundPainter oldDelegate) => false;
}
