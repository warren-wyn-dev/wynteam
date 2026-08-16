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
import 'package:flutter/material.dart';

import 'wyn_colors.dart';
import 'wyn_typography.dart';

/// WYN Social app theme.
class WynTheme {
  WynTheme._();

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: WynColors.socialLightScheme,
    textTheme: WynTypography.textTheme,
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: WynColors.socialDarkScheme,
    textTheme: WynTypography.textTheme,
  );
}
