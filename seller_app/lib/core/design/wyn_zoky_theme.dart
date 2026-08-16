// seller_app-only file -- NOT a mirror of app/lib/core/design/. This is the
// ZOKY sub-theme described in
// .wyn/docs/design/ds-001-color-system.md, Section 3.4 ("ZOKY sub-theme").
//
// Built on top of the mirrored `WynColors`/`WynTypography` tokens
// (`wyn_colors.dart`, `wyn_typography.dart`) -- do not duplicate any raw hex
// values here that already exist as a named token in `wyn_colors.dart`.
//
// Per Section 3.4, the ZOKY `ColorScheme` is identical to the WYN Social
// `ColorScheme` (`WynColors.socialLightScheme`/`socialDarkScheme`) in every
// slot except `tertiary`/`onTertiary`/`tertiaryContainer`/
// `onTertiaryContainer`, which switch from Cyan to raw Orange
// (`#FF6B35`, Option B -- no shade adjustment, same Founder decision as the
// WYN Social scheme, see .wyn/company/DECISIONS.md 2026-08-15).
//
// Per DS-001 Section 4 ("`seller_app/` (ZOKY Sellers by WYN)"), this app is
// the commerce layer end-to-end, so it uses this ZOKY sub-theme as its ONLY
// theme -- `seller_app/lib/main.dart` must reference `ZokyTheme.light` /
// `ZokyTheme.dark`, never `WynTheme.light` / `WynTheme.dark`. `primary`
// stays Cyan (per Section 3.4, "primary/surface/outline/typography เหมือน
// WYN ทุกประการ") -- screens in this app must read `colorScheme.tertiary`
// (Orange) for ZOKY-branded accents, not `colorScheme.primary`, so that
// Cyan never actually renders as a visible accent color anywhere in this
// app (Section 4: "Cyan ห้ามปรากฏใน seller_app เลย").
import 'package:flutter/material.dart';

import 'wyn_colors.dart';
import 'wyn_typography.dart';

/// ZOKY Sellers by WYN app theme -- WYN Social's `ColorScheme` with the
/// `tertiary` family swapped from Cyan to Orange (DS-001, Section 3.4).
class ZokyTheme {
  ZokyTheme._();

  static final ColorScheme _lightScheme = WynColors.socialLightScheme
      .copyWith(
        tertiary: WynColors.orange500,
        onTertiary: WynColors.ink,
        tertiaryContainer: WynColors.orange50,
        onTertiaryContainer: WynColors.ink,
      );

  static final ColorScheme _darkScheme = WynColors.socialDarkScheme.copyWith(
    tertiary: WynColors.orange500,
    onTertiary: WynColors.ink,
    // Not a named 2.x token in wyn_colors.dart -- copied verbatim from
    // DS-001 Section 3.4's ZOKY dark tertiaryContainer value.
    tertiaryContainer: const Color(0xFF3A1608),
    onTertiaryContainer: const Color(0xFFFFD9C9),
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    textTheme: WynTypography.textTheme,
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    colorScheme: _darkScheme,
    textTheme: WynTypography.textTheme,
  );
}
