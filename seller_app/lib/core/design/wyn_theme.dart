// CANONICAL SOURCE: app/lib/core/design/wyn_theme.dart — DO NOT EDIT THE MIRROR IN seller_app/ DIRECTLY.
//
// WYN Design System — assembled `ThemeData`.
//
// Combines `wyn_colors.dart` (`ColorScheme`) and `wyn_typography.dart`
// (`TextTheme`) into the `ThemeData` used by the WYN Social app
// (`app/lib/main.dart`). Deliberately does NOT use `colorSchemeSeed` --
// Section 3 of `.wyn/docs/design/ds-001-color-system.md` requires exact
// brand colors (Cyan `#00C8FF` primary, etc.), not Material-generated
// tones, which is what produced the "Material default" look the doc
// flags as the root cause to fix.
//
// The ZOKY sub-theme (`.wyn/docs/design/ds-001-color-system.md`,
// Section 3.4) is out of scope here -- that is DS-001b.
//
// `cardTheme` (added DS-002 Part 2, R3): every `Card()` in both apps used
// Material 3's default (elevation 1, tonal shadow) with no per-site
// override anywhere (verified via grep before adding this), so a single
// central override here is enough to flatten every card system-wide --
// `elevation: 0` + a hairline `WynColors.borderStrongLight`/`Dark` border
// (the same token the `ColorScheme.outline` slot already uses, so this
// isn't a new color, just reused) instead of a drop shadow, per DS-001's
// "Minimal Social Platform" direction (Threads-style flatness -- see
// .wyn/company/DECISIONS.md, 2026-08-15). `borderStrong` (not
// `borderSubtle`) is used deliberately: several Card sites are tappable
// (onTap wraps the whole card), so the boundary needs the same
// WCAG-1.4.11-safe 3:1 contrast as any other interactive outline, not
// the weaker decorative-divider value.
import 'package:flutter/material.dart';

import 'wyn_colors.dart';
import 'wyn_spacing.dart';
import 'wyn_typography.dart';

/// WYN Social app theme.
class WynTheme {
  WynTheme._();

  static final CardThemeData _lightCardTheme = CardThemeData(
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      side: const BorderSide(color: WynColors.borderStrongLight),
    ),
  );

  static final CardThemeData _darkCardTheme = CardThemeData(
    elevation: 0,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(WynSpacing.radiusMd),
      side: const BorderSide(color: WynColors.borderStrongDark),
    ),
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: WynColors.socialLightScheme,
    textTheme: WynTypography.textTheme,
    cardTheme: _lightCardTheme,
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: WynColors.socialDarkScheme,
    textTheme: WynTypography.textTheme,
    cardTheme: _darkCardTheme,
  );
}
