# WYN-175 — Perceived Speed & Motion (Design Spec)

Status: DESIGN — waiting on Founder decision for Route Transition (Option A vs B)
Date: 2026-09-19
Preview: https://claude.ai/artifact/V8UKS6DB4nkvWdvk2XGcS2

## Correction to WYN-174/175 product audit

WYN-174's initial gap analysis (grep-based) undercounted what already exists. A closer read of `web/components/ui/page-transition.tsx` and `web/components/ui/skeleton.tsx` found:

- **Route transition already exists**: `PageTransition` (framer-motion, opacity-only cross-fade, 70ms, `mode="wait"`) wraps every route in `web/app/layout.tsx`. The code comment states this is deliberately minimal — navigation is already instant via `lib/mount-cache.ts`, so the fade only exists to avoid a jarring cut, not to be a visible animation.
- **Skeleton loading already exists** as a shared system (`SkeletonBlock`, `SkeletonCircle`, `FeedSkeleton`, `ProfileSkeleton`, `ChatListSkeleton` in `components/ui/skeleton.tsx` + shimmer in `app/skeleton.css`), used in Home, Profile, Chat inbox.
- **Real gap**: Search (`search-route.tsx`) and Notifications (`notifications-route.tsx`) still use a plain centered spinner (`LoadingState` in `phase3-ui.tsx`) instead of skeleton.
- **Press feedback**: `.wyn-button:active` already has `scale(0.985)` (`design-system.css`); several rows have `:active` states (`chat-row`, `wyn-post-follow-pill`). Post cards and search result rows do not.

This spec covers the 3 real gaps, following `ห้ามคิดทิศทาง visual ใหม่หากมี design system ที่อนุมัติแล้ว`: everything below reuses existing tokens/components (`SkeletonBlock` primitives, `.wyn-button` press pattern, Flutter's `WynMotion` duration table from `ds-010-interaction-feedback.md`) — no new colors, radii, or shimmer style.

## Screen: Search & Notifications loading state

**Purpose**: Replace the generic spinner with content-shaped skeleton placeholders, matching the treatment Home/Profile/Chat already have, so these two screens stop feeling like a plain website mid-load.

**User Flow**: Unchanged — user opens Search or Notifications, data fetch starts, skeleton shows instead of spinner while `loading && !rows.length` (same condition already in the code), then real rows replace it in place (no layout shift since skeleton row heights match real row heights).

**Components** (new, all composed from existing `SkeletonBlock`/`SkeletonCircle`):
- `SearchUserSkeleton` — avatar circle (40px) + 2 text lines, matches `ProfileRowView` row shape
- `SearchClubSkeleton` — same shape as user (club icon is also circular in current UI)
- `SearchDropGridSkeleton` — 3-column grid of square blocks, matches `DropPreviewCard` grid
- `SearchHashtagSkeleton` — text-only rows (no avatar)
- `NotificationSkeleton` — avatar circle (44px) + 2 text lines, matches `Avatar` + message row shape in `notifications-route.tsx`

**Interactions**: None — this is a passive loading state, no tap targets.

**States**: Shown only when `loading && !rows.length` (first load / new query). Pagination loading (`loading && rows.length > 0`, "ดูเพิ่มเติม" button) keeps its existing `disabled` spinner-in-button behavior — not in scope, not broken by this change.

**Responsive Behavior**: Row skeleton widths use `%`-based placeholder bars (already the pattern in `skeleton.tsx`), so they scale with viewport width same as existing Home/Profile skeletons.

**Accessibility**: `aria-label`/`aria-live="polite"` on the skeleton container, same pattern as `FeedSkeleton`/`ChatListSkeleton` ("กำลังโหลด..."). Shimmer animation respects `prefers-reduced-motion` via the existing `@media` rule in `skeleton.css` (already covers any element using `.wyn-skeleton`, no new CSS needed there).

**Design Rules**: Reuse `.wyn-skeleton` class and shimmer keyframe as-is. No new color/radius token. Skeleton item count: 5 rows for Search tabs, 6 rows for Notifications (matches `ChatListSkeleton` default), 6 tiles for the Drops grid tab.

**Handoff**: → AI Coding. Build the 5 new skeleton components in `components/ui/skeleton.tsx`, swap `<LoadingState />` for the matching skeleton in `search-route.tsx` (4 call sites — Users/Drops/Clubs/Hashtags tabs) and `notifications-route.tsx` (1 call site). No backend/data change.

## Screen: Press feedback (system-wide)

**Purpose**: Give every tappable card/row a visible, immediate press state, matching the `.wyn-button:active` pattern that already exists, so touch interactions feel acknowledged instantly like a native app instead of waiting for navigation to prove the tap registered.

**Components affected**: Post card (feed), search result rows (user/club), profile recommendation cards — anywhere with an `onClick`/`<Link>` wrapping a card-shaped or row-shaped element that currently has no `:active` rule.

**Interactions**: `:active` triggers `transform: scale(0.96)` + 90ms transition (`transform 90ms ease`), released instantly on release/pointer-up (no separate "unpress" animation — matches `WynMotion.press = 90ms` from `ds-010-interaction-feedback.md`, the existing Flutter token for "ปุ่มตอบสนองนิ้ว").

**States**: default → active (pressed) → default. No visual "loading"/"disabled" state introduced by this — existing disabled handling on buttons is untouched.

**Responsive Behavior**: `:active` is a pointer/touch-driven pseudo-class; on desktop pointer (mouse) it still fires on mousedown, which is fine — same as existing `.wyn-button` behavior today.

**Accessibility**: Purely visual feedback layered on existing tap targets — no change to focus order, ARIA roles, or keyboard activation (`:active` doesn't fire on Enter/Space keyboard activation in most browsers; that's an acceptable, pre-existing gap shared with `.wyn-button` today, not introduced by this change).

**Design Rules**: `scale(0.96)`, not Flutter's `0.94` — cards on web are larger tap targets than mobile-app buttons, and `0.96` sits closer to the web's own existing `.wyn-button:active` value (`0.985`) than Flutter's number does, so the two press treatments already on the page (button vs. card) don't visually clash. Transform + opacity only, never layout properties (same restriction as `WynMotion` §5: "ไม่ animate padding/width/height").

**Handoff**: → AI Coding. Add a shared `.wyn-pressable:active { transform: scale(0.96); }` (90ms transition, `prefers-reduced-motion` guard reusing the existing pattern at `design-system.css:360`) utility class, apply to `PostCard`, search result row components, and any other existing card/row component missing `:active` — audit scope: everything currently rendered via `DropPreviewCard`, `ProfileRowView`, and club/user search rows.

## Screen: Route transition — DECISION NEEDED

**Purpose**: Decide whether WYNOS Web keeps its current near-invisible page fade or adopts a more visible, native-feeling directional transition.

**Two options presented in the preview artifact, not a recommendation to pick one over the other** — this is a product feel decision, not a technical one:

- **Option A — keep as-is**: `PageTransition` unchanged (70ms opacity fade). Zero risk, zero code change, matches the original engineering intent documented in the component's own comment.
- **Option B — add directional motion**: Port `WynMotion.standard` (220ms) from the Flutter interaction system to the web's `PageTransition` — slide (24px) + fade instead of fade-only. Reads more like a native app pushing/popping a screen; adds ~150ms more perceived transition time.

**Design Rules for Option B if chosen**: `cubic-bezier(.22,.61,.36,1)` easing (approximates Flutter's default emphasized-decelerate curve), transform + opacity only, `prefers-reduced-motion` collapses to Option A's plain fade (per `WynMotion` §6: "ตัดการเดินทาง ไม่ตัดสถานะ" — reduced motion removes distance traveled, not the state change itself).

**Handoff**: → **Founder decides A or B first** (via the preview artifact or the chat question below) → then AI Coding implements the chosen option only. Skeleton and press-feedback tracks above do not depend on this decision and can start immediately.
