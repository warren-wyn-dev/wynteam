// CANONICAL SOURCE: app/lib/core/design/wyn_typography.dart — DO NOT EDIT THE MIRROR IN seller_app/ DIRECTLY.
//
// WYN Design System — typography scale.
//
// Every size/weight/height/letterSpacing value below is copied verbatim
// from `.wyn/docs/design/ds-001-color-system.md`, Section 5 (Typography
// Scale). Uses the platform system font (San Francisco on iOS / Roboto on
// Android) -- no `fontFamily` override and no new font dependency (see
// Section 5's rationale: `google_fonts` is not in `app/pubspec.yaml`, and
// adding a font family is a separate, layout-wide task).
//
// `height` here is the line-height multiplier (line-height px / font-size
// px), exactly as given in the Section 5 table (e.g. `bodyLarge`'s
// "1.50 (24)" for a 16px font means `height: 1.50`).
import 'package:flutter/material.dart';

/// WYN Design System text styles (`TextTheme`).
class WynTypography {
  WynTypography._();

  static const TextTheme textTheme = TextTheme(
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
}
