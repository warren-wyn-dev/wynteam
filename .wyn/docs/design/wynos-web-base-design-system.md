# WYNOS Web Base Design System

Status: implementation prepared on a non-production branch
Scope: reusable web primitives plus the Founder-supplied six-screen auth reference flow
Target: `web/` (Next.js 16 + React 19 + TypeScript + existing CSS architecture)

## Founder direction — 2026-09-15

### Color tokens

- Background: `#FFFFFF`
- Surface/card: `#FAFAFA`
- Primary text: `#0A0A0A`
- Secondary text: `#6B6B6B`
- Muted text: `#9A9A9A`
- Border: `#E7E7E7`
- Strong border: `#D0D0D0`
- Accent: `#E0203D`

Accent red is reserved for like state, attached-media/status emphasis, and warning/error states. It is not a general decorative color.

## Base primitives

- `Button`: primary black and outline variants; pill (`999px`) or rounded (`12px`) geometry; 50px default and 44px compact heights. See "Button Interaction Spec" below for the full interaction contract (motion, danger variant, touch target, category map) — added 2026-09-19 as part of WYN-160.
- `Input`: 44px height, `1px #D0D0D0` border, 10px radius, optional label/hint/error affordances. A bare-control mode supports source-parity DOM composition.
- `Avatar`: circular person avatar; rounded square club avatar; optional 16:9 club banner variant. Root may render as `span` or `div` for source-parity composition.
- `PostCard`: avatar + author/time + text/media slot + Like/Comment/Repost actions.
- `BottomNav`: Home, Clubs, central black circular Post action, Chat, Profile.
- `TopBar`: back action, centered title, right-side action slot.
- `WynosIcon`: semantic mapping to `lucide-react`; stroke icons only, no filled icon treatment. Back uses a chevron matching the supplied HTML references and Camera is available for onboarding.

## Button Interaction Spec (added 2026-09-19 — WYN-160/WYN-177, reconciled with WYN-176)

Founder asked for every button across the web app to move in one consistent direction. Codebase audit
(`web/app/*.css`, all 44 stylesheets imported by `app/layout.tsx`) found ~72 button-related class
selectors, only 5 files with any `:active` state, only 3 files using the press-motion token introduced in
WYN-169/170, and at least 6 different hardcoded danger-red values (`#b42318`, `#dc2626`, `#b12d25`,
`#d33c32`, plus the approved accent `#E0203D`) across different screens. This section is the missing
interaction contract — not a new visual direction, an enforcement spec for the existing Button primitive
above.

**Reconciled 2026-09-19 with WYN-176** (a parallel workstream that reached Founder approval and shipped its
first batch before this spec's sizing numbers were checked against it): WYN-163's Auth redesign picked
*bigger* button/input/headline values than this doc originally assumed, and Founder confirmed those values
— not WYN-160's original smaller pill/12px numbers — are now the system-wide target:

- **Button**: `24px` radius, `58px` height, `16px/700` text (replaces the pill-`999px`/rounded-`12px`
  geometry this section originally specified)
- **Input**: `18px` radius, `56px` height (replaces the Base primitives section's `10px`/`44px` line above
  for any surface WYN-176 rolls out to — that original Input line still describes what's live today on
  unmigrated screens)
- **Screen headline**: `32px/800`
- **Press feedback**: `scale(0.96)`, `160ms cubic-bezier(0.34, 1.56, 0.64, 1)` — **matches this spec's
  Motion token below exactly**, so nothing here changes; WYN-176 batch 1 already shipped this exact
  formula (hardcoded per-selector rather than via the shared tokens below) to `.drawer-identity`,
  `.drawer-menu-row`, `.home-drawer-close .icon-button`, `.audit-sheet-row`, and
  `.route-primary`/`.route-secondary`/`.route-pill`/`.route-more`

The Motion token, Danger variant, and Touch target sections below remain the enforcement spec; the
Button category map's geometry column is updated to the values above. Rollout now continues under
**WYN-176** (`.wyn/tasks/active/WYN-176-visual-design-rollout-squircle.md`), not WYN-160 — see that task's
batch sequence instead of the Rollout note below.

### Motion token (mandatory on every tappable button)

Proven in production across WYN-169/170/171 — reuse verbatim, do not invent a new curve:

```css
.wyn-btn-name {
  transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
.wyn-btn-name:active {
  transform: scale(0.96);
}
@media (prefers-reduced-motion: reduce) {
  .wyn-btn-name {
    transition: none;
  }
}
```

Every button category below gets this triplet. No exceptions — even icon-only and text-link buttons need
press feedback; only the `:active` scale value (0.96) may need a smaller number for very small icon
buttons if 0.96 reads as imperceptible, but the base formula does not change without a Founder-reviewed
reason recorded in the CSS as a comment.

**Compose, don't overwrite, an element's own static transform.** A few controls already carry a
non-press `transform` for layout (e.g. `.wyn-bottom-nav__post { transform: translateY(-9px) }` for the
central Post button's lift). Applying `:active { transform: scale(0.96) }` verbatim on such an element
replaces its base transform instead of combining with it — the Post button would visibly drop 9px on
every press. For any control that already sets a static `transform`, either apply the press-scale to an
inner wrapper element instead of the element carrying the static transform, or write the combined value
explicitly (`transform: translateY(-9px) scale(0.96)`) in that control's own `:active` rule — never rely
on the generic triplet verbatim when a static transform is already present.

### Danger / destructive variant

One token only: `color: var(--wyn-accent)` (or `background: var(--wyn-accent)` for a filled danger
button). No screen may declare its own danger red. The 6 hardcoded values found in the audit above are the
migration list for the rollout phases below — each gets swapped to the token, not redesigned.

**Known gap, not yet resolved**: `var(--wyn-accent)` (`#e0203d`) is intentionally fixed across themes
(see `design-system.css`'s comment, "stays fixed across themes, same treatment as sapphire/like
elsewhere"). Measured as text-on-background contrast: **4.73:1 on light** (`--wyn-bg: #ffffff`) passes
WCAG AA, but only **4.44:1 on dark** (`--wyn-bg: #000000`) — just under the 4.5:1 AA floor (confirmed by
QA on the WYN-174 PR). Migrating every hardcoded danger red to this one token, as directed above, spreads
that same marginal dark-mode shortfall to every danger button the rollout touches — which would violate
this spec's own acceptance criterion ("ทุกปุ่มที่แก้ต้องผ่าน WCAG AA ทั้ง light/dark"). This needs a
Founder decision before the danger-token migration reaches any dark-mode-visible screen: either accept
the existing token's dark-mode contrast as a documented, Founder-approved risk (matching the AGENTS.md
policy for a HIGH-severity finding), or introduce a dark-mode-specific override for text-on-background
danger use that clears AA, kept separate from `--wyn-accent`'s existing fixed-across-themes role
elsewhere (like/error backgrounds, borders) so that role isn't disturbed. Not resolved in this
phase-0 spec pass — flag it to Founder before rollout reaches this token.

### Touch target

- **Any tappable action, including destructive text-links** (delete/remove/block — e.g.
  `.wyn-note-delete`, "ลบรูปโปรไฟล์" in WYN-174): **minimum 44px hit area**, matching DS-008. This applies
  to the *hit area*, not the visible size — a small icon or small text-only control can sit inside a
  larger invisible padding box, same pattern as the Flutter `ActionMetric` reference in WYN-106 and the
  Dismiss Icon category below. A destructive action never gets a pass on hit area just because it's
  styled as a text-link; only its *visual weight* (no border/background) differs from a Primary button.
- **Genuinely optional secondary text-link** (does not complete a required task, and isn't
  delete/remove/block — e.g. "ดูเพิ่มเติม"): still target 44px hit area where practical; a smaller hit
  area is acceptable only when the control sits inline in a text flow where a large hit box would
  overlap neighboring tap targets. When in doubt, give it 44px.
- Audit finding: `.route-primary`/`.route-secondary`/`.route-pill`/`.route-more`
  (`web/app/phase3.css:83-114`, used across 13 component files) currently ships at **38px** default /
  **32px** on `.small` — both under the 44px floor. This corrects the earlier WYN-160 consolidation
  doc's touch-target line ("สม่ำเสมอดี — ไม่ต้องแก้") — that pass evidently checked a different subset of
  controls; `route-primary`/`route-secondary` need to move into scope for the touch-target rollout.
- Audit finding: `.wyn-note-delete` (`web/app/chat-notes.css:469`) ships at 36px min-height, and the
  WYN-174 "ลบรูปโปรไฟล์" button has no explicit min-height at all — both need a 44px hit area added in
  their rollout phase (visual size/styling stays the same, only the invisible hit box grows).

### Button category map

Mirrors the grouping method used for the Flutter Home button system (WYN-106) — every button on web maps
to one of these categories; do not invent a 7th without a Founder-reviewed reason:

| Category | Real example (web) | Shape | Fill | When to use |
|---|---|---|---|---|
| Primary | `.route-primary` | `24px` radius, `58px` height (WYN-163/176 target — see reconciliation note above) | solid `--wyn-text` bg, `--wyn-bg` text | The single most important action on a screen |
| Secondary Outline | `.route-secondary` | same geometry as Primary | `1px --wyn-border` border, `--wyn-bg` fill | A lower-emphasis alternative next to a Primary (cancel, follow-back) |
| Icon Button | `.route-icon-button`, `.wyn-chat-note-plus` | circle or square, `--wyn-radius-control` (10px) or `50%` | transparent or filled per context | Navigation, compose triggers, non-CTA actions |
| Tab / Toggle | `.wyn-chat-requests-link` (`is-active` modifier) | pill `999px` | transparent default, `--wyn-surface` when active | Switching between two or more views on the same screen |
| Destructive text-link | `.wyn-note-delete`, `.wyn-profile-edit-avatar-remove` | no border/background, text-only, but 44px hit area (see Touch target above) | `--wyn-accent` | Delete/remove — low visual weight but still a required 44px target since it's destructive |
| Dismiss Icon | close/X buttons on modals and sheets | icon only | transparent | Closing an overlay — must have real 44px hit area even though the icon itself is small |

Icon Button and Tab/Toggle keep their existing smaller geometry (`--wyn-radius-control`/pill) — WYN-163/176
only redefined Primary/Secondary buttons and Input, not every control category; confirm with Founder
before widening the bigger-squircle treatment to icon buttons or tabs.

### Rollout note

This spec's motion/danger/touch-target rules are enforcement guidance; the phased rollout itself now
continues under **WYN-176** (`.wyn/tasks/active/WYN-176-visual-design-rollout-squircle.md`), which has its
own batch sequence and has already shipped batch 1 (Home/Bottom Nav). WYN-160's original 8-phase plan is
superseded — see that task file's status line.

## Six-screen auth reference flow

The supplied HTML screens are converted to React components in `web/components/auth-flow/screens.tsx`. Source geometry, spacing, colors and element hierarchy are preserved through the scoped `web/app/auth-reference.css` layer while shared controls come from the base design system.

Routes:

- `/welcome`
- `/signup/step-1`
- `/signup/step-2`
- `/onboarding/profile`
- `/login`
- `/forgot-password`

The hidden App Router group `(auth-flow)` owns a shared `SignupDraftProvider`. Signup step 1 and step 2 therefore share one in-memory draft while the user moves forward/back within the flow. Password values are not written to `localStorage` or `sessionStorage`.

`web/tests/browser/auth-reference-flow.spec.ts` covers all six routes, source geometry for the phone/topbar/button/input, route wiring, and signup state retention after using the in-flow back button.

## Implementation notes

- Existing consumer web does not use Tailwind, so this layer uses the project's current CSS approach instead of adding a new styling dependency.
- New semantic variables remain prefixed `--wyn-*`; the auth-reference CSS is scoped under `.auth-ref-viewport` to avoid collisions with Beta4/parity surfaces.
- No production deployment, Supabase schema, authentication backend, or existing home/feed/profile behavior is changed by this batch.

## Adoption rule

Future page migrations should use these primitives instead of copying their styling. Existing page-specific components should be migrated incrementally and verified per surface; do not perform broad visual rewrites in one step.
