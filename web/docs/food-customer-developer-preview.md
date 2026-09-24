# WYNOS Food customer UI — developer preview

Approved visual reference: 10-screen red-and-white customer UI collage (Founder, 2026-09-25).
The WYNOS Social app at wynos.online remains the entry point. This iteration
implements a clickable customer-side design prototype for multiple restaurants.

## Scope
- Food home, address picker, search/filter, multi-restaurant discovery
- Restaurant details, menu list/search, rating/info tabs, restaurant favorites
- Menu customization (spice/extras/note/quantity)
- Cart grouped by merchant; delivery and sample discount totals
- Checkout with mock-only payment choices, sample DEMO20 coupon
- In-memory sample order creation and status simulation (no API calls)
- Example order history/reordering, reviews, Food profile and Food bottom navigation
- Food Chat button leads to WYNOS Social's existing /chat; primary WYNOS
  Social five-tab navigation is not modified.

## Visibility and safety
The /food route mounts DeveloperRouteGate (authentication) and independently checks
is_developer_account() against the current Supabase session. UI remains
hidden until an explicit positive RPC result; denied/error -> redirect /.
The WYNOS Home Food shortcut continues to use its existing developer-only gate.

All Food records, prices, restaurant names, photos, addresses, reviews and
delivery status are demonstration data. Client-side state resets on reload.
No real ordering, payments, merchant API, dispatch, GPS tracking, refunds,
reviews backend or financial transactions are connected. External Unsplash
photo URLs are placeholders; replace with merchant-owned/licensed assets prior
to any public release. Do not deploy a backend endpoint merely because this
UI exists.

## QA
Development-only /dev/food-fixture renders the same customer UI without a
backend, for automated browser QA. It redirects to / on production builds.
tests/browser/wynos-food-customer-demo.spec.ts covers developer gating as
source audit plus multi-screen user interactions in the browser.

The developer preview is a UI deliverable, not a public marketplace launch.
Before enabling for ordinary accounts, design and separately authorize a
multi-merchant database schema, merchant access control (RLS), order ownership,
payment provider integration, fraud/abuse controls, service availability and
delivery operations. No version bump or rollback is authorized by this UI work.
