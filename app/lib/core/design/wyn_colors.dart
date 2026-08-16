// CANONICAL SOURCE: app/lib/core/design/wyn_colors.dart — DO NOT EDIT THE MIRROR IN seller_app/ DIRECTLY.
//
// WYN Design System — color tokens.
//
// Every value below is copied verbatim (no rounding, no adjustment) from
// `.wyn/docs/design/ds-001-color-system.md`:
//   - Section 2 (Color Scale): raw token values (cyan/orange/neutral/semantic)
//   - Section 3.1/3.2 (Flutter ColorScheme Mapping): `ColorScheme` slots for
//     the WYN Social app, light and dark
//
// Founder approved "Option B" on 2026-08-15 (see .wyn/company/DECISIONS.md,
// "เปลี่ยน Color Direction ของ WYN: Blue → Cyan"): use the raw Cyan
// `#00C8FF` / Orange `#FF6B35` values directly in both light and dark mode,
// not adjusted shades. Some raw-on-white combinations fall below WCAG AA
// (documented in the source doc) -- this is an accepted, informed risk, not
// an oversight. Do not "fix" it by changing values here.
//
// The ZOKY sub-theme (Section 3.4, `tertiary` = Orange for `seller_app/`)
// is out of scope for this file -- see DS-001b.
import 'package:flutter/material.dart';

/// Raw WYN design-system color tokens, plus the assembled `ColorScheme`s
/// for the WYN Social app (light/dark).
///
/// Prefer `Theme.of(context).colorScheme` in screens/widgets. The named
/// token constants below exist so the `ColorScheme`s can be built without
/// repeating hex literals, and so this file stays a single source of truth
/// for every color in the system.
class WynColors {
  WynColors._();

  // ---------------------------------------------------------------------
  // 2.1 WYN Cyan (primary brand color)
  // ---------------------------------------------------------------------
  static const Color cyan50 = Color(0xFFE6F9FF);
  static const Color cyan100 = Color(0xFFCCF2FF);
  static const Color cyan300 = Color(0xFF66DDFF);
  static const Color cyan500 = Color(0xFF00C8FF);
  static const Color cyan600 = Color(0xFF00A3D9);
  static const Color cyan700 = Color(0xFF0090C4);
  static const Color cyan800 = Color(0xFF00739E);
  static const Color cyan900 = Color(0xFF00658A);
  static const Color cyan950 = Color(0xFF003D54);

  // ---------------------------------------------------------------------
  // 2.2 ZOKY Orange (commerce layer accent)
  // ---------------------------------------------------------------------
  static const Color orange50 = Color(0xFFFFF1EC);
  static const Color orange500 = Color(0xFFFF6B35);
  static const Color orange600 = Color(0xFFE85A24);
  static const Color orange700 = Color(0xFFCC4A16);
  static const Color orange800 = Color(0xFFA63A10);

  // ---------------------------------------------------------------------
  // 2.3 Neutral (core scaffolding of the whole system)
  // ---------------------------------------------------------------------
  static const Color ink = Color(0xFF0A0A0A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color gray500 = Color(0xFF6B7280);
  static const Color gray400 = Color(0xFF9CA3AF);
  static const Color borderSubtleLight = Color(0xFFE5E7EB);
  static const Color borderStrongLight = Color(0xFF8B929C);
  static const Color surfaceMutedLight = Color(0xFFF7F8FA);
  static const Color bgDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF111111);
  static const Color surfaceMutedDark = Color(0xFF1A1A1A);
  static const Color borderSubtleDark = Color(0xFF222222);
  static const Color borderStrongDark = Color(0xFF666666);

  // ---------------------------------------------------------------------
  // 2.4 Semantic (status colors -- not brand colors, not reinvented)
  // ---------------------------------------------------------------------
  static const Color successLight = Color(0xFF15803D);
  static const Color successDark = Color(0xFF4ADE80);
  static const Color errorLight = Color(0xFFDC2626);
  static const Color errorDark = Color(0xFFF87171);
  static const Color warningLight = Color(0xFFB45309);
  static const Color warningDark = Color(0xFFFBBF24);
  static const Color likeLight = Color(0xFFE11D48);
  static const Color likeDark = Color(0xFFFB7185);

  // ---------------------------------------------------------------------
  // Technical/overlay tokens -- NOT brand colors. Not part of DS-001's
  // Section 2.3/2.4 scale (that section is scoped to brand/neutral/status
  // colors, not technical image overlays). Discovered during DS-001c
  // implementation: a handful of grid tiles/clip views draw a
  // semi-transparent black scrim behind white text/badges so they stay
  // readable on top of arbitrary user-uploaded photos/video frames --
  // this has nothing to do with light/dark theme or brand identity (the
  // scrim is always black, on both themes, because it sits directly on a
  // photo/video, not on a themed surface). Named here instead of staying
  // as inline `Color(0x...)` literals so DS-001's own "no hardcoded
  // Color(0x...) outside this file" rule holds without inventing a
  // brand-color meaning that doesn't exist for these values.
  // ---------------------------------------------------------------------
  static const Color imageScrim = Color(0x99000000);
  static const Color imageScrimStrong = Color(0xCC000000);

  // ---------------------------------------------------------------------
  // 3.1 WYN Social — Light `ColorScheme`
  // ---------------------------------------------------------------------
  static const ColorScheme socialLightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: cyan500,
    onPrimary: ink,
    primaryContainer: cyan50,
    onPrimaryContainer: ink,
    secondary: cyan500,
    onSecondary: ink,
    // secondaryContainer: neutral tonal container (not a named 2.x token).
    secondaryContainer: Color(0xFFF2F4F7),
    onSecondaryContainer: ink,
    // tertiary is used as a bare-text link color on light -- 1.96:1, below
    // AA. Accepted risk per Founder decision (DS-001, Section 3.0/3.1).
    tertiary: cyan500,
    onTertiary: ink,
    error: errorLight,
    onError: white,
    // errorContainer/onErrorContainer: not named 2.x tokens.
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: white,
    onSurface: ink,
    onSurfaceVariant: gray500,
    surfaceContainerLowest: white,
    // surfaceContainerLow: not a named 2.x token.
    surfaceContainerLow: Color(0xFFFAFBFC),
    surfaceContainer: surfaceMutedLight,
    surfaceContainerHigh: Color(0xFFF2F4F7),
    // surfaceContainerHighest: not a named 2.x token.
    surfaceContainerHighest: Color(0xFFEDEFF3),
    outlineVariant: borderSubtleLight,
    outline: borderStrongLight,
    inverseSurface: ink,
    onInverseSurface: white,
    inversePrimary: cyan500,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // ---------------------------------------------------------------------
  // 3.2 WYN Social — Dark `ColorScheme`
  // ---------------------------------------------------------------------
  static const ColorScheme socialDarkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: cyan500,
    onPrimary: ink,
    primaryContainer: cyan950,
    onPrimaryContainer: cyan100,
    secondary: cyan500,
    onSecondary: ink,
    secondaryContainer: surfaceMutedDark,
    onSecondaryContainer: white,
    // tertiary on dark reads fine as bare text (10.09:1) -- no risk here.
    tertiary: cyan500,
    onTertiary: ink,
    error: errorDark,
    onError: ink,
    surface: bgDark,
    onSurface: white,
    onSurfaceVariant: gray400,
    surfaceContainerLowest: bgDark,
    // surfaceContainerLow: not a named 2.x token (same value as `ink`, but
    // documented in Section 3.2 as its own ColorScheme slot).
    surfaceContainerLow: Color(0xFF0A0A0A),
    surfaceContainer: surfaceDark,
    surfaceContainerHigh: surfaceMutedDark,
    surfaceContainerHighest: borderSubtleDark,
    outlineVariant: borderSubtleDark,
    outline: borderStrongDark,
    inverseSurface: white,
    onInverseSurface: ink,
    inversePrimary: cyan500,
  );
}
