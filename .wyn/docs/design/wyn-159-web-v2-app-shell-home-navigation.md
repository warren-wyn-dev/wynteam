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

**Design Rules — reconciling reference vs. existing product requirements:**
The reference nav is icon-only (no text labels) with a 5th slot layout of Home / Clubs / Post-CTA / Chat /
Profile. The current shipped nav is icon **+ label** with Home / Search / Post-CTA / Notifications /
Profile, and Search and Notifications are real, frequently-used top-level destinations in WYNOS today.
Per the Founder brief's own instruction — "if existing WYNOS destinations differ from the reference HTML,
preserve required product destinations while keeping the SAME visual language... do not silently delete
product routes" — **the destinations do not change**: keep Home / Search / Post-CTA / Notifications /
Profile. What changes is the **visual language**: monochrome icon coloring (active = `--text-primary`,
inactive = `--text-secondary`), the circular black center CTA exactly as the reference shows it, `21px`
icon sizing at rest (24px for the CTA glyph per existing Lucide sizing convention), and the same hairline
top border instead of any heavier chrome. Labels stay (dropping an existing, working affordance is a
product/IA change outside this redesign's scope, not a visual one) but are restyled to the type scale in
the design-system doc (11.5px existing size is fine to keep — it's already close to reference proportions;
only recolor/reweight, don't resize).

**Handoff:** Depends on Icon Button + tokens. Build immediately after Home so the flagship screenshot
includes real navigation.
