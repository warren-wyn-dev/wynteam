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

- `Button`: primary black and outline variants; pill (`999px`) or rounded (`12px`) geometry; 50px default and 44px compact heights.
- `Input`: 44px height, `1px #D0D0D0` border, 10px radius, optional label/hint/error affordances. A bare-control mode supports source-parity DOM composition.
- `Avatar`: circular person avatar; rounded square club avatar; optional 16:9 club banner variant. Root may render as `span` or `div` for source-parity composition.
- `PostCard`: avatar + author/time + text/media slot + Like/Comment/Repost actions.
- `BottomNav`: Home, Clubs, central black circular Post action, Chat, Profile.
- `TopBar`: back action, centered title, right-side action slot.
- `WynosIcon`: semantic mapping to `lucide-react`; stroke icons only, no filled icon treatment. Back uses a chevron matching the supplied HTML references and Camera is available for onboarding.

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
