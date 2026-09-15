# WYNOS Web Base Design System

Status: implementation prepared on a non-production branch
Scope: reusable web primitives only; no existing screen has been migrated to these primitives yet
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
- `Input`: 44px height, `1px #D0D0D0` border, 10px radius, optional label/hint/error affordances.
- `Avatar`: circular person avatar; rounded square club avatar; optional 16:9 club banner variant.
- `PostCard`: avatar + author/time + text/media slot + Like/Comment/Repost actions.
- `BottomNav`: Home, Clubs, central black circular Post action, Chat, Profile.
- `TopBar`: back action, centered title, right-side action slot.
- `WynosIcon`: semantic mapping to `lucide-react`; stroke icons only, no filled icon treatment.

## Implementation notes

- Existing consumer web does not use Tailwind, so this layer uses the project's current CSS approach instead of adding a new styling dependency.
- New semantic variables are prefixed `--wyn-*` and component classes are prefixed `wyn-` to avoid collisions with existing Beta4/parity CSS.
- `web/app/design-system.css` is loaded globally so primitives are ready for adoption without per-page CSS imports.
- No production deployment, route behavior, data flow, Supabase schema, authentication, or existing page composition is changed by this base-component batch.

## Adoption rule

Future page migrations should use these primitives instead of copying their styling. Existing page-specific components should be migrated incrementally and verified per surface; do not perform broad visual rewrites in one step.
