# UX/UI Audit — WYN-141

Date: 2026-09-08
Scope: Flutter consumer frontend (`app/`) and Next.js Admin (`admin/`); static repository audit before visual implementation.

## Executive Summary

WYNOS already has a coherent approved foundation: Sapphire colors, a 4px spacing scale, 44/48px touch targets, a complete typography scale and shared motion/haptic helpers. The work should not introduce a new visual direction. The highest-value gap is consistent application across states and responsive widths.

## Evidence Snapshot

| Signal | Current repository evidence | Implication |
|---|---:|---|
| Flutter presentation files | 150 across 21 feature areas | Roll out in batches, never a single sweeping refactor |
| `CircularProgressIndicator` files | 88 | Loading presentation is distributed and needs cataloguing/consolidation |
| `showDialog` files | 20 | Dialog behavior needs a shared responsive/accessibility contract |
| `showModalBottomSheet` files | 32 | Bottom sheets need consistent safe-area, keyboard and desktop behavior |
| `EmptyStateBlock` files | 9 | Shared empty-state primitive exists but adoption is incomplete |
| hardcoded `Color(0x...)` files | 3 | Color token adoption is strong; audit remaining exceptions rather than redesign palette |
| hardcoded numeric `EdgeInsets` files | 17 | Review intent; DS-008 explicitly allows justified micro-spacing exceptions |
| viewport/text-scale test files found | 4 | Responsive/accessibility regression coverage is materially thinner than feature coverage |

Counts are static search signals, not automatic defects. Every occurrence must be inspected in context before replacement.

## Strengths to Preserve

- `WynSpacing`: approved 4px rhythm, radius roles and minimum/recommended touch targets.
- `WynTypography`: semantic hierarchy for page titles, section titles, body, inputs, buttons, navigation and metadata.
- `WynTheme`: flat cards, controlled borders and exact brand colors rather than generated Material tones.
- `WynMotion`, `WynPressScale`, `WynStatePop`, `WynFeedback`: subtle interaction feedback already standardized.
- WYN-140 Home feed polish and WYN-106/107 action/card decisions.

## Gaps by User Impact

### P1 — Accessibility and resilient layout

- Expand automated coverage for 320px plus text scaling up to 2.0.
- Audit semantic labels, focus order, keyboard traversal, visible focus and contrast for all actionable states.
- Prevent fixed-height containers from clipping translated Thai copy, validation errors or keyboard-resized content.

### P1 — Responsive web/tablet behavior

- Introduce centered content rails rather than stretching mobile layouts edge-to-edge.
- Keep mobile single-column behavior; use max-width and optional supporting rail only where content warrants it.
- Present bottom sheets as bounded centered dialogs on large screens when the task is modal rather than navigational.

### P1 — Async state consistency

- Define full-screen loading, inline loading, pagination loading, empty, recoverable error, offline and permission-denied patterns.
- Preserve usable stale content during refresh/error where repository behavior already supports it.
- Never replace a meaningful action label with an unlabeled spinner.

### P2 — Form and modal consistency

- Standardize label/help/error spacing, 16px minimum input text, keyboard-safe actions and destructive confirmations.
- Standardize dialog widths, button order, dismiss rules, focus trapping and safe areas.

### P2 — Information architecture and copy

- Audit route entry points, back behavior, deep links and overflow menus without changing feature ownership.
- Normalize Thai labels for the same action; errors must explain the recovery action rather than expose implementation terms.

## Surface Rollout Order

1. Shared primitives and regression harness.
2. Auth/onboarding.
3. Navigation and Home/feed.
4. Content detail and creation.
5. Search/discovery and notifications.
6. Profile/settings.
7. Clubs.
8. Chat.
9. Admin.
10. Cross-surface accessibility/responsive regression pass.

Every batch stops if lint, tests or build fail. No unrelated backend refactor is permitted.
