# WYN-159 — App Shell, Home Feed, Bottom Navigation, Post Card

Tokens/primitives referenced here are defined in `wyn-159-web-v2-design-system.md` — do not redefine
values locally. Existing code referenced: `web/components/home/*.tsx`, `web/components/bottom-navigation.tsx`,
`web/app/page.tsx`, `web/app/bottom-nav.css`, `web/app/home.css`.

---

## Screen: App Shell (`WynosAppShell`)

**Purpose:** Provide the single page frame every route mounts into — background, max-width column,
safe-area handling, and the header/tabs/bottom-nav slots — so no screen re-implements layout chrome.

**User Flow:** Not a screen a user navigates to; it wraps every route. Renders `WynosHeader` (variant
per route), routed content, and `WynosBottomNav` (hidden on focused sub-screens like Post Detail per
existing Flutter-parity behavior already recorded in `wyn-071`/`wyn-158`).

**Components:** `WynosAppShell`, `WynosHeader`, `WynosBottomNav`.

**Interactions:** None directly; delegates to header/nav.

**States:** N/A (structural).

**Responsive Behavior:**
- Mobile (≤767px): full-width, content edge-to-edge minus 16px side padding where the reference uses it
  (header/post padding), bottom nav fixed with `env(safe-area-inset-bottom)`.
- Tablet/Desktop (≥768px): centered content column, `max-width: 600px` (wider than the reference's
  400px "phone card" since that 400px was a demo staging frame, not a real content measure — 600px is
  the standard readable-column width for a text-led feed; confirm with Founder if a different max-width
  is preferred). No card border/radius around the whole page at desktop — the 16px-radius `.app` box in
  the reference was a mockup device frame, not a chrome element to reproduce literally at every viewport.
  Background outside the column may use `--surface` to separate content from viewport edge at wide
  screens (open question — default to plain `--bg` if unsure, simplest option).
- Default per open question #2 in the design-system doc: no desktop sidebar, same bottom nav pinned,
  centered column. Revisit if Founder wants a sidebar.

**Accessibility:** Skip-to-content link before header (already exists as a pattern from WYN-141 Admin
batch — reuse the same approach). Landmark roles: `header`, `nav`, `main`.

**Design Rules:** `--bg` background, no outer border/shadow at real viewport widths (only in isolated
component-preview contexts if any). Bottom nav and header both sit on hairline `--border` dividers, never
shadows.

**Handoff:** AI Coding creates `WynosAppShell` first, before any screen migrates, since every other
component in this batch mounts inside it.

---

## Screen: Header (`WynosHeader`)

**Purpose:** Consistent top bar across Home/Search/Notifications/etc., with a route-appropriate
leading control, center content, and trailing actions.

**User Flow:** Static chrome; leading icon opens the side drawer (existing `home-drawer.tsx` behavior)
on Home, or acts as back navigation on stacked routes (Post Detail, Settings sub-pages).

**Components:** `WynosHeader`, `WynosIconButton`.

**Interactions:**
- Leading `WynosIconButton` (menu icon on Home; back-chevron on stacked routes) — tap opens drawer /
  navigates back.
- Trailing `WynosIconButton`s (Search, Notifications on Home; route-specific elsewhere) — tap navigates.
- Center: brand wordmark + mark on Home; page title (14–16px, 600 weight) on other routes.

**States:** Notification bell shows an unread-count badge (reuse existing `notificationBadge` data from
`BottomNavigation`'s current contract — do not duplicate the unread-count source of truth) — small red
dot or count pill using `--accent-red`, the one place besides Like where color is allowed, since it is a
genuine status signal, not decoration.

**Responsive Behavior:** Identical structure at all widths; header content stays within the same
max-width column as the app shell, does not stretch full-bleed at desktop.

**Accessibility:** All icon buttons carry `aria-label` (reference already does this in Thai — preserve
exact existing labels: "เมนู", "ค้นหา", "การแจ้งเตือน"). Minimum 44×44px hit area even though the visual
icon is 22px (pad via button box, not icon scale).

**Design Rules:** `border-bottom: 1px solid var(--border)`, `14px 16px 0` padding matching reference,
no shadow.

**Handoff:** Depends on `WynosIconButton`. Build alongside App Shell.

---

## CORRECTION (2026-09-14): exact source of truth for Home and Post Card

Founder supplied `.wyn/docs/design/reference/wynos-home.html` as **100% literal source of truth** for
this screen, correcting/superseding the "Home Feed" and "Post Card" sections below wherever they conflict.
Binding rules from the Founder's brief, restated so Coding does not have to re-derive them:

- DOM structure, element order, and class names must match the reference **exactly** — map each reference
  class to a component/CSS-module class 1:1 rather than inventing a different structure that looks the same.
- Every CSS value (color, radius, spacing, font-size) must match **exactly**. No rounding, no approximation,
  no substituting a "close enough" token.
- Keep the reference's CSS variable names (`--text-primary`, `--accent-red`, `--border`, `--danger-bg`,
  etc.) or map them 1:1 to this project's `tokens.css` — same names where possible, so anyone diffing the
  two files can trace every value.
- Icons: Tabler Icons (`ti ti-*`) or the closest equivalent already available in the project's icon library
  (`lucide-react`) — see the icon-mapping table in `wyn-159-web-v2-design-system.md`, extended below for
  the two icons this file adds (`ti-alert-circle`).
- The `.brand` SVG is a **temporary placeholder** — wire it to swap for the real brand logo file (woven-W)
  when that asset exists; don't treat the inline path as final brand art.
- **The three post variants in the file (text-only / image-carousel / failed-to-send) are one component
  with props, not three hardcoded blocks.** Build a single Post component whose variant is driven by data
  (e.g. `media: [] | MediaItem[]`, `sendStatus: "sent" | "failed"`), matching the reference's shared
  `.post-block` skeleton.
- After implementation, open the rendered app next to `wynos-home.html` and diff visually — anywhere they
  differ, fix the implementation to match the file, not the other way around.

### Corrected structure (literal, replaces the looser description under "Post Card" further down)

```
article.post-block                         (border-bottom: 1px solid var(--border); last post: none)
  div.post-head-row                        (padding: 14px 16px 0)
    div.post                               (display:flex; gap:10px)
      div.avatar                           (36x36, round, var(--border) fill; opacity:.5 on failed variant)
      div.post-body                        (flex:1, min-width:0)
        div.post-head                      (flex, space-between)      -- omitted entirely on failed variant,
                                                                          which renders only post-meta's name
          div.post-meta                    (14px, name 600 weight, " · " + time in var(--text-muted))
          div.post-head-actions            (flex, gap:8px)            -- omitted on failed variant
            button.follow-btn               (pill, see design-system tokens)
            button.more-btn                 (ti-dots)
        p.post-text                        (15px/1.5, margin:6px 0 10px; opacity:.6 on failed variant)
        div.post-actions                   (flex, gap:28px)           -- present on text-only variant only
                                                                          (rendered here, inside post-body,
                                                                          for the no-media case)
        div[style="height:14px"]           -- text-only variant's bottom spacer inside post-body
        div.error-box                      -- failed variant only, see below
  div.post-media-wrap                      -- carousel variant only, sibling of post-head-row (NOT nested
                                               inside post-body) so the carousel can bleed to full card width
    div.carousel                           (flex, gap:6px, overflow-x:auto, scroll-snap-type:x mandatory,
                                             padding: 0 16px 10px 62px — 62px = 16 card pad + 36 avatar +
                                             10 gap, so the first image's left edge lines up with the text
                                             above it, not with the card edge)
      div.carousel-item × N                (220x270, var(--surface) fill, 12px radius, scroll-snap-align:start)
  div.dots                                 -- carousel variant only, sibling after post-media-wrap
                                             (flex, centered, gap:4px, margin-bottom:10px; each dot 5x5 round,
                                             var(--border-strong), active dot var(--text-primary))
  div.post-footer                          -- carousel variant only, sibling after dots (padding: 0 16px 14px)
    div.post-actions                       (flex, gap:28px — same action row as text-only, just relocated
                                             below the media instead of inside post-body)
```

Three variants, one component, distinguished by **where the action row and closing spacer land**, not by
different markup per case:

1. **Text-only** (no media, `sendStatus: "sent"`): `post-actions` + the 14px spacer render directly inside
   `post-body`, after `post-text`. No `post-media-wrap`/`dots`/`post-footer` render at all.
2. **Image carousel** (`media.length > 0`): `post-body` stops after `post-text` (no actions, no spacer
   inside it). `post-media-wrap` (carousel) and `dots` render as siblings of `post-head-row` inside the
   `post-block`, then `post-footer` (containing the same `post-actions`) closes the card below the media.
3. **Failed to send** (`sendStatus: "failed"`): `post-head` (name+time+follow+more) is **not rendered** —
   only a bare name (`คุณ`, i.e. "you", since this is always the current user's own unsent post) inside
   `post-meta`. Avatar and post-text both render at reduced opacity (`.5` / `.6` respectively — literal
   values from the file, not a token, since this is a one-off transient state). `post-actions` is replaced
   entirely by an `error-box`: `ti-alert-circle` icon + message text ("โพสต์ไม่สำเร็จ ตรวจสอบอินเทอร์เน็ต")
   + a "ลองอีกครั้ง" (retry) button, all in `--accent-red` on a `--danger-bg` pill (`border-radius: 10px`,
   `padding: 8px 12px`, `gap: 8px`). No `post-media-wrap`/`dots`/`post-footer` for this variant either
   (the reference shows it text-only, but the component should still accept `media` on a failed post if the
   product needs that combination later — just don't invent carousel-on-failed styling now, nothing in the
   reference specifies it).

### Tabs — corrected

`wynos-feed.html` (the first reference) had left-aligned tabs (`gap:18px`, no `justify-content`).
`wynos-home.html` (this newer, authoritative reference) **centers** the tabs (`justify-content: center`,
`gap: 20px`). Use the centered version — it is the more recent, more precise file and this doc's fidelity
mandate makes it authoritative over the earlier mockup for anything the two disagree on.

### Icon mapping — superseded 2026-09-14

The icon-font-based mapping originally sketched here is superseded by the full semantic mapping table in
`wyn-159-web-v2-design-system.md` (Icon Set section), derived from the newer `wynos-home-v2.html` reference
which uses inline SVG rather than a CDN icon font. Use that table as the single source of truth for every
icon on this screen, including `AlertCircle` for the failed-post error box and `MoreHorizontal` for the
post/header "more" menus (not a literal 3-dot custom SVG).

---

## Screen: Home Feed (route `/`)

**Purpose:** Primary content surface — three feed modes, scrollable post list.

**User Flow:** Land on Home (post-auth) → default tab "สำหรับคุณ" → switch tabs via `WynosTabs` → scroll
posts → tap post opens Post Detail → tap avatar/name opens Profile → tap Follow toggles follow state
inline (existing behavior, preserve exactly) → tap central bottom-nav CTA opens Create Post composer
(existing `?compose=1` query-param pattern in `bottom-navigation.tsx` — preserve).

**Components:** `WynosHeader` (Home variant), `WynosTabs` (replaces current `HomeTabs`/`wyn-home-tabs`
styling, same `HomeFeedMode` data contract: `for-you` / `following` / `clubs`, same Thai labels), list of
`WynosPostCard`, `WynosBottomNav`.

**Interactions:** Tab switch (existing `onSelect` callback, no data-flow change), pull-to-refresh /
infinite scroll (preserve current pagination behavior exactly — this is a visual migration only),
Like/Comment/Repost/Share taps on each card (existing handlers in `home-post-card.tsx`/`post-actions.tsx`,
unchanged).

**States:**
- Loading: `WynosLoadingState` skeleton rows shaped like `WynosPostCard` (avatar circle + 2 text bars),
  not a generic spinner — matches reference's content-first density.
- Empty (e.g. "กำลังติดตาม" tab with no follows yet): `WynosEmptyState` with existing copy, restyled to
  monochrome (no colorful illustration bursts — simple line icon + text).
- Error: inline retry row, same tone as rest of system (text-primary message, text button retry).

**Responsive Behavior:** Single column at all widths (do not introduce a masonry/2-column layout — that
was a prior WYN-107 experiment for a different visual direction; the reference is single-column and nothing
in this brief asks to revisit that). Tabs remain horizontally scrollable only if they overflow at narrow
widths; at ≥768px they fit without scrolling.

**Accessibility:** `WynosTabs` uses `role="tablist"`/`role="tab"`/`aria-selected` (existing `HomeTabs`
already does this correctly — preserve). Post cards are focusable/navigable via keyboard (existing `Link`
usage in `post-actions.tsx` for comment count → detail navigation; extend the same pattern so the whole
card's primary tap target is keyboard-reachable).

**Design Rules:** Post-to-post divider is a single `1px solid var(--border)` (no card elevation, no gaps
between posts beyond the divider — matches reference exactly, this is the most visually load-bearing rule
in the whole redesign since it is what makes the feed read as "X/Threads" rather than "boxed cards").

**Handoff:** Build after App Shell + tokens are in place. This is the Founder-designated flagship screen —
capture a screenshot and get sign-off before proceeding to remaining batches, even though the brief asked
for full spec up front; the migration-order rule from the design-system doc still requires a stop-and-check
after this batch specifically because Home is the visual reference point for everything after it.

---

## Screen: Post Card (`WynosPostCard`)

**Purpose:** The atomic feed unit; reused in Home, Profile media/repost tabs, Search results, and (in
expanded form) Post Detail.

**User Flow:** See Home Feed above; also reachable via Profile tabs and Search.

**Components:** `WynosAvatar` (36px), `WynosPostHeader` (name + timestamp + `WynosPillButton` Follow +
more-menu `WynosIconButton`), body text, media (see Media section below), `WynosPostActions`.

**Interactions:** Tap avatar/name → Profile. Tap Follow pill → toggle (existing debounce/optimistic-update
behavior preserved). Tap more (`⋯`) → opens existing report/mute/block/save sheet (`WynosSheet`), unchanged
menu contents. Tap body/media → Post Detail. Like/Comment/Repost/Share/Save per Post Actions below.

**States:**
- Own post: no Follow pill (existing rule, preserve).
- Already following: Follow pill hidden or shows "กำลังติดตาม" per existing convention — do not
  reintroduce a pill that was previously removed for followed authors; confirm current behavior in
  `post-author-row.tsx` before Coding and preserve it exactly.
- Liked: red heart, filled, per reference (`--accent-red`, filled icon) — this is the only place in the
  entire redesign where a non-monochrome color is load-bearing, keep it exactly as the reference shows.
- Redropped/reposted: filled/active icon state, monochrome (text-primary), not colored — reference doesn't
  show this state but existing WYN convention (WYN-089/096) uses an active monochrome fill for Redrop,
  which stays consistent with "color reserved for Like only."

**Responsive Behavior:** Card layout (avatar column + content column, `10px` gap) unchanged across
breakpoints; only the outer column width changes (App Shell responsibility, not the card's).

**Accessibility:** Follow pill and more-menu are independently focusable/actionable from the rest of the
card (existing `stopPropagation` pattern, if present, preserve so tapping Follow doesn't also open the post).

**Design Rules:** Exactly as tokens/design-system doc: `14px 16px` padding, `10px` avatar gap, `15px/1.5`
body text, `28px` gap between action items, `18px`→ use `24px` per existing `lucide-react` icon size
already in `post-actions.tsx` (the reference's `18px` was for its own `<i>` webfont icons; keep the
already-shipped 24px Lucide sizing for real icons rather than shrinking working icons to match a demo's
font-icon metrics — note this as an intentional, sized-for-real-icons deviation, not an oversight).

**Handoff:** Depends on Avatar, Pill Button, Icon Button primitives. Extend the reference's 3-action row
(Like/Comment/Repost) to the existing real WYN 4–5 action set (Like/Comment/Repost/Share, plus Save on
Post Detail per brief's explicit 5-action requirement there) — see Post Detail spec for the full row.

---

## Screen: Media / Image Posts

**Purpose:** Consistent treatment for single images and multi-image carousels within a post.

**Components:** Extends `WynosPostCard` body; reuses existing `post-media-carousel.tsx` behavior/logic.

**Interactions:** Swipe/tap through carousel (existing), tap image → fullscreen viewer (existing route/
overlay, restyle chrome only).

**States:** Loading placeholder (skeleton block, `--surface` fill, no shimmer gradient — flat, matches
"no gradients" rule), failed-to-load fallback (existing icon + retry).

**Responsive Behavior:** Full content-column width, existing WYN aspect-ratio preservation logic
(WYN-093/WYN-109) unchanged — this redesign restyles chrome, not media math.

**Accessibility:** Existing alt-text/aria behavior preserved; carousel dots need `aria-label` per index
if not already present.

**Design Rules:** `16px` radius (`--radius-card`) on media corners, no border around images (reference
has no border on its media-equivalent elements; a hairline border reads as an extra decorative layer this
system avoids), carousel position indicators as small subtle dots (`--border-strong` inactive, `--text-primary`
active) rather than a colored/pill indicator.

**Handoff:** Migrate alongside Post Card since it's the same component tree.

---

## Screen: Bottom Navigation (`WynosBottomNav`)

**Purpose:** Primary cross-app navigation, persistent on top-level routes.

**User Flow:** Tap any of 5 slots to navigate; tap center CTA to open composer.

**Components:** `WynosBottomNav`, `WynosIconButton` (per slot), circular CTA button.

**Interactions:** Existing `isActive(href)` active-state logic (from current `BottomNavigation`) preserved
exactly — same 5 destinations and hrefs (`/`, `/search`, compose CTA, `/notifications`, profile).

**States:** Active slot renders icon in `--text-primary`; inactive slots in `--text-secondary` (reference:
`.nav-btn` vs `.nav-btn.active`). Notification slot shows unread badge (existing `notificationBadge` prop,
red dot/count using `--accent-red`).

**Responsive Behavior:** Fixed to viewport bottom with safe-area padding on mobile; on desktop the current
product decision (open question #2) is to keep this exact bottom nav rather than moving navigation to a
sidebar — same component, same position, just sitting under the wider centered column.

**Accessibility:** `aria-label` per slot preserved from existing implementation (already present: "หน้าหลัก",
"ค้นหา", "สร้างโพสต์ใหม่", "การแจ้งเตือน" + label, "โปรไฟล์"). Keep 44×44px+ tap targets.

**Design Rules — CORRECTED 2026-09-14, supersedes the paragraph below:**
Founder reviewed a direct side-by-side screenshot comparison (implementation vs.
`wynos-home-v2.html`) and explicitly confirmed: match the reference **100% exactly**, including
navigation structure, not just visual language. This is a deliberate, informed override of the
"preserve existing destinations" reasoning below — Founder was told plainly that this relocates
Search and Notifications out of the bottom nav, and confirmed anyway. Binding spec now:

- **Bottom nav** (global — this component is shared chrome across essentially every top-level
  route via `AppChrome`, not just Home; this change affects site-wide navigation, not only the
  Home screen): icon-only, **no text labels**, exactly 5 slots in this order: Home / Clubs /
  Post-CTA / Chat / Profile. Clubs → `/clubs`, Chat → `/chat` (both existing real routes already
  in the product, simply promoted from secondary to primary nav). Active state
  `--text-primary`, inactive `--text-secondary`, circular black center CTA exactly as the
  reference, `21px` icon sizing at rest per the reference (24px CTA glyph, existing convention).
- **Header trailing actions** (Home only — other routes keep their own existing headers,
  unaffected): replace the single Chat-icon-with-badge action with **two** icons matching the
  reference exactly — Search (`/search`) and Bell/Notifications (`/notifications`, carrying the
  unread-badge logic that used to live on the bottom nav's notification slot).
- **Brand wordmark text**: reference literally spells it `Wynos` (capital W only), not `WYNOS`
  (all-caps). Match this exactly **on the Home header specifically** — this correction is scoped
  to this one reference file's wordmark element, not a global rebrand; every other `WYNOS`
  mention elsewhere in the product (Welcome screen, Settings version footer, etc.) is out of
  scope for this file and stays as-is unless a separate reference/instruction says otherwise.

Superseded reasoning (kept for audit trail, no longer binding): the original assumption was that
"preserve existing destinations, don't silently delete routes" meant the nav's destination *set*
must stay fixed and only its *paint* could change. Founder's explicit, informed confirmation after
seeing the concrete tradeoff (Search/Notifications leaving the bottom bar) replaces that
assumption — nothing is actually deleted (both routes remain reachable, just relocated to the
header to match the reference precisely), so this is compatible with "do not silently delete
product routes" once Search/Notifications have a real, equally-reachable new home.

**Handoff:** Depends on Icon Button + tokens. This is a global chrome change (bottom nav affects
every route using `AppChrome`) — build and verify across multiple routes, not just Home, before
considering this done.
