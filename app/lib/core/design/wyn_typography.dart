// WYN Design System — typography scale.
//
// Native iOS/Android deliberately set no `fontFamily`, so Flutter inherits
// each platform's system typography. Flutter Web cannot reliably use arbitrary
// installed device fonts from its canvas renderer, so WynTheme applies the
// self-hosted `WYNWebNotoThai` family only when `kIsWeb` is true. The bundled
// file is Noto Sans Thai under SIL OFL 1.1 and includes Thai + Latin coverage;
// no Google Fonts CSS/CDN or Apple font file is embedded.
//
// Scale below is the 2026-08-30 typography-system pass (Page Title 24,
// Section Title 20, Username 15, Post Body 16, Comment 15, Button 15,
// Input/Placeholder 16, Metadata/Counts 13, Bottom Nav 13) mapped onto
// the existing 12-role `TextTheme` so every `Theme.of(context).textTheme`
// call site keeps working unchanged. Roles Flutter's own Material 3
// widgets pull implicitly (not just this app's explicit
// `textTheme.xxx` call sites) are noted since they widen a role's real
// blast radius beyond its grep count:
// - `bodyLarge` -- Post Body; also M3's actual typed `TextField` text
//   AND its empty-field hint/placeholder text. Already exactly
//   16/400/1.5 before this pass; unchanged.
// - `titleMedium` -- M3's `TextField`/`InputDecorator` label (inline
//   and floating). Left unchanged (16/600) on purpose: bumping its
//   weight for the few explicit sheet-title call sites would have
//   bolded every form field's label app-wide.
// - `titleSmall` -- Username (48 call sites, all feed/author-name
//   contexts) -- 15/600/1.3 per spec, was 14/600/1.43.
// - `labelLarge` -- Button (M3's default `ElevatedButton`/`FilledButton`/
//   `TextButton` text style) -- 15/600/1.2 per spec, was 15/600/1.33.
// - `labelMedium` -- Bottom Navigation (M3 `NavigationBar`'s default
//   label style, both selected/unselected) -- 13/500, was 13/600.
// - `labelSmall` -- Metadata / like-comment-share counts -- 13/500, was
//   12/500 (12px violated this app's own "never below 12px for text a
//   user must read" rule with zero margin).
// - `bodyMedium`/`bodySmall` -- both were a duplicate 14px "secondary
//   reading text" role in practice (comment sheets, moderation reasons,
//   legal text, banners); consolidated onto Comment's 15/400/1.45.
//   `bodySmall` is also M3's implicit input helper/error/counter style.
//
// `height` here is the line-height multiplier (line-height px / font-size
// px), matching how the previous scale's doc comment described it.
import 'package:flutter/material.dart';

/// WYN Design System text styles (`TextTheme`).
class WynTypography {
  WynTypography._();

  // Important Number / Statistic (largest tier). Not yet referenced by
  // name anywhere in `app/` -- kept as the token for future big-number
  // displays rather than another ad-hoc literal.
  static const TextTheme textTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    ),
    // Page Title.
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    ),
    // Section Title.
    headlineSmall: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: 0,
    ),
    // Shop Price / other prominent inline totals.
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.2,
      letterSpacing: 0,
    ),
    // Input/floating label text (M3 `TextField`/`InputDecorator` default)
    // -- see file-level doc comment for why this is intentionally
    // unchanged from the pre-2026-08-29 scale.
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.38,
      letterSpacing: 0,
    ),
    // Username / author name on feed cards.
    titleSmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0,
    ),
    // Post Body. Also M3's actual `TextField` input text and empty-field
    // placeholder text -- see file-level doc comment.
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0,
    ),
    // Comment / secondary reading text (moderation reasons, legal text,
    // banners, sheet descriptions).
    bodyMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
      letterSpacing: 0,
    ),
    // Comment / secondary reading text -- same role as bodyMedium (see
    // file-level doc comment); also M3's implicit input helper/error/
    // counter text style.
    bodySmall: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.45,
      letterSpacing: 0,
    ),
    // Button (M3's default ElevatedButton/FilledButton/TextButton text
    // style) -- also used directly for a few subsection headers.
    labelLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0,
    ),
    // Bottom Navigation (M3 NavigationBar's default label style).
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.2,
      letterSpacing: 0,
    ),
    // Metadata (timestamps) / like-comment-share counts.
    labelSmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.3,
      letterSpacing: 0.1,
    ),
  );

  /// Screen/nav-header title text. Same call signature callers have used
  /// since the platform-font typography pass: system font on native and the
  /// WynTheme-selected self-hosted family on Web, with no per-style override.
  static TextStyle screenTitle({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w600,
    double? letterSpacing,
    Color? color,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );
}
