// WYNOS design-reference token set (2026-08-29 rollout, 23 `.tsx` screens
// dropped at the repo root, `/SPEC.md` Section 1-2). Introduced by WYN-072
// (Screen 01, Home Feed) and reused by WYN-073 (Screen 05, Profile --
// own-profile view only) and any later screen in the same rollout, since
// they all read from the exact same 7-token palette (ink/paper/canvas/
// graphite/faint/hairline/sapphire) and the same "Fraunces for display,
// Inter for everything else" font rule.
//
// Deliberately NOT folded into `WynColors`/`WynTheme` (app/lib/core/
// design/wyn_colors.dart, wyn_theme.dart): the reference's Sapphire accent
// replaces DS-001's Cyan direction, but only the screens that have reached
// their turn in the 23-screen rollout use it -- every other screen still
// needs the old Cyan-based `WynTheme` until it's migrated. This file is
// additive/opt-in, applied locally per-widget (never via
// `Theme.of(context)` globally), so screens not yet at their turn are
// completely unaffected.
//
// File/class name deliberately shared across WYN-072/WYN-073 (both tasks'
// own task files point at this exact path) rather than each task creating
// its own copy -- if you're reconciling a conflict here, merge into one
// superset (as this file already is), never fork two parallel token
// systems or rename either side "to fix a merge conflict".
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WynosHomeTokens {
  WynosHomeTokens._();

  // ---------------------------------------------------------------------
  // Section 1: color
  // ---------------------------------------------------------------------

  /// Primary text, icons at full strength, banner background, active nav.
  static const Color ink = Color(0xFF12120F);

  /// Page background, card background, text-on-dark.
  static const Color paper = Color(0xFFFAF9F6);

  /// Outer device bezel background only in the reference's own mockup
  /// frame -- not part of any real (non-framed) Flutter screen's own UI,
  /// kept here only for completeness/parity with SPEC.md's token table.
  static const Color canvas = Color(0xFFEDEBE5);

  /// Secondary text, inactive icons, metadata.
  static const Color graphite = Color(0xFF8A8880);

  /// Tertiary text -- view counts, disabled states, footer text.
  static const Color faint = Color(0xFFC7C4BC);

  /// All dividers, all 1px borders.
  static const Color hairline = Color(0xFFE8E6E0);

  /// The **one** accent color: avatar ring, active tab underline,
  /// hashtags, verified-badge fill, primary buttons (follow, new-posts
  /// pill), liked-heart fill.
  static const Color sapphire = Color(0xFF1B3A6B);

  /// Sapphire at 20% opacity (`#1B3A6B33`) -- SPEC.md Section 1's *only*
  /// permitted alpha variant, used exclusively for the avatar ring
  /// border. Do not invent any other tint of sapphire (or any other
  /// token) -- see SPEC.md Section 0's "Non-negotiables".
  static const Color sapphireRing = Color(0x331B3A6B);

  /// Post body text color (`#2B2A26`) -- SPEC.md's own `.jsx` reference
  /// uses this slightly-warmer-than-`ink` shade for post body copy
  /// specifically (Section 4.6 point 5), distinct from `ink` itself.
  static const Color postBodyInk = Color(0xFF2B2A26);

  /// Top-reply-preview text color (`#5A5850`) -- SPEC.md Section 4.10:
  /// "a slightly muted ink-adjacent tone ... deliberately not full
  /// `graphite` and not full `ink`". Not one of the 7 headline tokens in
  /// Section 1, but explicitly named and pinned to this exact value by
  /// Section 4.10's own prose, so it's declared here rather than inlined
  /// as a bare hex literal in a widget.
  static const Color replyPreviewInk = Color(0xFF5A5850);

  // ---------------------------------------------------------------------
  // Section 2: typography
  // ---------------------------------------------------------------------
  //
  // Two font families only, per SPEC.md Section 2: Fraunces (serif,
  // weight 500) for display text (the "WYNOS" wordmark, empty-state
  // headlines) only; Inter (sans-serif) for everything else. `app/
  // pubspec.yaml` adds `google_fonts` for this (WYN-072) -- neither font
  // ships as a system font on iOS/Android and neither was already
  // bundled as an asset, so this renders the real typefaces rather than
  // falling back to the platform default under an unregistered family
  // name.

  /// Bare family names, for any call site that needs the family only
  /// (rather than one of the named [TextStyle] helpers below) -- e.g.
  /// composing into a `DefaultTextStyle`/`TextTheme` override.
  static const String fontDisplay = 'Fraunces';
  static const String fontBody = 'Inter';

  /// 19px, Fraunces 500, letter-spacing 0.06em -- the "WYNOS" wordmark
  /// in the header (SPEC 4.1). Nowhere else.
  static TextStyle get wordmark => GoogleFonts.fraunces(
        fontSize: 19,
        fontWeight: FontWeight.w500,
        letterSpacing: 19 * 0.06,
        color: ink,
      );

  /// 20px, Fraunces 500 -- the empty-state headline (SPEC 4.5). Nowhere
  /// else.
  static TextStyle get emptyStateHeadline => GoogleFonts.fraunces(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: ink,
      );

  /// 14.5px, Inter 600 -- post author name.
  static TextStyle get postAuthorName => GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: ink,
      );

  /// 14.5px, Inter 400, relaxed line-height -- post body text.
  static TextStyle get postBody => GoogleFonts.inter(
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: postBodyInk,
      );

  /// 14px, Inter 600 -- suggested-to-follow name (empty state).
  static TextStyle get suggestedFollowName => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      );

  /// 13.5px, Inter 400/600 -- filter tab labels. [active] selects the
  /// active (weight 600, ink) vs. inactive (weight 400, faint) look per
  /// SPEC 4.3.
  static TextStyle filterTab({required bool active}) => GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
        color: active ? ink : faint,
      );

  /// 13.5px, Inter 500, sapphire -- hashtags (SPEC 4.6.6). Rendered as
  /// plain inline text, never a pill/chip.
  static TextStyle get hashtag => GoogleFonts.inter(
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        color: sapphire,
      );

  /// 13px, Inter 600, paper -- explainer banner headline (SPEC 4.2 line
  /// 1).
  static TextStyle get bannerHeadline => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: paper,
      );

  /// 13px, Inter 400 -- empty-state subtext, and (per SPEC 4.6.4) the
  /// "แชร์"/"บันทึก" more-options menu row labels. [color] defaults to
  /// `graphite` (the empty-state subtext usage); the menu rows pass
  /// `ink` explicitly since SPEC 4.6.4 doesn't name a color for them.
  static TextStyle bodySmall({Color color = graphite}) => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// 12.5px, Inter 600 -- new-posts pill text, reply-preview replier
  /// name, and (compact) the empty-state Follow button label. [color]
  /// defaults to `paper` (the pill's own white-on-sapphire text);
  /// callers on a light background pass `ink`/`sapphire` explicitly.
  static TextStyle label({Color color = paper}) => GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// 12.5px, Inter 400 -- the reply-preview's own comment text
  /// (`replyPreviewInk`, SPEC 4.10).
  static TextStyle get replyPreviewBody => GoogleFonts.inter(
        fontSize: 12.5,
        fontWeight: FontWeight.w400,
        color: replyPreviewInk,
      );

  /// 12px, Inter 400 -- timestamp, "liked by" text, handle text.
  /// [color] defaults to `graphite` (SPEC 4.6 point 3's explicit
  /// "timestamp (12px graphite)"); callers pass a different token only
  /// where SPEC's own prose says so.
  static TextStyle caption({Color color = graphite}) => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// 11.5px, Inter 400, graphite -- the "ReDrop โดย {handle}" attribution
  /// line (SPEC 4.6 point 1: "in 11.5px graphite").
  static TextStyle get redropAttribution => GoogleFonts.inter(
        fontSize: 11.5,
        fontWeight: FontWeight.w400,
        color: graphite,
      );
}
