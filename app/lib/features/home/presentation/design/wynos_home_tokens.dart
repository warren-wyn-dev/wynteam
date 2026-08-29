// WYNOS Home feed — design tokens, scoped to this feature only.
//
// Source of truth: WYNOSHomeSpec.md + wynos-home-full.tsx (the reference
// implementation the Founder supplied for the Home feed redesign). Every
// value below is copied verbatim from that spec, not estimated.
//
// Deliberately NOT merged into the app-wide `core/design/` tokens
// (WynColors/WynTypography/WynSpacing): those implement DS-001, the
// Founder-approved global color/type system (Cyan/Orange, system font)
// used by every other screen (Profile, Chat, Club, Search, ...). This
// reference introduces an unrelated palette (ink/paper/sapphire) and
// typeface (Fraunces/Inter) that only the Home feed has been asked to
// adopt -- keeping it in its own file means the rest of the app is
// untouched and DS-001 stays intact everywhere else.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Section 1 — color tokens.
class WynosHomeColors {
  WynosHomeColors._();

  /// Primary text, icons at full strength, banner background, active nav.
  static const Color ink = Color(0xFF12120F);

  /// Page background, card background, text-on-dark.
  static const Color paper = Color(0xFFFAF9F6);

  /// Secondary text, inactive icons, metadata.
  static const Color graphite = Color(0xFF8A8880);

  /// Tertiary text (view counts, disabled states, footer text).
  static const Color faint = Color(0xFFC7C4BC);

  /// All dividers, all 1px borders.
  static const Color hairline = Color(0xFFE8E6E0);

  /// The one accent color: avatar ring, active tab underline, hashtags,
  /// verified badge fill, primary buttons (follow, new-posts pill),
  /// liked-heart fill.
  static const Color sapphire = Color(0xFF1B3A6B);

  /// Avatar ring only -- sapphire at 20% opacity. The spec calls out that
  /// this is the *only* place sapphire gets an alpha value; don't invent
  /// new tints elsewhere.
  static const Color sapphireRing = Color(0x331B3A6B);

  /// Reply-preview body text -- deliberately between graphite and ink
  /// (quieter than the post author's name, still legible body text).
  static const Color replyText = Color(0xFF5A5850);

  /// Banner subtext -- the reference's own `#B7B4AC` is used verbatim
  /// there for text-on-ink secondary copy (distinct from `graphite`,
  /// which is for text-on-paper).
  static const Color onInkSecondary = Color(0xFFB7B4AC);
}

/// Section 2 — typography. Two font families only: Fraunces (display,
/// wordmark + empty-state headline -- nowhere else) and Inter (every
/// other piece of UI text).
class WynosHomeText {
  WynosHomeText._();

  static TextStyle _sans({
    required double size,
    required FontWeight weight,
    Color color = WynosHomeColors.ink,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle _serif({
    required double size,
    required FontWeight weight,
    Color color = WynosHomeColors.ink,
    double? letterSpacing,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// "WYNOS" wordmark in the header. 19px, Fraunces 500, letter-spacing
  /// 0.06em, ink.
  static TextStyle wordmark = _serif(
    size: 19,
    weight: FontWeight.w500,
    letterSpacing: 19 * 0.06,
  );

  /// Empty-state headline. 20px, Fraunces 500, ink.
  static TextStyle emptyHeadline = _serif(size: 20, weight: FontWeight.w500);

  /// Empty-state / banner subtext. 13px/12px regular, graphite -- callers
  /// pass the size that applies (empty-state subtext is 13px, banner
  /// line 2 is 12px on ink so uses [WynosHomeColors.onInkSecondary]).
  static TextStyle emptyStateSubtext =
      _sans(size: 13, weight: FontWeight.w400, color: WynosHomeColors.graphite);

  static TextStyle bannerHeadline =
      _sans(size: 13, weight: FontWeight.w600, color: WynosHomeColors.paper);

  static TextStyle bannerBody = _sans(
    size: 12,
    weight: FontWeight.w400,
    color: WynosHomeColors.onInkSecondary,
  );

  /// Post author name. 14.5px, Inter 600, ink.
  static TextStyle postAuthorName =
      _sans(size: 14.5, weight: FontWeight.w600);

  /// Post body text. 14.5px, Inter 400, leading-relaxed.
  static TextStyle postBody =
      _sans(size: 14.5, weight: FontWeight.w400, height: 1.6);

  /// Suggested-follow name. 14px, Inter 600, ink.
  static TextStyle suggestedFollowName =
      _sans(size: 14, weight: FontWeight.w600);

  static TextStyle suggestedFollowHandle =
      _sans(size: 12, weight: FontWeight.w400, color: WynosHomeColors.onInkSecondary);

  /// Filter tab label -- caller passes [active] to pick weight/color.
  static TextStyle filterTab({required bool active}) => _sans(
        size: 13.5,
        weight: active ? FontWeight.w600 : FontWeight.w400,
        color: active ? WynosHomeColors.ink : WynosHomeColors.faint,
      );

  /// Hashtags -- rendered as plain inline text, not a chip.
  static TextStyle hashtag =
      _sans(size: 13.5, weight: FontWeight.w500, color: WynosHomeColors.sapphire);

  static TextStyle menuItem = _sans(size: 13, weight: FontWeight.w400);

  static TextStyle newPostsPill =
      _sans(size: 12.5, weight: FontWeight.w600, color: WynosHomeColors.paper);

  static TextStyle replyPreviewName = _sans(size: 12.5, weight: FontWeight.w600);

  static TextStyle replyPreviewText =
      _sans(size: 12.5, weight: FontWeight.w400, color: WynosHomeColors.replyText);

  static TextStyle followButton =
      _sans(size: 12.5, weight: FontWeight.w600, color: WynosHomeColors.sapphire);

  static TextStyle timestamp =
      _sans(size: 12, weight: FontWeight.w400, color: WynosHomeColors.onInkSecondary);

  static TextStyle likedByText =
      _sans(size: 12, weight: FontWeight.w400, color: WynosHomeColors.graphite);

  static TextStyle likedByName =
      _sans(size: 12, weight: FontWeight.w600, color: WynosHomeColors.ink);

  static TextStyle redropAttribution =
      _sans(size: 11.5, weight: FontWeight.w400, color: WynosHomeColors.onInkSecondary);

  static TextStyle actionCount =
      _sans(size: 12, weight: FontWeight.w400, color: WynosHomeColors.graphite);
}

/// Section 3 — spacing & layout constants used across the Home feed's
/// components. Named per their role in the spec, not just raw numbers,
/// so call sites read like the spec section they implement.
class WynosHomeSpacing {
  WynosHomeSpacing._();

  /// Horizontal page padding shared by every top-level section (header,
  /// banner, tabs, posts, empty state).
  static const double pagePadding = 24;

  /// Post vertical padding (pt-4 pb-4).
  static const double postVertical = 16;

  /// Gap between avatar and post content column (gap-3.5).
  static const double avatarContentGap = 14;

  /// Gap between action-bar icon groups (gap-5).
  static const double actionBarGap = 20;

  /// Gap between an action-bar icon and its own count label (gap-1.5).
  static const double actionIconLabelGap = 6;

  /// Avatar ring: outer diameter = inner diameter + this.
  static const double avatarRingExtra = 6;

  /// Gap between suggested-follow rows in the empty state (space-y-4).
  static const double suggestedRowGap = 16;

  /// Gap between lines of a post body (space-y-2).
  static const double postLineGap = 8;
}
