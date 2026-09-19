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

## Button Interaction Spec (added 2026-09-19 — WYN-160/WYN-175)

Founder asked for every button across the web app to move in one consistent direction. Codebase audit
(`web/app/*.css`, all 44 stylesheets imported by `app/layout.tsx`) found ~72 button-related class
selectors, only 5 files with any `:active` state, only 3 files using the press-motion token introduced in
WYN-169/170, and at least 6 different hardcoded danger-red values (`#b42318`, `#dc2626`, `#b12d25`,
`#d33c32`, plus the approved accent `#E0203D`) across different screens. This section is the missing
interaction contract — not a new visual direction, an enforcement spec for the existing Button primitive
above.

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

### Danger / destructive variant

One token only: `color: var(--wyn-accent)` (or `background: var(--wyn-accent)` for a filled danger
button). No screen may declare its own danger red. The 6 hardcoded values found in the audit above are the
migration list for the rollout phases below — each gets swapped to the token, not redesigned.

### Touch target

- **Primary action** (the button a user taps to complete the screen's main task, or any destructive
  action like delete/remove/block): **minimum 44px hit area**, matching DS-008. This applies to the *hit
  area*, not necessarily the visible size — a small icon can sit inside a larger invisible padding box,
  same pattern as the Flutter `ActionMetric` reference in WYN-106.
- **Secondary text-link action** (a lower-emphasis action that sits next to a primary one and is not the
  main reason the user is on the screen — e.g. "ลบรูปโปรไฟล์" next to the avatar upload control in
  WYN-174): may stay below 44px if it is genuinely optional/secondary and not the only way to complete a
  required task. When in doubt, treat it as primary and give it 44px.
- Audit finding: `.route-primary`/`.route-secondary`/`.route-pill`/`.route-more`
  (`web/app/phase3.css:83-114`, used across 13 component files) currently ships at **38px** default /
  **32px** on `.small` — both under the 44px floor, and both are primary-action buttons (form submit,
  confirm, follow, etc.), not secondary text-links. This corrects the earlier WYN-160 consolidation
  doc's touch-target line ("สม่ำเสมอดี — ไม่ต้องแก้") — that pass evidently checked a different subset of
  controls; `route-primary`/`route-secondary` need to move into scope for the touch-target rollout.

### Button category map

Mirrors the grouping method used for the Flutter Home button system (WYN-106) — every button on web maps
to one of these categories; do not invent a 7th without a Founder-reviewed reason:

| Category | Real example (web) | Shape | Fill | When to use |
|---|---|---|---|---|
| Primary Pill/Rounded | `.route-primary` | pill `999px` or rounded `12px` | solid `--wyn-text` bg, `--wyn-bg` text | The single most important action on a screen |
| Secondary Outline | `.route-secondary` | same geometry as Primary | `1px --wyn-border` border, `--wyn-bg` fill | A lower-emphasis alternative next to a Primary (cancel, follow-back) |
| Icon Button | `.route-icon-button`, `.wyn-chat-note-plus` | circle or square, `--wyn-radius-control` (10px) or `50%` | transparent or filled per context | Navigation, compose triggers, non-CTA actions |
| Tab / Toggle | `.wyn-chat-requests-link` (`is-active` modifier) | pill `999px` | transparent default, `--wyn-surface` when active | Switching between two or more views on the same screen |
| Text-link secondary action | `.wyn-note-delete`, `.wyn-profile-edit-avatar-remove` | no border/background, text-only | `--wyn-accent` for danger, `--wyn-text` for neutral | A secondary action that doesn't need visual weight (delete, remove) |
| Dismiss Icon | close/X buttons on modals and sheets | icon only | transparent | Closing an overlay — must have real 44px hit area even though the icon itself is small |

### Rollout note

This spec is written and needs Founder approval before any code changes — see WYN-160's handoff for the
phased rollout order this attaches to.

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
