import assert from "node:assert/strict";

const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));

Deno.test("new connected accounts are Accounts v2 only", () => {
  assert.match(source, /POST|method: "POST"/);
  assert.match(source, /https:\/\/api\.stripe\.com\/v2\/core\/accounts/);
  assert.match(source, /fees_collector: "stripe"/);
  assert.match(source, /losses_collector: "stripe"/);
  assert.match(source, /dashboard: "none"/);
  assert.doesNotMatch(source, /fetch\("https:\/\/api\.stripe\.com\/v1\/accounts"\s*,\s*\{\s*method:\s*"POST"/s);
});

Deno.test("provisioning is protected against duplicate connected accounts", () => {
  assert.match(source, /food_claim_stripe_account_creation/);
  assert.match(source, /wynos-connect-v2-/);
  assert.match(source, /Idempotency-Key/);
  assert.match(source, /eq\("store_id", storeId\)/);
});

Deno.test("embedded onboarding keeps Stripe authentication enabled", () => {
  assert.match(source, /\/v1\/account_sessions/);
  assert.match(source, /components\[account_onboarding\]\[enabled\]/);
  assert.match(source, /external_account_collection/);
  assert.doesNotMatch(source, /disable_stripe_user_authentication/);
});

Deno.test("readiness requires automatic payout setup and sanitized bank state", () => {
  assert.match(source, /automaticPayouts/);
  assert.match(source, /bank_ready/);
  assert.match(source, /bank_last4/);
  assert.match(source, /requirements_due_count/);
  assert.match(source, /stripe_payments_enabled: state\.status === "ready"/);
  assert.doesNotMatch(source, /bank_account_number/);
});
