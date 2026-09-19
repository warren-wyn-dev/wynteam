# WYN-176 Batch 1 — Home Chrome (Drawer, Header, Sheets, Retry buttons)

Status: DESIGN — preview ready, waiting on Founder approval before AI Coding
Preview: (published as an Artifact — see chat)

## Correction to batch scope (verified against real code before designing)

Confirmed by re-reading the actual components/CSS, not assumed from the WYN-174/176 plan:

- **Home's post card and bottom nav dock are Flutter-parity-locked** (`home.css`, `bottom-nav.css`'s dock radius/font-size) — WYN-160 batch 3 already audited this in full and found it intentional, with a locked regression test (`pixel-parity-pass-2.spec.ts`). Not touched, per Founder's confirmed scope for this batch.
- **Neither `.wyn-button` (design-system.css) nor `.btn-primary`/`.btn-outline` (auth-reference.css, what WYN-163 actually changed) exist anywhere in Home's code.** Home uses none of the classes WYN-163 touched. There is nothing to "extend" 1:1 from WYN-163 onto Home literally — a third, separate button family (`.route-primary`/`.route-secondary`/`.route-pill`/`.route-more`, `app/phase3.css`) is what Home's non-locked chrome actually uses, shared with Search/Notifications.
- The real non-locked surface in Home is: the side drawer (`home-drawer.tsx` — also shared with Notifications' own drawer, confirmed by its own code comment), the header icon buttons (`home-header.tsx`), the action sheets (share/save/hide/report/redrop rows in `home-screen.tsx`), and the retry/error button (`.route-secondary`).

## What "apply WYN-163's direction" means here (not a literal copy)

WYN-163's two changes were: (1) bigger sizing for full-width primary CTA buttons on Auth screens, and (2) a spring press-feedback (`scale(0.96)`, 160ms cubic-bezier). Forcing Auth's exact `24px/58px` CTA numbers onto a 44px icon button or a 54px list row would break proportion — none of Home's chrome is a full-width primary CTA. The proportional read:

1. **Press feedback is universal** — add WYN-163's exact spring (`scale(0.96)`, 160ms `cubic-bezier(0.34, 1.56, 0.64, 1)`, `prefers-reduced-motion` fallback) to every tappable element in this batch that has none today: drawer close button, drawer identity row, drawer menu rows, header icon buttons, sheet action rows, `.route-secondary`/`.route-pill`/`.route-more`. This is the one thing that's clearly missing everywhere and clearly should be everywhere.
2. **Radius gets a modest, proportional bump**, not Auth's 24px: `.drawer-menu-row` `14px → 16px`, `.drawer-identity` `18px → 20px` — nudging toward the rounder feel without pretending a 54px row is the same shape as a 58px full-bleed button.
3. **Sizing, spacing, and typography stay as-is** — already correctly scaled for their role (a drawer row isn't a CTA), and none of it was found to be stray drift in the WYN-160 batch 3 audit.

## Components

- `.drawer-close .icon-button` (44px circle) — press feedback added, no size/radius change (already a full circle)
- `.drawer-identity` (radius 18→20px) — press feedback added
- `.drawer-menu-row` × 6 (radius 14→16px) — press feedback added
- `home-header.tsx` icon buttons — press feedback added, no size/radius change
- Action sheet rows (`.audit-sheet-row`, `.wyn-redrop-sheet-option`) — press feedback added
- `.route-secondary`/`.route-pill`/`.route-more` (shared with Search/Notifications) — press feedback added; already pill-shaped (999px), no radius change needed

## Interactions

```css
.drawer-menu-row, .drawer-identity, .home-drawer-close .icon-button,
.audit-sheet-row, .wyn-redrop-sheet-option,
.route-primary, .route-secondary, .route-pill, .route-more {
  transition: transform 160ms cubic-bezier(0.34, 1.56, 0.64, 1);
}
.drawer-menu-row:active, .drawer-identity:active:not(:disabled), .home-drawer-close .icon-button:active,
.audit-sheet-row:active, .wyn-redrop-sheet-option:active,
.route-primary:active:not(:disabled), .route-secondary:active:not(:disabled),
.route-pill:active:not(:disabled), .route-more:active:not(:disabled) {
  transform: scale(0.96);
}
@media (prefers-reduced-motion: reduce) {
  /* same selector list */ { transition: none; }
}
```

Same spring curve as WYN-163's approved Auth buttons, so the "feel" of pressing something is consistent whether it's a login button or a drawer row.

## States / Responsive / Accessibility

No new states, no layout/breakpoint change. Touch targets already meet 44px minimum (drawer close is exactly 44px, rows are 54px). `prefers-reduced-motion` handled per above, same pattern as WYN-163/WYN-175.

## Design Rules

1. Do not touch anything the WYN-160 batch 3 audit already confirmed as Flutter-parity-locked (post card, bottom nav dock radius/font-size)
2. Do not apply Auth's literal 24px/58px CTA numbers to non-CTA chrome — proportional radius bump only where noted above
3. Press-feedback spring is the one thing that should be genuinely universal across this batch

## Handoff

→ **AI Coding**: apply the CSS above to `web/app/parity-final.css` (drawer), `web/app/parity-audit.css` (sheet rows), `web/app/home.css` or wherever `home-header.tsx`'s icon buttons are styled, `web/app/phase3.css` (`.route-*` family) — verify each selector's real winning cascade rule first (same discipline as WYN-175's bug), confirm no regression on the Flutter-parity-locked test suite, and confirm the drawer change also renders correctly on Notifications (shared component).
