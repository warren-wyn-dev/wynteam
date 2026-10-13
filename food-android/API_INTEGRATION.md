# Integration handoff — WYNOS Food Android

Step 1 is an **offline Native Android foundation**. Step 2 must be designed
against these existing, versioned repository contracts, not guessed endpoints.

## Grounded web/backend source

- `web/app/food/page.tsx`: WYNOS Food entry screen.
- `web/components/food/wynos-food-developer-app.tsx`: web customer flow.
- `web/lib/food-customer.ts`: customer domain types and operations.
- `web/lib/supabase/browser.ts`: browser-side Supabase publishable client.
- `supabase/functions/food-stripe-checkout/index.ts`: Stripe checkout edge function.

## Already used by Web Food

- `food_store_directory`: restaurant listing RPC.
- `food_quote_order` / `food_quote_order_v2`: server quote.
- `food_create_order` / `food_create_order_v2`: server order creation.
- `food_delivery_availability`: delivery feasibility.
- `food-stripe-checkout`: payment function.

Names above are observational only. Before implementation verify current RPC
signatures, auth/session behavior, RLS policies, failure handling,
idempotency, and production deployment/version parity.

## Payment blocker requiring backend work

The existing `food-stripe-checkout` code enforces
`origin == https://food.wynos.online` in Stripe live mode. Native clients
must **not** spoof a browser Origin header. Design a secure native-capable
server authorization path, preserving order ownership, payment state
and idempotency, then test in Stripe test mode and review it before rollout.

## Next milestone

Connect real catalog read-only to Supabase, then WYNOS Account sign-in, secure
server-side quote/order flows, payment and notification integration. No
production network configuration or secrets are included in Step 1.
