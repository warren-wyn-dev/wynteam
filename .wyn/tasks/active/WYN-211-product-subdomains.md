# Product Task — WYN-211 — WYNOS product subdomains

Status: active — Founder requested production routing on 2026-10-04.

## Scope

Route the existing WYNOS web surfaces through dedicated production subdomains without changing their existing feature logic:

- `wynos.online` → Social main app (existing root behavior).
- `food.wynos.online` → WYNOS Food customer ordering surface (`/food`).
- `merchant.wynos.online` → WYNOS Merchant restaurant surface (`/merchant`).
- `maps.wynos.online` → WYNOS Maps surface (`/maps`).
- Keep `tiles.wynos.online` unchanged for the existing map tile gateway.

## Implementation

Use host-aware root rewrites in the existing Next.js app so the three new subdomains land on the already-shipped route implementations. Keep existing prefixed routes working to avoid breaking links, auth flows, assets, and bookmarks.

## Acceptance Criteria

- `wynos.online/` continues to render the Social main app.
- `food.wynos.online/` renders the existing WYNOS Food route.
- `merchant.wynos.online/` renders the existing WYNOS Merchant route.
- `maps.wynos.online/` renders the existing WYNOS Maps route.
- Existing `/food`, `/merchant`, `/maps`, and `tiles.wynos.online` behavior remains available.
- Build/CI passes before production.
- Production domains are verified in Vercel after release.

## Rollback

Remove the three host-aware rewrites and detach the three new project domains. Existing `wynos.online` and `tiles.wynos.online` remain untouched.


## Deployment retry

- 2026-10-04: no-op task update to trigger the production pipeline after the proxy fix was merged to main.
