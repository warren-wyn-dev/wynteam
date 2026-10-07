import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { test } from "node:test";

const root = new URL("..", import.meta.url).pathname;
const read = (path) => readFileSync(join(root, path), "utf8");

const migration = read("../supabase/migrations_wynos_stripe_payment_core_v1.sql");
const connectV2Migration = read("../supabase/migrations_wynos_stripe_connect_v2_embedded.sql");
const checkout = read("../supabase/functions/food-stripe-checkout/index.ts");
const connect = read("../supabase/functions/merchant-stripe-connect/index.ts");
const refund = read("../supabase/functions/merchant-stripe-refund/index.ts");
const cancelStripe = read("../supabase/functions/food-stripe-cancel/index.ts");
const webhook = read("../supabase/functions/stripe-webhook/index.ts");
const foodUi = read("components/food/wynos-food-developer-app.tsx");
const merchantUi = read("components/merchant/wynos-merchant-app.tsx");
const paymentUi = read("components/merchant/merchant-payment-setup.tsx");
const financeUi = read("components/merchant/merchant-finance.tsx");
const refundUi = read("components/merchant/merchant-core-panels.tsx");
const merchantCore = read("lib/merchant-core.ts");

test("Stripe secrets stay server-side and gateway tables stay private", () => {
  assert.match(migration, /alter table public\.food_stripe_accounts enable row level security/i);
  assert.match(migration, /revoke all on table public\.food_stripe_accounts from public, anon, authenticated/i);
  assert.match(connectV2Migration, /revoke all on table public\.food_stripe_payouts from public, anon, authenticated/i);
  assert.match(connectV2Migration, /revoke all on table public\.food_stripe_connect_locks from public, anon, authenticated/i);
  assert.match(migration, /grant execute on function public\.food_apply_stripe_event[\s\S]*to service_role/i);
  for (const clientFile of [foodUi, merchantUi, paymentUi, financeUi, refundUi]) {
    assert.doesNotMatch(clientFile, /STRIPE_SECRET_KEY|STRIPE_WEBHOOK_SECRET|STRIPE_V2_WEBHOOK_SECRET|sk_live_|sk_test_/);
  }
});

test("Checkout remains a direct connected-account charge with server-calculated amount", () => {
  assert.match(checkout, /"Stripe-Account": account/);
  assert.match(checkout, /headers\["Idempotency-Key"\]\s*=\s*idempotencyKey/);
  assert.match(checkout, /Math\.round\(Number\(order\.total\) \* 100\)/);
  assert.match(checkout, /params\.set\("payment_method_types\[0\]", "card"\)/);
  assert.match(checkout, /params\.set\("payment_method_types\[1\]", "promptpay"\)/);
  assert.doesNotMatch(checkout, /application_fee_amount|transfer_data|destination/);
});

test("new merchants use Accounts v2 and never create a connected account with POST v1 accounts", () => {
  assert.match(connect, /https:\/\/api\.stripe\.com\/v2\/core\/accounts/);
  assert.match(connect, /"Stripe-Version": STRIPE_V2_VERSION/);
  assert.match(connect, /identity: \{ country: "th" \}/);
  assert.match(connect, /card_payments: \{ requested: true \}/);
  assert.match(connect, /promptpay_payments: \{ requested: true \}/);
  assert.match(connect, /fees_collector: "stripe"/);
  assert.match(connect, /losses_collector: "stripe"/);
  assert.match(connect, /dashboard: "none"/);
  assert.match(connect, /wynos-connect-v2-/);
  assert.match(connect, /v1_account_instead_of_v2_account/);
  assert.doesNotMatch(connect, /fetch\("https:\/\/api\.stripe\.com\/v1\/accounts",\s*\{\s*method:\s*"POST"/);
  assert.match(connect, /\["owner","admin"\]\.includes\(member\.role\)/);
});

test("double tap protection uses DB lock, unique store mapping and Stripe idempotency", () => {
  assert.match(connectV2Migration, /store_id uuid primary key references public\.food_stores/i);
  assert.match(connectV2Migration, /food_stripe_connect_locks/);
  assert.match(connectV2Migration, /merchant_acquire_stripe_connect_lock/);
  assert.match(connect, /acquireProvisioningLock/);
  assert.match(connect, /Idempotency-Key/);
  assert.match(connect, /wynos-connect-v2-/);
  assert.match(connect, /waitForSavedAccount/);
});

test("embedded onboarding is primary for v2 and hosted onboarding remains a fallback", () => {
  assert.match(connect, /https:\/\/api\.stripe\.com\/v1\/account_sessions/);
  assert.match(connect, /components\[\$\{component\}\]\[enabled\]/);
  assert.match(connect, /external_account_collection/);
  assert.match(connect, /flow: "embedded"/);
  assert.match(connect, /https:\/\/api\.stripe\.com\/v2\/core\/account_links/);
  assert.match(paymentUi, /https:\/\/connect-js\.stripe\.com\/v1\.0\/connect\.js/);
  assert.match(paymentUi, /createMerchantStripeSession/);
  assert.match(paymentUi, /"account-onboarding"/);
  assert.match(paymentUi, /"account-management"/);
  assert.match(paymentUi, /locale: "th-TH"/);
});

test("Merchant payment UX is WYNOS-first and auto-refreshes return/refresh URLs", () => {
  assert.match(merchantUi, /เปิดรับชำระเงิน/);
  assert.match(paymentUi, /เปิดรับชำระเงิน/);
  assert.match(paymentUi, /พร้อมรับเงิน/);
  assert.match(paymentUi, /ต้องยืนยันข้อมูล/);
  assert.match(paymentUi, /กำลังตั้งค่า/);
  assert.match(paymentUi, /มีปัญหา กรุณาดำเนินการต่อ/);
  assert.match(paymentUi, /searchParams\.get\("stripe"\)/);
  assert.match(paymentUi, /stripeReturn === "refresh"/);
  assert.doesNotMatch(merchantUi, /เชื่อม Stripe|ตรวจสถานะ|ดำเนินการต่อใน Stripe/);
  assert.doesNotMatch(paymentUi, /Accounts v2|capabilit|webhook|connected account/i);
});

test("readiness requires payments, payouts, requirements and a payout bank", () => {
  assert.match(connect, /core\.charges && core\.payouts && !core\.due && bank\.ready/);
  assert.match(connect, /payout_bank_ready/);
  assert.match(connect, /requirements_due/);
  assert.match(connect, /promptpay_supported/);
  assert.match(connect, /stripe_payments_enabled: state\.status === "ready"/);
  assert.match(connectV2Migration, /bank_last4/);
  assert.doesNotMatch(connectV2Migration, /bank_account_number/);
});

test("payout schedule prefers daily through Balance Settings without hard-coding the UI", () => {
  assert.match(connect, /https:\/\/api\.stripe\.com\/v1\/balance_settings/);
  assert.match(connect, /payments\[payouts\]\[schedule\]\[interval\]/);
  assert.match(connect, /"daily"/);
  assert.match(paymentUi, /ตามรอบที่บัญชีนี้รองรับ/);
  assert.match(paymentUi, /รอบที่เร็วที่สุดที่บัญชีนี้รองรับ/);
});

test("Webhook verifies signatures, supports Accounts v2 and payout outcomes", () => {
  assert.match(webhook, /verifyAnyStripeSignature/);
  assert.match(webhook, /STRIPE_V2_WEBHOOK_SECRET/);
  assert.match(webhook, /eventType\.startsWith\("v2\.core\.account"\)/);
  assert.match(webhook, /related_object/);
  assert.match(webhook, /payout\.paid/);
  assert.match(webhook, /payout\.failed/);
  assert.match(webhook, /food_stripe_payouts/);
  assert.match(webhook, /food_apply_stripe_event/);
  assert.match(migration, /on conflict \(event_id\) do nothing/i);
  assert.match(migration, /amount mismatch/);
  assert.match(migration, /stripe account mismatch/);
});

test("Paid remains webhook-authoritative and browser redirects cannot mark orders paid", () => {
  assert.match(webhook, /checkout\.session\.completed/);
  assert.match(webhook, /checkout\.session\.async_payment_succeeded/);
  assert.match(webhook, /checkout\.session\.async_payment_failed/);
  assert.match(webhook, /payment_intent\.payment_failed/);
  assert.match(webhook, /state = "paid"/);
  assert.doesNotMatch(foodUi, /stripe=success[\s\S]{0,400}payment_status\s*[:=]\s*["']paid/);
});

test("Manual slip fallback expires any open Stripe Checkout first", () => {
  assert.match(cancelStripe, /checkout\/sessions\/\$\{encodeURIComponent\(sessionId\)\}\/expire/);
  assert.match(cancelStripe, /payment_status === "paid"/);
  assert.match(cancelStripe, /stripe_checkout_session_id: null/);
  assert.match(migration, /cancel stripe checkout before submitting slip/);
  assert.match(foodUi, /if \(order\.stripe_checkout_session_id\)/);
  assert.match(foodUi, /prepareFoodManualPayment/);
});

test("Food keeps slip fallback and Merchant refunds use the gateway", () => {
  assert.match(foodUi, /startFoodStripeCheckout/);
  assert.match(foodUi, /submitFoodPayment/);
  assert.match(refundUi, /requestStripeRefund/);
  assert.match(refund, /payment_provider !== "stripe"/);
  assert.match(refund, /payment_intent/);
});

test("Merchant Finance reads sanitized payout status and exposes only bank last4", () => {
  assert.match(financeUi, /fetchMerchantStripeStatus/);
  assert.match(financeUi, /ยอดขายวันนี้/);
  assert.match(financeUi, /กำลังดำเนินการ/);
  assert.match(financeUi, /พร้อมโอน/);
  assert.match(financeUi, /โอนเข้าธนาคารแล้ว/);
  assert.match(financeUi, /คืนเงิน/);
  assert.match(financeUi, /bank_last4/);
  assert.doesNotMatch(financeUi, /stripe_account_id|bank_account_number/);
});

test("Merchant errors are localized and raw gateway errors stay out of UI", () => {
  assert.match(merchantCore, /context instanceof Response/);
  assert.match(merchantCore, /\/[ก-๙]\//);
  assert.match(merchantCore, /เปิดรับชำระเงินไม่สำเร็จ/);
  assert.match(merchantCore, /อัปเดตสถานะการรับเงินไม่สำเร็จ/);
  assert.doesNotMatch(merchantCore, /return raw\.message/);
});
