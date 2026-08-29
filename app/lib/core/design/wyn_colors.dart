// CANONICAL SOURCE: app/lib/core/design/wyn_colors.dart — DO NOT EDIT THE MIRROR IN seller_app/ DIRECTLY.
//
// WYN Design System — color tokens.
//
// Founder approved switching the WYN Social app's brand color from Cyan to
// Sapphire on 2026-08-29 (see .wyn/company/DECISIONS.md, "เปลี่ยน Color
// Direction ของ WYN: Cyan → Sapphire (design-reference re-brand)"), which
// supersedes the 2026-08-15 "Blue → Cyan" decision for `app/` (this file's
// scope) only -- `seller_app/`'s ZOKY Orange accent is untouched, and this
// file's own `orange*`/ZOKY tokens stay as before since the WYN Social
// app's own ZOKY sub-theme (wyn_zoky_accent.dart) still needs them.
//
// Every neutral/accent value below is copied verbatim from
// `/design-reference/SPEC.md`, Section 1 (Design Tokens). `sapphire` is
// the single accent color for the whole app -- do not add another brand
// hue here without going back to the Founder first, per that doc's
// Section 0 ("Do not introduce any color not listed in Section 1").
//
// The ZOKY sub-theme (Section 3.4, `tertiary` = Orange for `seller_app/`,
// and for the ZOKY-branded screens inside `app/` itself) is out of scope
// for this re-brand -- see DS-001b and the design-reference README's "out
// of scope" note on commerce/shop screens.
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
  // design-reference SPEC.md, Section 1 — WYNOS neutral/accent palette
  // ---------------------------------------------------------------------

  /// Primary text, icons at full strength, banner background, active nav.
  static const Color ink = Color(0xFF12120F);

  /// Page background, card background, text-on-dark.
  static const Color paper = Color(0xFFFAF9F6);

  /// Outer device bezel background only in the reference mockups -- not
  /// part of the app UI itself. Kept here only for completeness/parity
  /// with SPEC.md Section 1; nothing in the real app should reference it.
  static const Color canvas = Color(0xFFEDEBE5);

  /// Secondary text, inactive icons, metadata.
  static const Color graphite = Color(0xFF8A8880);

  /// Tertiary text (view counts, disabled states, footer text).
  static const Color faint = Color(0xFFC7C4BC);

  /// All dividers, all 1px borders.
  static const Color hairline = Color(0xFFE8E6E0);

  /// The one accent color -- avatar ring, active tab underline, hashtags,
  /// verified badge fill, primary buttons, liked-heart fill.
  static const Color sapphire = Color(0xFF1B3A6B);

  /// Sapphire at 20% opacity -- used for exactly one thing, the 1px avatar
  /// ring border (SPEC.md Section 1: "Nothing else gets an alpha value").
  static const Color sapphireRing = Color(0x331B3A6B);

  /// Literal, faint-adjacent neutral used consistently across multiple
  /// reference screens (02-notifications.tsx's GroupLabel/inactive tab,
  /// 03-search.tsx's SectionLabel) for small uppercase eyebrow labels --
  /// not one of SPEC.md's named Section 1 tokens, but appears identically
  /// (`#B7B4AC`) in more than one reference file, so it's a real system
  /// token, not a one-off typo -- promoted here rather than duplicated as
  /// a local literal per file.
  static const Color mutedNeutral = Color(0xFFB7B4AC);

  // ---------------------------------------------------------------------
  // Notification type-badge colors (02-notifications.tsx) -- Founder-
  // approved exception to "sapphire is the only accent" (2026-08-29),
  // scoped explicitly to the small 18px type-icon badge on a notification
  // row (heart/comment/repost/follow), never a text/large-surface color.
  // ---------------------------------------------------------------------
  static const Color notificationBadgeComment = Color(0xFF3A5A40);
  static const Color notificationBadgeRepost = Color(0xFF8A6D3A);

  // ---------------------------------------------------------------------
  // ZOKY Orange (commerce layer accent) -- unaffected by the Sapphire
  // re-brand above, see file-level doc comment.
  // ---------------------------------------------------------------------
  static const Color orange50 = Color(0xFFFFF1EC);
  static const Color orange500 = Color(0xFFFF6B35);
  static const Color orange600 = Color(0xFFE85A24);
  static const Color orange700 = Color(0xFFCC4A16);
  static const Color orange800 = Color(0xFFA63A10);

  // ---------------------------------------------------------------------
  // Neutral technical/dark-mode scaffolding not covered by SPEC.md (which
  // only specifies a light palette) -- kept from the pre-rebrand system so
  // `dark` ColorScheme below still compiles to something coherent even
  // though WynApp forces `ThemeMode.light` (WYN-071) and this is unused
  // in production today.
  // ---------------------------------------------------------------------
  static const Color white = Color(0xFFFFFFFF);
  static const Color borderStrongLight = Color(0xFF8B929C);
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
  // DS-009 Rainbow accent -- copied verbatim from .wyn/docs/design/
  // ds-009-rainbow-accent.md (Founder-approved "Option B", 2026-08-22).
  // NOT a primary/brand color slot and NOT part of DS-001's Section 2/3
  // scale -- decorative only, used in exactly 2 places (Trending tile
  // ring, active Home feed-mode segment). Never a text/icon color on its
  // own: a 5-stop gradient has no single WCAG contrast value, so this is
  // restricted to surfaces that never carry text directly. Same value in
  // both light and dark mode -- do not theme-split this.
  // ---------------------------------------------------------------------
  static const LinearGradient rainbowAccent = LinearGradient(
    colors: [
      Color(0xFFFF6B6B), // coral
      Color(0xFFFFB347), // amber
      Color(0xFF4ECDC4), // mint
      Color(0xFF4A9DE0), // sky
      Color(0xFF9B6BFF), // violet
    ],
  );

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
  //
  // Deliberately flat: SPEC.md Section 1 defines exactly 7 flat tokens, no
  // tonal elevation scale, and Section 1's own rule ("nothing else gets an
  // alpha value; do not invent new tints") forbids synthesizing new
  // sapphire/neutral shades for Material's container slots. Every
  // "container" slot below is one of the 7 named tokens verbatim, reused,
  // never a newly-computed tint -- see .wyn/company/DECISIONS.md,
  // 2026-08-29.
  // ---------------------------------------------------------------------
  static const ColorScheme socialLightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: sapphire,
    onPrimary: paper,
    primaryContainer: paper,
    onPrimaryContainer: ink,
    secondary: sapphire,
    onSecondary: paper,
    secondaryContainer: paper,
    onSecondaryContainer: ink,
    tertiary: sapphire,
    onTertiary: paper,
    error: errorLight,
    onError: white,
    // errorContainer/onErrorContainer: semantic, not part of SPEC.md's
    // brand palette -- unchanged from the pre-rebrand system.
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: paper,
    onSurface: ink,
    onSurfaceVariant: graphite,
    surfaceContainerLowest: paper,
    surfaceContainerLow: paper,
    surfaceContainer: paper,
    surfaceContainerHigh: paper,
    surfaceContainerHighest: paper,
    outlineVariant: hairline,
    outline: borderStrongLight,
    inverseSurface: ink,
    onInverseSurface: paper,
    inversePrimary: sapphire,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  // ---------------------------------------------------------------------
  // 3.2 WYN Social — Dark `ColorScheme`
  //
  // SPEC.md does not define a dark palette (WYNOS ships light-only per
  // WYN-071/DECISIONS.md 2026-08-24 -- `WynApp` forces `ThemeMode.light`),
  // so this stays functionally coherent but unexercised in production;
  // kept, not deleted, so a future dark-mode decision can revisit it.
  // ---------------------------------------------------------------------
  static const ColorScheme socialDarkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: sapphire,
    onPrimary: paper,
    primaryContainer: bgDark,
    onPrimaryContainer: paper,
    secondary: sapphire,
    onSecondary: paper,
    secondaryContainer: surfaceMutedDark,
    onSecondaryContainer: white,
    tertiary: sapphire,
    onTertiary: paper,
    error: errorDark,
    onError: ink,
    surface: bgDark,
    onSurface: white,
    onSurfaceVariant: graphite,
    surfaceContainerLowest: bgDark,
    surfaceContainerLow: Color(0xFF0A0A0A),
    surfaceContainer: surfaceDark,
    surfaceContainerHigh: surfaceMutedDark,
    surfaceContainerHighest: borderSubtleDark,
    outlineVariant: borderSubtleDark,
    outline: borderStrongDark,
    inverseSurface: white,
    onInverseSurface: ink,
    inversePrimary: sapphire,
  );
}
