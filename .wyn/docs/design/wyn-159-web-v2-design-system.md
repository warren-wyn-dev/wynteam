# WYN-159 — Consumer Web v2 Design System (Monochrome)

Status: APPROVED DIRECTION (Founder-provided master reference) — component/screen migration in progress
Source of truth: `.wyn/docs/design/reference/wynos-feed.html` (Founder-attached master, verbatim copy)
Supersedes for Consumer Web only: `.wyn/docs/design/design-principles.md` (Blue+White+Soft Gray direction
stays in force for Mobile Flutter app and Admin/Seller dashboards; it does not apply to `web/` anymore)

## Why this document exists

Founder's brief said "extract the design system directly from wynos-feed.html" and "create a real
reusable WYNOS design-token layer." This is that layer. Every screen spec in the `wyn-159-web-v2-*.md`
series consumes these tokens/primitives instead of re-deriving values. AI Coding must implement tokens
here as actual code (CSS custom properties / TS constants) in one place, not copy literals per file.

## Design Principles (Consumer Web only)

- Minimal, white, clean, lightweight, compact, social-first, modern, monochrome.
- Subtle gray hierarchy carries structure — color is reserved for exactly one signal (like-state red).
- Rounded but not excessively rounded (16px cards, pill buttons/tabs only where the reference uses them).
- No heavy shadows, no gradients, no stacked cards-on-cards, no oversized controls/typography, no dense
  borders, nothing that reads as the old Flutter-parity look.
- Reference mood: X (Twitter) / Threads — content-first, text-led, generous whitespace, restrained chrome.

## Color Tokens

| Token | Value | Usage |
|---|---|---|
| `--bg` | `#FFFFFF` | Page/app background |
| `--surface` | `#FAFAFA` | Hover states, subtle secondary surfaces (never a second "card on card") |
| `--text-primary` | `#0A0A0A` | Names, body text, active states, icons at rest |
| `--text-secondary` | `#6B6B6B` | Timestamps, secondary icons, inactive nav/tabs |
| `--text-muted` | `#9A9A9A` | Least-important metadata (e.g. inline separators) |
| `--border` | `#E7E7E7` | Default hairline dividers |
| `--border-strong` | `#D0D0D0` | Outlined buttons (Follow), stronger separators |
| `--accent-red` | `#E0203D` | **Only** for the liked/active Like state. Never used decoratively. |

Dark mode: not in the Founder-attached reference (light-only mockup). Do not invent a dark palette
speculatively — flag to Founder as an open question before Coding builds one. Until answered, ship
light-only for `web/` (this is a scope reduction from the old design-principles.md dark-mode-from-day-one
rule, so it is called out explicitly rather than silently dropped).

Status colors (success/error/warning outside of Like) are not defined in the reference. Until Founder
specifies otherwise, keep the existing WYN convention (green success / red error / amber warning) from
`design-principles.md` — this is inherited, not reinvented, since the brief only redefines the primary
monochrome+accent system, not status semantics.

## Typography

Font stack (verbatim from reference): `-apple-system, "Segoe UI", "Noto Sans Thai", sans-serif`

| Role | Size | Weight | Color | Notes |
|---|---|---|---|---|
| Brand wordmark | 16px | 600 | primary | Header center |
| Post author name | 14px | 600 | primary | |
| Post timestamp | 14px | 400 | muted | Same line as name, ` · ` separator |
| Post body text | 15px | 400 | primary | `line-height: 1.5` |
| Tab label | 14px | 400 (600 active) | secondary (primary active) | |
| Action count | 13px | 400 | secondary (red when liked) | |
| Follow button | 12px | 600 | primary | |

Minimum body text stays 14px+ per accessibility rule inherited from `design-principles.md` (post body
at 15px already clears this; verify any smaller derived text, e.g. captions, does not drop under 14px).

## Spacing Scale

4px-based grid, consistent with existing WYN convention: `4, 8, 10, 12, 14, 16, 18, 24, 28, 32`.
Reference-specific usages to preserve exactly:

- Post padding: `14px 16px`
- Avatar-to-content gap: `10px`
- Header horizontal padding: `16px`, top `14px`
- Tabs gap: `18px`
- Post action group gap: `28px`
- Action icon-to-count gap: `5px`

## Radius Tokens

- `--radius-card: 16px` — outer app container, media corners, sheets/modals
- `--radius-pill: 999px` — Follow button, pill tabs/chips, circular nav CTA

## Sizing Tokens (derived — verify against reference, extend for real product needs)

| Element | Size |
|---|---|
| Avatar (feed row) | 36×36px |
| Avatar (profile header) | 72×72px *(derived — no profile screen in reference; keep within existing WYN touch-target/hierarchy rules)* |
| Header icon button | 22px icon, 4px padding → ~30px hit area *(pad to 44×44px minimum touch target per accessibility rule — visually 22px icon inside a larger invisible hit box, do not enlarge the icon itself)* |
| Bottom nav icon | 21px |
| Bottom nav central CTA | 38×38px circle, black fill, white icon |
| Post action icon | 18px |
| Follow button | 4px 14px padding, 12px text, pill |
| Header height | ~54px (14px top pad + row + 12px margin, excludes tabs) |
| Tabs row height | ~34px (14px text + 10px bottom padding + border) |
| Bottom nav height | ~58px (10px vertical padding + 38px max control) + safe-area inset |

## Icon Set

Reference uses **Tabler Icons** (`ti ti-*`, via `tabler-icons` webfont/CDN class names: `ti-menu-2`,
`ti-search`, `ti-bell`, `ti-heart`, `ti-message-circle`, `ti-repeat`, `ti-dots`, `ti-home`,
`ti-users-group`, `ti-plus`, `ti-message-2`, `ti-user`). AI Coding: do not pull the CDN webfont into
production (external font-icon CDN is not appropriate for a production bundle); use the already-installed
`lucide-react` (present in `web/package.json`) and map each Tabler name to its closest Lucide equivalent,
keeping the same visual weight (outline style, ~1.5–1.75 stroke) and the sizes in the table above. Record
the mapping table in the app-shell spec doc so it is not re-derived per screen.

## Canonical Component Primitives

Build these once, reuse everywhere. Names below match the Founder brief; file locations are proposed
for AI Coding, adjust only if the existing `web/components` structure gives a clearly better home.

| Component | Purpose | Reference basis |
|---|---|---|
| `WynosAppShell` | Page frame: max-width column, background, safe-area padding | `.app` |
| `WynosHeader` | Top bar: leading icon button, centered brand OR page title, trailing actions | `.header`, `.header-row` |
| `WynosIconButton` | Icon-only tap target, ghost style, consistent hit area | `.icon-btn` |
| `WynosTabs` | Horizontal scrollable text tabs with active underline | `.tabs`, `.tab` |
| `WynosAvatar` | Circular avatar, size variants (36 / 72 / custom), fallback state | `.avatar` |
| `WynosPostCard` | Feed post: avatar + author row + body + actions | `.post` |
| `WynosPostHeader` (= post author row) | Name, timestamp, Follow pill, more-menu | `.post-head` |
| `WynosPostActions` | Like/Comment/Repost(/Share/Save) row | `.post-actions`, `.action` |
| `WynosButton` | Primary/secondary solid button (composer submit, settings actions, etc.) | derived — not in reference, follow monochrome rules |
| `WynosPillButton` | Outlined pill button (Follow, filter chips) | `.follow-btn` |
| `WynosBottomNav` | 5-slot bottom navigation with circular center CTA | `.bottom-nav`, `.nav-btn`, `.post-cta` |
| `WynosListRow` | Generic row: leading icon/avatar, label, trailing control/chevron | derived — Settings/Notifications/Chat inbox rows |
| `WynosSection` | Grouped content block with optional header label | derived — Settings groups, Profile stat blocks |
| `WynosSheet` | Bottom sheet (mobile) / centered panel (desktop) for menus, composer options | derived |
| `WynosModal` | Centered dialog for confirmations | derived |
| `WynosInput` | Text field, single-line | derived |
| `WynosSearchField` | Search input with leading icon, clear affordance | derived |
| `WynosEmptyState` | Icon/illustration + message for empty lists | derived |
| `WynosLoadingState` | Skeleton row matching `WynosPostCard`/`WynosListRow` shapes | derived |

"Derived" components have no direct reference mock — they must still obey the tokens above (colors,
radius, spacing, typography) so they read as native to the same system, not bolted on.

## CSS Architecture Migration Strategy

Current state (audited 2026-09-14): 25 CSS files under `web/app/*.css`, ~5,000 lines total, named after
their migration history rather than their purpose (`founder-parity-lock.css`, `pixel-parity-final.css`,
`system-parity-lock.css`, `phase2.css`, `phase3.css`, `golden-drop-card.css`, `club-detail-golden.css`,
`parity-*.css`, etc.), plus components named to match (`chat-inbox-parity.tsx`, `profile-parity-route.tsx`,
`golden-drop-card.tsx`, `club-detail-golden.tsx`, `parity-auth-entry.tsx`, `phase3-ui.tsx`).

Target state:

1. One token layer: `web/app/design-system/tokens.css` (CSS custom properties from the tables above) +
   `web/app/design-system/tokens.ts` (typed constants for any JS-side sizing/logic, e.g. breakpoints).
2. One primitives layer: `web/components/design-system/*.tsx` — the components listed above, each a thin,
   composable React component styled from tokens only (CSS Modules or Tailwind-esque utility classes built
   on the tokens; avoid a 26th ad-hoc CSS file).
3. Each screen route consumes primitives + at most one small screen-specific stylesheet for true one-off
   layout (e.g. `home.module.css` limited to grid/layout, not color/type/spacing values already tokenized).
4. Retire legacy files **as their surface migrates**, in the batch order below — do not delete a file
   before its replacement is built, tested and merged; do not leave a retired file merely unreferenced,
   remove it from the repo once nothing imports it (confirm via grep before deletion each time).
5. No new file matching `*-parity*`, `*-golden*`, `*-final*`, `*-closure*`, `*-audit*`, `*-lock*`,
   `phase*` is to be created. If a stopgap is genuinely unavoidable mid-migration, it must be named for
   what it does and removed in the same PR that completes that surface — never left as a permanent layer.

## Migration Batch Order (binding — matches Founder brief exactly)

1. Design tokens / primitives
2. App shell
3. Home
4. Bottom navigation
5. Post cards
6. Profile
7. Post Detail
8. Search
9. Notifications
10. Chat
11. Create Post
12. Clubs
13. Settings
14. Remaining screens (Welcome/Auth, club sub-routes, follow/following lists, public profile slug)

Lint + typecheck + build (`npm run check` in `web/`) after every batch; stop and report on regression
before starting the next batch, per standing WYN-141 precedent.

## Open Questions for Founder (flag, do not guess)

1. Dark mode for Consumer Web: reference is light-only. Ship light-only for now, or is dark mode still
   required (existing `design-principles.md` mandated it from day one)?
2. Desktop navigation: brief says "mobile design is primary... optional side navigation where appropriate"
   — should desktop keep the bottom nav in a centered column (like the reference's own `max-width: 400px`
   card treatment scaled up), or introduce a left sidebar nav at wide viewports? Default assumption
   (documented in the app-shell spec) is: centered column, same bottom nav, no sidebar — reversible if
   Founder prefers a sidebar.
3. Repost/Share/Save icons and verified badge are not in the reference (it only shows Like/Comment/Repost
   counts). AI Design has extended the pattern in the screen specs to cover existing WYN features (5-action
   row, verified badge, media, hashtags) — flagged per-section in `wyn-159-web-v2-app-shell-home-navigation.md`
   for Founder to confirm the extensions read as consistent with the reference.
