// CANONICAL SOURCE: app/lib/core/design/wyn_typography.dart — DO NOT EDIT THE MIRROR IN seller_app/ DIRECTLY.
//
// WYN Design System — typography scale.
//
// Every size/weight/height/letterSpacing value in [textTheme] below is
// copied verbatim from `.wyn/docs/design/ds-001-color-system.md`, Section 5
// (Typography Scale) -- that numeric scale (which named role gets which
// size/weight) is unchanged by the 2026-08-29 Sapphire re-brand, only the
// font family is: `/design-reference/SPEC.md`, Section 2 mandates exactly
// two font families app-wide -- Fraunces (serif, display -- the "WYNOS"
// wordmark and screen-title-style headlines only) and Inter (sans, every
// other piece of UI text) -- so [textTheme] is Inter-ized via
// `GoogleFonts.interTextTheme` (keeps every existing size/weight/height,
// just swaps the rendered font), and [fraunces] is a separate style
// factory for the Fraunces-only spots. See .wyn/company/DECISIONS.md,
// 2026-08-29.
//
// `height` here is the line-height multiplier (line-height px / font-size
// px), exactly as given in the Section 5 table (e.g. `bodyLarge`'s
// "1.50 (24)" for a 16px font means `height: 1.50`).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// WYN Design System text styles (`TextTheme`).
class WynTypography {
  WynTypography._();

  static const TextTheme _rawTextTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.4,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.29,
      letterSpacing: -0.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.30,
      letterSpacing: -0.2,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      height: 1.33,
      letterSpacing: -0.1,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.38,
      letterSpacing: 0,
    ),
    // Author name on feed cards (already matches home_drop_card.dart usage
    // per Section 5's note).
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.43,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.50,
      letterSpacing: 0,
    ),
    // App-wide default body style.
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.50,
      letterSpacing: 0,
    ),
    bodySmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.43,
      letterSpacing: 0,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.33,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.23,
      letterSpacing: 0.1,
    ),
    // Metadata only (timestamps, counters) -- never body content the user
    // must read (Section 5's rule).
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.33,
      letterSpacing: 0.2,
    ),
  );

  /// The `TextTheme` every screen actually uses (via `WynTheme` ->
  /// `Theme.of(context).textTheme`) -- [_rawTextTheme]'s sizes/weights,
  /// rendered in Inter. `GoogleFonts.interTextTheme` merges Inter's
  /// `fontFamily`/`fontFamilyFallback` onto each role without touching any
  /// other property, so nothing in [_rawTextTheme] needs to be repeated.
  static final TextTheme textTheme = GoogleFonts.interTextTheme(_rawTextTheme);

  /// Fraunces, for the two spots SPEC.md Section 2 allows it: the "WYNOS"
  /// wordmark and a screen's Fraunces-styled title/headline text. Never
  /// use this for body/UI text -- see the file-level doc comment.
  static TextStyle fraunces({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w500,
    double? letterSpacing,
    Color? color,
  }) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );
}
