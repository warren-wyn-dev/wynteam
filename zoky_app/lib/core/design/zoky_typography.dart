import 'package:flutter/material.dart';

import 'zoky_colors.dart';

/// ZOKY typography (design section 5, tokens.json `typography.scale`).
///
/// Anuphan is bundled as an unmodified *variable* font, so every weight is
/// also applied through the `wght` axis ([FontVariation.weight]); setting
/// only [TextStyle.fontWeight] is not guaranteed to move a variable font's
/// axis. Always change weight through [ZokyTextStyles.weight] instead of
/// `copyWith(fontWeight: ...)`.
abstract final class ZokyTextStyles {
  static const String fontFamily = 'Anuphan';

  /// Fallback for glyphs Anuphan lacks (design: Noto Sans Thai -> system).
  /// Noto Sans Thai is not bundled; the platform fallback is used.
  static const List<String> fontFamilyFallback = ['Noto Sans Thai'];

  static TextStyle _style(
    double size,
    FontWeight weight,
    double height, {
    double letterSpacing = 0,
    Color color = ZokyColors.textPrimary,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: size,
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
      height: height,
      // Thai stacks vowels/tone marks above and below: distribute leading
      // evenly so marks are never clipped (design 5.2).
      leadingDistribution: TextLeadingDistribution.even,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: features,
    );
  }

  /// Returns [style] with both fontWeight and the `wght` axis set.
  static TextStyle weight(TextStyle style, FontWeight weight) {
    return style.copyWith(
      fontWeight: weight,
      fontVariations: [FontVariation.weight(weight.value.toDouble())],
    );
  }

  static final TextStyle display = _style(
    28,
    FontWeight.w700,
    1.25,
    letterSpacing: -0.3,
  );
  static final TextStyle titleLg = _style(
    24,
    FontWeight.w700,
    1.25,
    letterSpacing: -0.3,
  );
  static final TextStyle titleMd = _style(
    22,
    FontWeight.w700,
    1.25,
    letterSpacing: -0.2,
  );
  static final TextStyle titleSm = _style(
    18,
    FontWeight.w700,
    1.3,
    letterSpacing: -0.2,
  );
  static final TextStyle bodyLg = _style(16, FontWeight.w400, 1.45);
  static final TextStyle bodyMd = _style(15, FontWeight.w400, 1.45);
  static final TextStyle bodySm = _style(
    13,
    FontWeight.w400,
    1.45,
    color: ZokyColors.textSecondary,
  );
  static final TextStyle labelLg = _style(16, FontWeight.w700, 1.25);
  static final TextStyle labelMd = _style(14, FontWeight.w600, 1.3);
  static final TextStyle labelSm = _style(12, FontWeight.w700, 1.25);

  /// Minimum size: bottom-nav labels and badges only.
  static final TextStyle caption = _style(11, FontWeight.w500, 1.2);

  static final TextStyle price = _style(
    16,
    FontWeight.w700,
    1.3,
    features: const [FontFeature.tabularFigures()],
  );
  static final TextStyle priceLg = _style(
    24,
    FontWeight.w700,
    1.2,
    letterSpacing: -0.3,
    features: const [FontFeature.tabularFigures()],
  );

  /// Material TextTheme mapping per design section 12.2.
  static TextTheme textTheme() {
    return TextTheme(
      displaySmall: display,
      headlineSmall: titleLg,
      titleLarge: titleMd,
      titleMedium: titleSm,
      titleSmall: weight(bodyLg, FontWeight.w600),
      bodyLarge: bodyLg,
      bodyMedium: bodyMd,
      bodySmall: bodySm,
      labelLarge: labelLg,
      labelMedium: labelMd,
      labelSmall: labelSm,
    );
  }
}
