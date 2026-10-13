# WYNOS Food Android — verified source contracts for Step 2

## Source of truth

- `web/components/food/food-guest-browse.tsx` uses `client.rpc("food_public_catalog")`.
- `supabase/migrations/20261010120000_food_public_guest_catalog.sql` defines
  public read-only JSONB result of at most 60 published, unsuspended stores
  including up to 100 available menu entries each (behind the rollout gate).
- `web/lib/food-customer.ts` provides authenticated orders / address and
  server RPC contracts; **none of those are called in Step 2**.
- `android/app/src/main/java/io/wyn/wyn/core/data/SupabaseAuthRepository.kt`
  shows the existing WYNOS Supabase email-login and reset flow.
- `web/lib/supabase/browser.ts` uses public browser Supabase config.

## Android implementation

- `data/FoodCatalog.kt`: defensive mapping from the public JSONB RPC to
  native UI models. Menu prices are display-only strings, not checkout quotes.
- `data/SupabaseFoodGateway.kt`: shared Supabase backend client with Auth
  and Postgrest modules, email login/logout/reset, public catalog read only.
- `ui/FoodViewModel.kt`: loading, error, signed-in and empty-state handling.
- `ui/FoodApp.kt`: native Material 3 UI and disabled checkout.

## Never do this

- No direct anonymous table queries to `food_stores`, `food_menu_items`,
  `food_orders`, customer addresses, merchant finance, or private storage.
- No use of any service-role or secret key in a mobile client.
- No spoofing browser Origin to bypass Stripe's live checkout restriction.
- No production schema/edge-function/deployment changes without approval.

## Planned next milestone

- Verify Supabase project/public keys in developer environment.
- Verify login and guest catalog with a test account/device.
- Add authenticated order history and customer address flows only once
  current RLS and RPC contracts have passed security review.
- Design native-safe payment initiation separately; no unreviewed live Stripe.
