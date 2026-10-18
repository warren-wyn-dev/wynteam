# Bug Report — ZOKY-135

Status: bugs
Severity: HIGH (release blocker for the ZOKY domain cutover; known, carried from handoff)
Owner: AI Debug Engineer (edge function change requires QA Security + Founder approval + deploy)
Found by: AI QA & Security, branch `feat/zoky-web-rebrand` @ ffd3ac6, 2026-10-18

Bug:
Supabase edge functions still hardcode `https://food.wynos.online` as the only trusted Food origin.
After the web deploy, Food runs on `https://zoky.wynos.online` (food.wynos.online only redirects), so:
- `supabase/functions/food-stripe-checkout/index.ts:69` — live mode rejects `Origin: https://zoky.wynos.online` with 403 `live_stripe_origin_required` → card payment impossible on ZOKY.
- `supabase/functions/food-stripe-cancel/index.ts:71` — same check → cancelling a card-paid order from ZOKY returns 403.
- `supabase/functions/wynos-maps-geocode/index.ts:22-30` (`ALLOWED_ORIGINS`, line 26) — geocode fallback from ZOKY returns 403.
- `supabase/functions/food-stripe-checkout/index.ts:152-153` — success/cancel URLs point to food.wynos.online (works via 307, should move to zoky); `:155` product name `WYNOS Food #…` (Q10, branding only).

Reproduction:
1. Deploy web @ ffd3ac6 with zoky.wynos.online attached, Stripe live mode.
2. On https://zoky.wynos.online place an order and choose card payment.
3. Edge function compares `Origin` to `https://food.wynos.online` → 403.
(Code-level verification only: `grep -rn food.wynos.online supabase/functions`. Not executed against any real project.)

Root Cause:
Origin allowlists not updated for the new canonical Food origin (web change deliberately excluded edge functions).

Fix:
Accept an explicit allowlist `{https://zoky.wynos.online, https://food.wynos.online}` (exact string match, no suffix/regex matching, keep deny-by-default) in all three functions; move success/cancel URLs to zoky. Keep food.wynos.online accepted during transition/rollback. Deploy before or together with the web release.

Files Changed: (to do) supabase/functions/food-stripe-checkout/index.ts, food-stripe-cancel/index.ts, wynos-maps-geocode/index.ts
Tests: add unit tests for origin allowlist (zoky accepted, food accepted, `https://zoky.wynos.online.evil.com`, `https://evil.com`, `null`, missing Origin rejected in live mode).
Regression Risk: Medium — payment path; security-sensitive (Founder approval required).
Handoff to QA: re-test origin allowlist + Stripe test-mode success/cancel on staging.
