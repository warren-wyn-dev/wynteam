/**
 * WYNOS Consumer Web v2 — typed design tokens (WYN-159).
 *
 * TS-side companion to `tokens.css`. Holds values that are needed in JS/TS
 * (sizing constants used as component props, breakpoints, the Tabler->Lucide
 * icon mapping) rather than pure CSS. Colors/radius stay in `tokens.css` as
 * CSS custom properties — do not duplicate hex values here.
 *
 * Source of truth: `.wyn/docs/design/wyn-159-web-v2-design-system.md`.
 */

/** 4px-based spacing scale (design-system doc, "Spacing Scale"). */
export const WYNOS_SPACING = {
  xs: 4,
  sm: 8,
  sm2: 10,
  md: 12,
  md2: 14,
  lg: 16,
  lg2: 18,
  xl: 24,
  xl2: 28,
  xxl: 32,
} as const;

/** Sizing tokens (design-system doc, "Sizing Tokens"). */
export const WYNOS_SIZES = {
  avatarFeed: 36,
  avatarProfile: 72,
  headerIconGlyph: 22,
  headerIconHitArea: 44,
  bottomNavIconGlyph: 21,
  bottomNavCtaGlyph: 24,
  bottomNavCta: 38,
  /**
   * Reference uses 18px webfont (`<i class="ti-*">`) glyphs. The already
   * shipped `post-actions.tsx` uses real `lucide-react` <svg> icons at
   * 24px — kept as-is (see app-shell/home doc, Post Card "Design Rules":
   * intentional deviation, not an oversight — shrinking a working icon to
   * match a demo font-icon's metrics would be a regression, not parity).
   */
  postActionIcon: 24,
  followPaddingY: 4,
  followPaddingX: 14,
  followFontSize: 12,
  headerHeight: 54,
  tabsHeight: 34,
  bottomNavHeight: 58,
} as const;

/**
 * Tabler Icons (reference `wynos-feed.html`) -> lucide-react mapping.
 * The reference uses `ti ti-*` webfont classes; production must not pull an
 * icon-font CDN, so every Tabler glyph maps to its closest already-installed
 * lucide-react equivalent, following the Founder's explicit **semantic**
 * mapping table from `wynos-home-v2.html` (2026-09-14) — matched by meaning,
 * not by copying inline SVG path data or guessing "closest to Tabler" shape.
 * That table is binding: an earlier revision of this file kept `MessageSquare`
 * for comment/chat to match the mobile Flutter app's icon shape, but the
 * Founder's explicit table calls for `MessageCircle` and `Repeat` (not
 * `Repeat2`) — corrected here per that table taking precedence over any
 * mobile-shape-consistency judgment call.
 */
export const TABLER_TO_LUCIDE_ICON_MAP = {
  "ti-menu-2": { lucide: "Menu", usage: "Header leading icon (opens drawer)" },
  "ti-search": { lucide: "Search", usage: "Header/bottom-nav search" },
  "ti-bell": { lucide: "Bell", usage: "Notifications" },
  "ti-heart": { lucide: "Heart", usage: "Like action" },
  "ti-message-circle": { lucide: "MessageCircle", usage: "Comment action" },
  "ti-repeat": { lucide: "Repeat", usage: "Repost/ReDrop action" },
  "ti-dots": { lucide: "MoreHorizontal", usage: "Post more-menu" },
  "ti-home": { lucide: "Home", usage: "Bottom nav: Home" },
  "ti-users-group": {
    lucide: "Users",
    usage: "Bottom nav slot (reference only)",
    note:
      "Reference's 2nd bottom-nav slot is Clubs; shipped WYNOS bottom nav keeps Search in that " +
      "slot instead (existing product destination, preserved per app-shell/home doc's Bottom " +
      "Navigation \"Design Rules\" section) — mapped here for completeness of the reference only.",
  },
  "ti-plus": { lucide: "Plus", usage: "Bottom nav: create-post CTA" },
  "ti-message-2": {
    lucide: "MessageCircle",
    usage: "Chat (existing WYNOS home header action, not a bottom-nav slot)",
  },
  "ti-user": { lucide: "User", usage: "Bottom nav: profile" },
  "ti-alert-circle": {
    lucide: "AlertCircle",
    usage: "Failed-to-send post error-box icon (wynos-home.html correction, 2026-09-14)",
  },
} as const;
