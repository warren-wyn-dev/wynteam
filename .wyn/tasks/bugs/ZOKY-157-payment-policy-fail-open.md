# Bug Report — ZOKY-157

Status: fixed, waiting for QA re-test (AI QA & Security). Nothing pushed or deployed.
Owner: AI Debug Engineer
Severity: HIGH (ZOKY full-system QA 2026-10-24, finding H1). Report: `.wyn/tasks/qa/ZOKY-full-system-qa-2026-10-24.md`.

## Bug
The Stripe-only payment policy failed open, in two places:
- Customer web: the policy was read once per session. Any error made it fall back to legacy, so customers saw the store's own PromptPay QR and the "แนบสลิปการโอน" button.
- Backend: `food-payment-qr` and `food-verify-slip` never checked the policy. Even with the policy on, a direct API call returned the store's QR.

## Reproduction (synthetic, mocked Supabase, no real data)
- QA Playwright S4: one 500 from `rpc/food_payment_policy_public` on `?order=WF0001` showed the store QR, the PromptPay ID, the slip button, and called `food-payment-qr`.
- Debug probe `/tmp/claude-0/-home-user-wynteam/a4bef52b-31cd-5461-ba0f-50621a25ded3/scratchpad/h1probe/probe-h1.mjs` (Next dev, mock `sb-mock.test`):
  - Before the fix, with the policy RPC always returning 500, the slip upload was shown (FAIL).
  - After the fix, all 22 checks pass.
  - Note: in dev, React StrictMode runs the effect twice. A single 500 is therefore hidden in dev, but it reproduces in a production build (as QA ran it).

## Root cause
- `web/lib/food-payment-policy.ts` `fetchFoodPaymentPolicy` returned `false` (legacy) for every error. It made no distinction between PGRST202 (migration not applied) and transient errors (5xx, timeout, offline).
- `web/components/food/wynos-food-developer-app.tsx` cached that result for the session and never read the policy again.
- The edge functions on main had no policy check at all. Only the DB triggers stopped the slip, and they act after the customer has already paid the store.

## Fix
Web, branch `feat/zoky-stripe-only-web`:
- New `fetchFoodPaymentPolicyState` returns one of three states:
  - `stripe_only`.
  - `legacy`: false/NULL, unexpected shape, PGRST202, or 42883.
  - `unavailable`: any other error or a thrown exception.
- `foodPaymentGateForPolicy`: `unavailable` gives `stripeOnly: true` plus `unavailable: true`. The result is fail closed:
  - no store QR, bank rows or slip upload;
  - `food-payment-qr` is not called;
  - only "จ่ายด้วยพร้อมเพย์ (QR)" through Stripe is offered.
- When the policy is `unavailable`, the order page shows "ระบบชำระเงินขัดข้องชั่วคราว ตอนนี้ชำระได้เฉพาะพร้อมเพย์ผ่าน Stripe" with a "ลองใหม่" button. Opening an order (the order view) reads the policy again. Only the latest read is applied.
- Merchant web keeps using the boolean `fetchFoodPaymentPolicy`, which is now true only for a confirmed `stripe_only`. Its behaviour is unchanged.
- The guest flow (`food-guest-browse.tsx`) has no payment UI and does not read the policy, so it needs no change.

Backend, `main`, branch `fix/zoky-slip-qr-policy-gate`:
- `storePaymentPolicyRefusal` in `supabase/functions/food-payment-qr/_lib.ts`:
  - policy on: 409 `stripe_only_payments`;
  - PGRST202/42883 or policy off/NULL: null (legacy);
  - any other error: 503 `payment_policy_unavailable`.
- `food-payment-qr` and `food-verify-slip` call it after the ownership check. That is before they read the store's PromptPay, download the slip, call SlipOK, or record a verification.
- The DB triggers that reject slips under the policy are unchanged.

## Files changed
- Web: `web/lib/food-payment-policy.ts`, `web/lib/food-customer.ts`, `web/components/food/wynos-food-developer-app.tsx`, `web/lib/i18n/en.ts`, `web/tests/food-stripe-only.test.mjs`
- Backend: `supabase/functions/food-payment-qr/{_lib.ts,_lib.test.ts,index.ts,index.test.ts}`, `supabase/functions/food-verify-slip/{index.ts,index.test.ts}`

## Tests
- Web:
  - `node --test tests/*.test.mjs`: 368/368 pass.
  - `tsc --noEmit`: OK.
  - `eslint .`: 0 errors. The 17 warnings were already there before this fix.
  - Playwright probe: 22/22 checks pass. It covers a 500 once, a 500 always, the RPC missing, and the policy off. In the last two cases the legacy flow still works and `food-payment-qr` is still called.
- Backend:
  - `deno check index.ts` and `deno test --allow-read=.` (the same steps as deploy-edge-functions.yml), run for both functions: pass.
  - `deno test --allow-read supabase/functions/`: 157/157 pass.

## Regression risk / residual
- While the policy RPC is failing, a store that is legacy and has no Stripe account will show a PromptPay button that fails at checkout. This is the intended fail-closed behaviour. A retry recovers once the RPC answers.
- Merchant web still treats an unreadable policy as legacy (setup checklist, manual paid buttons). The server and the DB still enforce the policy.
- `food-payment-qr` and `food-verify-slip` are not in the `deploy-edge-functions.yml` choice list, so this fix cannot be shipped through that workflow as it is. Adding them needs a DevOps decision (check the live verify_jwt first) and Founder production approval.
- The deno tests for the gate's position in `index.ts` are source-level tests. The handler is not run end to end against Supabase.

## Handoff to QA
Re-run the QA S4 scenario on a production build, plus a direct API call to `food-payment-qr` / `food-verify-slip` with the policy on, off, missing, and erroring.
