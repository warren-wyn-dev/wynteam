# Design Spec — WYN-141: Frontend UX/UI System Upgrade

Owner: AI Design → Founder review → AI Coding
Status: DESIGN_COMPLETE / APPROVAL_REQUIRED before Coding
Visual preview: `design-reference/23-ux-ui-system-preview.svg`

## Design Direction

Refine the approved WYNOS language; do not replace it. Use Sapphire as the primary accent, paper/ink surfaces, flat bordered containers, restrained radius, system typography, generous whitespace and subtle motion. No gradients, decorative glass, heavy shadows or new accent colors.

## Responsive Shell

| Width | Layout contract |
|---|---|
| 320–599 | Single column, 12–16px edge inset, bottom navigation, full-width sheets |
| 600–839 | Centered primary rail up to 600px; preserve mobile navigation unless a tested adaptive shell is introduced |
| 840–1199 | Centered primary rail up to 680px; optional contextual rail, never empty decorative space |
| ≥1200 | App shell max-width 1180px; primary content 680px; supporting rail up to 320px |

Content detail and forms use a readable max-width. Media may be wider only where the existing surface intentionally makes media the hero.

## Core Primitives

### Buttons

- Primary: Sapphire fill, white label, 48px recommended height.
- Secondary: paper fill, strong border, ink label.
- Tertiary/icon: no container until hover/focus/press; minimum 44×44 target.
- Destructive: danger color only for the destructive choice, never the whole modal.
- Loading keeps button width stable, disables duplicate submission and retains an accessible label.
- Disabled uses reduced emphasis but must remain legible.

### Inputs

- Persistent label; placeholder is an example, never the only label.
- Input and placeholder text remain at least 16px.
- Help text appears before interaction when useful; error replaces help without shifting unrelated layout excessively.
- Focus ring uses the existing Sapphire token and is visible on keyboard navigation.

### Cards and List Rows

- Prefer flat sections/list rows for social content.
- Use bordered cards only for grouped controls, dashboard metrics or distinct bounded objects.
- Whole-row navigation has one semantic tap target; nested actions must not compete with it.
- Skeleton geometry matches final content to minimize layout shift.

### Modal Surfaces

- Mobile: safe-area-aware bottom sheet for short contextual tasks; pushed screen for long/complex flows.
- Desktop: bounded dialog, max-width 520px, focus trapped, Escape/dismiss behavior explicit.
- Destructive dialogs name the object and consequence; primary focus starts on the safe action.

### Loading, Empty and Error

- Initial loading: skeleton for content surfaces; spinner only for compact indeterminate operations.
- Refresh: retain content and show non-blocking progress.
- Empty: icon/illustration placeholder, one clear explanation, one meaningful CTA at most.
- Error: human-readable cause category, retry action and preserved content when possible.
- Offline: state that connectivity is required and expose retry; never loop silently.

## Surface Contracts

### Auth and Onboarding

One primary action per step, visible progress, keyboard-safe CTA, clear recovery for OAuth/email failures and no dead-end guest entry. Preserve existing auth architecture.

### Navigation and Feed

Preserve five-item navigation and current Home post structure. Improve only adaptive width, state consistency, focus/semantics and verified gesture arbitration between tab swipe, carousel swipe, refresh and back navigation.

### Content Detail and Creation

Keep composer actions reachable above the keyboard, stabilize upload progress, make validation local to the offending control and preserve draft/retry paths.

### Search, Discovery and Notifications

Use stable result/filter hierarchy, retain queries across navigation when currently supported, and give empty/error states a specific recovery action. Notification rows maintain a single clear destination.

### Profile and Settings

Use readable centered rails on wide screens; preserve current profile/feed relationship. Group settings by consequence and visually separate destructive/account actions.

### Clubs and Chat

Preserve existing permissions, membership and message business logic. Standardize list density, unread/online indicators, composer states, moderation actions and responsive modal treatment.

### Admin

Use the same semantic principles with denser desktop spacing: persistent sidebar, clear page hierarchy, responsive tables/list fallback, visible filters, deterministic bulk/destructive actions and strong keyboard focus.

## Accessibility Acceptance

- 44px absolute minimum target; 48px recommended.
- No clipping/overflow at 320px or text scale 2.0.
- Meaning is not conveyed by color alone.
- Keyboard focus is visible and follows reading order.
- Icon-only actions have semantic/accessible names.
- Motion uses existing tokens and respects reduced-motion capability where supported.

## Implementation Batches and Gates

Each batch requires: targeted tests → full relevant lint/test → production build where credentials/toolchain permit → regression report. Stop before the next batch on any failure.

1. Tokens/primitives/tests.
2. Auth/navigation shell.
3. Feed/content.
4. Search/notifications/profile/settings.
5. Clubs/chat.
6. Admin.
7. Full responsive/accessibility QA.

No production UI code may start until Founder approves the visual preview. Any approved implementation remains behind developer-account staged rollout when it changes user-visible behavior rather than fixing an existing accessibility/layout defect.
