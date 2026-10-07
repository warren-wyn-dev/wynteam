import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const root = new URL("..", import.meta.url).pathname;
const read = (path) => readFileSync(join(root, path), "utf8");

const migration = read("../supabase/migrations_wynos_stripe_payment_core_v1.sql");
const checkout = read("../supabase/functions/food-stripe-checkout/index.ts");
const connect = read("../supabase/functions/merchant-stripe-connect/index.ts");
const refund = read("../supabase/functions/merchant-stripe-refund/index.ts");
const cancelStripe = read("../supabase/functions/food-stripe-cancel/index.ts");
const webhook = read("../supabase/functions/stripe-webhook/index.ts");
const foodUi = read("components/food/wynos-food-developer-app.tsx");
const merchantUi = read("components/merchant/wynos-merchant-app.tsx");
const refundUi = read("components/merchant/merchant-core-panels.tsx");

test("Stripe secrets stay server-side and private gateway tables are locked down", () => {
  assert.match(migration, /alter table public\.food_stripe_accounts enable row level security/i);
  assert.match(migration, /revoke all on table public\.food_stripe_accounts from public, anon, authenticated/i);
  assert.match(migration, /grant execute on function public\.food_apply_stripe_event[\s\S]*to service_role/i);
  for (const clientFile of [foodUi, merchantUi, refundUi]) {
    assert.doesNotMatch(clientFile, /STRIPE_SECRET_KEY|STRIPE_WEBHOOK_SECRET|sk_live_|sk_test_/);
  }
});

test("Checkout is a direct connected-account charge with idempotency and server-calculated amount", () => {
  assert.match(checkout, /"Stripe-Account": account/);
  assert.match(checkout, /"Idempotency-Key": idempotencyKey/);
  assert.match(checkout, /Math\.round\(Number\(order\.total\) \* 100\)/);
  assert.match(checkout, /params\.set\("payment_method_types\[0\]", "card"\)/);
  assert.match(checkout, /params\.set\("payment_method_types\[1\]", "promptpay"\)/);
  assert.doesNotMatch(checkout, /application_fee_amount|transfer_data|destination/);
});

test("Connect uses Standard Thai accounts and requires owner/admin for onboarding", () => {
  assert.match(connect, /params\.set\("type", "standard"\)/);
  assert.match(connect, /params\.set\("country", "TH"\)/);
  assert.match(connect, /capabilities\[promptpay_payments\]\[requested\]/);
  assert.match(connect, /Idempotency-Key/);
  assert.match(connect, /wynos-connect-/);
  assert.match(connect, /\["owner","admin"\]\.includes\(member\.role\)/);
});

test("Webhook verifies Stripe signature, enforces idempotency and finalizes status server-side", () => {
  assert.match(webhook, /verifyStripeSignature\(raw, signature, secret\)/);
  assert.match(webhook, /Math\.abs\(Math\.floor\(Date\.now\(\)\/1000\) - ts\) > 300/);
  assert.match(webhook, /food_apply_stripe_event/);
  assert.match(migration, /on conflict \(event_id\) do nothing/i);
  assert.match(migration, /amount mismatch/);
  assert.match(migration, /stripe account mismatch/);
});

test("Manual slip fallback expires any open Stripe Checkout first", () => {
  assert.match(cancelStripe, /checkout\/sessions\/\$\{encodeURIComponent\(sessionId\)\}\/expire/);
  assert.match(cancelStripe, /payment_status === "paid"/);
  assert.match(cancelStripe, /stripe_checkout_session_id: null/);
  assert.match(migration, /cancel stripe checkout before submitting slip/);
  assert.match(foodUi, /prepareFoodManualPayment/);
});

test("Food keeps slip fallback and Merchant Stripe refunds use the gateway", () => {
  assert.match(foodUi, /startFoodStripeCheckout/);
  assert.match(foodUi, /โอนเงินเข้าบัญชีร้านโดยตรงและแนบสลิปเป็นช่องทางสำรอง/);
  assert.match(foodUi, /submitFoodPayment/);
  assert.match(refundUi, /requestStripeRefund/);
  assert.match(refund, /payment_provider !== "stripe"/);
  assert.match(refund, /payment_intent/);
});

test("Stripe can satisfy Merchant payment readiness without removing legacy methods", () => {
  assert.match(migration, /v_stripe_ready/);
  assert.match(migration, /nullif\(btrim\(s\.promptpay_id\),''\)/);
  assert.match(migration, /nullif\(btrim\(s\.bank_account_number\),''\)/);
  assert.match(migration, /s\.payment_qr_path is not null/);
});
