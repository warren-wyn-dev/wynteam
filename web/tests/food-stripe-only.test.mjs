// ZOKY Stripe-only payments + automatic refunds (Founder 2026-10-22): customer web.
// Synthetic data and fake clients only; no network, no real Supabase/Stripe.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

import {
  cancelFoodStripeCheckout,
  FOOD_CANCEL_ALREADY_PAID_COPY,
  fetchFoodPaymentPolicy,
  fetchStorePaymentOptions,
  foodEdgePayload,
  foodRefundNotice,
  foodStoreNotAccepting,
  foodStripeCheckoutErrorCopy,
} from "../lib/food-payment-policy.ts";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const STORE_A = "11111111-1111-4111-8111-111111111111";
const STORE_B = "22222222-2222-4222-8222-222222222222";

const rpcClient = (handler) => {
  const calls = [];
  return {
    calls,
    rpc: async (name, args) => {
      calls.push({ name, args });
      return handler(name, args);
    },
  };
};
const missingRpc = () => ({ data: null, error: { code: "PGRST202", message: "Could not find the function" } });

// A FunctionsHttpError-like error: supabase-js only exposes a non-2xx body through error.context.
const httpError = (status, body) => ({
  data: null,
  error: Object.assign(new Error("Edge Function returned a non-2xx status code"), {
    name: "FunctionsHttpError",
    context: new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } }),
  }),
});
const functionsClient = (result) => {
  const calls = [];
  return { calls, functions: { invoke: async (name, options) => { calls.push({ name, options }); return result; } } };
};

test("payment policy: on only when the RPC says so; missing RPC or errors keep legacy", async () => {
  assert.equal(await fetchFoodPaymentPolicy(rpcClient(() => ({ data: true, error: null }))), true);
  assert.equal(await fetchFoodPaymentPolicy(rpcClient(() => ({ data: [{ stripe_only: true }], error: null }))), true);
  assert.equal(await fetchFoodPaymentPolicy(rpcClient(() => ({ data: false, error: null }))), false);
  assert.equal(await fetchFoodPaymentPolicy(rpcClient(missingRpc)), false);
  assert.equal(await fetchFoodPaymentPolicy(rpcClient(() => ({ data: "true", error: null }))), false);
  assert.equal(await fetchFoodPaymentPolicy({ rpc: async () => { throw new Error("offline"); } }), false);
  const client = rpcClient(() => ({ data: true, error: null }));
  await fetchFoodPaymentPolicy(client);
  assert.deepEqual(client.calls, [{ name: "food_payment_policy_public", args: undefined }]);
});

test("store payment options: one batched call with valid ids; missing RPC = null (legacy)", async () => {
  const client = rpcClient(() => ({
    data: [
      { store_id: STORE_A, accepting_orders: false, promptpay: false, card: false },
      { store_id: STORE_B, accepting_orders: true, promptpay: true, card: true },
    ],
    error: null,
  }));
  const options = await fetchStorePaymentOptions(client, [STORE_A, STORE_B, STORE_A, "not-a-uuid", ""]);
  assert.equal(client.calls.length, 1);
  assert.equal(client.calls[0].name, "food_store_payment_options");
  assert.deepEqual(client.calls[0].args, { p_store_ids: [STORE_A, STORE_B] });
  assert.equal(options.get(STORE_A).accepting_orders, false);
  assert.equal(options.get(STORE_B).promptpay, true);

  const none = rpcClient(() => ({ data: [], error: null }));
  assert.equal((await fetchStorePaymentOptions(none, [])).size, 0);
  assert.equal(none.calls.length, 0, "no call without stores");
  assert.equal(await fetchStorePaymentOptions(rpcClient(missingRpc), [STORE_A]), null);
});

test("a store is shown as not accepting only under the policy and only when the server says so", () => {
  const options = new Map([
    [STORE_A, { store_id: STORE_A, accepting_orders: false, promptpay: false, card: false }],
    [STORE_B, { store_id: STORE_B, accepting_orders: true, promptpay: true, card: true }],
  ]);
  assert.equal(foodStoreNotAccepting(true, options, STORE_A), true);
  assert.equal(foodStoreNotAccepting(true, options, STORE_B), false);
  assert.equal(foodStoreNotAccepting(false, options, STORE_A), false, "policy off = legacy");
  assert.equal(foodStoreNotAccepting(true, null, STORE_A), false, "options unavailable = accepting");
  assert.equal(foodStoreNotAccepting(true, new Map(), STORE_A), false, "unknown store = accepting");
  assert.equal(foodStoreNotAccepting(true, options, null), false);
});

test("Edge Function errors are read from the non-2xx body", async () => {
  const { error } = httpError(422, { error: "promptpay_unavailable" });
  assert.deepEqual(await foodEdgePayload(error, null), { error: "promptpay_unavailable" });
  assert.deepEqual(await foodEdgePayload(null, { url: "https://checkout.stripe.test/x" }), { url: "https://checkout.stripe.test/x" });
  assert.equal(await foodEdgePayload(new Error("network"), null), null);
  const notJson = Object.assign(new Error("x"), { context: new Response("<html>", { status: 502 }) });
  assert.equal(await foodEdgePayload(notJson, null), null);
});

test("checkout errors map to Thai copy, including the new Stripe-only codes", () => {
  assert.equal(foodStripeCheckoutErrorCopy({ error: "promptpay_unavailable" }), "ร้านนี้ยังไม่รองรับพร้อมเพย์ กรุณาเลือกบัตรเครดิต/เดบิต");
  assert.equal(foodStripeCheckoutErrorCopy({ error: "store_not_accepting_orders" }), "ร้านนี้ยังไม่เปิดรับออเดอร์");
  assert.equal(foodStripeCheckoutErrorCopy({ error: "stripe_not_ready" }), "ร้านยังไม่พร้อมรับชำระผ่าน Stripe");
  assert.equal(foodStripeCheckoutErrorCopy({ error: "payment_deadline_expired", message: "หมดเวลาชำระเงินแล้ว" }), "หมดเวลาชำระเงินแล้ว");
  assert.equal(foodStripeCheckoutErrorCopy(null), "เปิดหน้าชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง");
});

test("customer cancel closes the Stripe session first; a completed payment blocks the cancel", async () => {
  const expired = functionsClient({ data: { cancelled: true }, error: null });
  assert.equal(await cancelFoodStripeCheckout(expired, "order-1"), "expired");
  assert.deepEqual(expired.calls, [{ name: "food-stripe-cancel", options: { body: { orderId: "order-1", reason: "order_cancelled" } } }]);

  assert.equal(await cancelFoodStripeCheckout(functionsClient(httpError(409, { error: "stripe_payment_already_completed" })), "o"), "paid");
  assert.equal(await cancelFoodStripeCheckout(functionsClient({ data: { cancelled: false, reason: "no_stripe_session" }, error: null }), "o"), "none");
  assert.equal(await cancelFoodStripeCheckout(functionsClient(httpError(502, { error: "stripe_session_lookup_failed" })), "o"), "failed");
  assert.equal(await cancelFoodStripeCheckout({ functions: { invoke: async () => { throw new Error("offline"); } } }, "o"), "failed");
  assert.equal(FOOD_CANCEL_ALREADY_PAID_COPY, "ชำระเงินแล้ว ยกเลิกไม่ได้ ติดต่อร้าน");
});

test("refund states shown to the customer", () => {
  assert.equal(foodRefundNotice({ refund_status: "none", payment_status: "paid" }), null);
  assert.equal(foodRefundNotice({ payment_status: "paid" }), null);
  assert.equal(foodRefundNotice({ refund_status: "pending", payment_provider: "stripe" }).title, "กำลังคืนเงิน");
  assert.match(foodRefundNotice({ refund_status: "pending", payment_provider: "stripe" }).detail, /อัตโนมัติ/);
  assert.equal(foodRefundNotice({ refund_status: "pending", payment_provider: "manual" }).detail, "ร้านจะโอนเงินคืนให้คุณ");
  assert.equal(foodRefundNotice({ refund_status: "refunded" }).title, "คืนเงินแล้ว");
  assert.equal(foodRefundNotice({ refund_status: "none", payment_status: "refunded" }).title, "คืนเงินแล้ว");
  const failed = foodRefundNotice({ refund_status: "failed", payment_provider: "stripe" });
  assert.equal(failed.title, "คืนเงินมีปัญหา ติดต่อร้าน");
  assert.equal(failed.tone, "warn");
});

test("customer web wires the policy without changing the legacy flow", () => {
  const lib = read("../lib/food-customer.ts");
  const app = read("../components/food/wynos-food-developer-app.tsx");
  // Library contract.
  assert.match(lib, /export async function startFoodStripeCheckout\(client: SupabaseClient, orderId: string, method\?: FoodCheckoutMethod\)/);
  assert.match(lib, /body: method \? \{ orderId, method \} : \{ orderId \}/);
  assert.match(lib, /fetchFoodPaymentPolicy,\n\s*fetchStorePaymentOptions,/);
  assert.match(lib, /message\.includes\("store_not_accepting_orders"\)\) return FOOD_STORE_NOT_ACCEPTING_COPY/);
  assert.match(lib, /message\.includes\("promptpay_unavailable"\)\) return FOOD_PROMPTPAY_UNAVAILABLE_COPY/);
  // Two first-class Stripe options under the policy; PromptPay only when the store has it.
  assert.match(app, /\{orderStoreOption\?\.promptpay \? \(/);
  assert.match(app, /payWithStripe\("promptpay"\)/);
  assert.match(app, /"พร้อมเพย์ · ยืนยันอัตโนมัติ"/);
  assert.match(app, /payWithStripe\("card"\)/);
  assert.match(app, /"บัตรเครดิต\/เดบิต"/);
  // No QR, bank rows, copy buttons or slip picker under the policy; legacy kept when it is off.
  assert.match(app, /footer=\{canPay && paymentGate\.ready && !stripeOnly \? \(/);
  assert.match(app, /if \(!paymentGate\.ready \|\| stripeOnly \|\| \(orderStore && !orderStore\.promptpay_id\)/);
  assert.match(app, /\) : stripeOnly \? \(\s*<small className="fx-pay-qr-note">ชำระผ่าน Stripe/);
  assert.match(app, /\{!stripeOnly && slipFile \? \(/);
  assert.match(app, /paymentGate\.ready && !stripeOnly && orderStore\?\.stripe_payments_enabled \? \(/);
  assert.match(app, /แนบสลิปการโอน/, "legacy slip flow still exists for policy off");
  // Customer cancel: Stripe session first, then the RPC.
  assert.match(app, /if \(order\.stripe_checkout_session_id\) \{\s*const stripe = await cancelFoodStripeCheckout\(client, order\.id\);\s*if \(stripe === "paid"\) \{\s*onMessage\(FOOD_CANCEL_ALREADY_PAID_COPY\);/);
  assert.ok(app.indexOf("await cancelFoodStripeCheckout(client, order.id)") < app.indexOf('await cancelFoodCustomerOrder(client, order.id, "ยกเลิกโดยลูกค้าใน ZOKY")'));
  // Not-ready stores: tagged in lists and Home, cannot add to cart or check out.
  assert.match(app, /\{store\.is_open && notAccepting \? <b className="zk-tag is-closed">\{FOOD_STORE_NOT_ACCEPTING_TAG\}<\/b> : null\}/);
  assert.match(app, /notAccepting \? <b>\{FOOD_STORE_NOT_ACCEPTING_TAG\}<\/b>/);
  assert.match(app, /const open = !storeNotAccepting && foodStoreIsEffectivelyOpen\(store\);/);
  assert.match(app, /const storeOpen = !!store && !storeNotAccepting && foodStoreIsEffectivelyOpen\(store\);/);
  assert.match(app, /storeOpen=\{!storeNotAccepting && foodStoreIsEffectivelyOpen\(store\)\}/);
  assert.match(app, /\|\| \(paymentGate\.notAccepting\(store\.id\) \? FOOD_STORE_NOT_ACCEPTING_COPY : ""\)/);
  // Refund states on the order.
  assert.match(app, /const refundNotice = foodRefundNotice\(order\);/);
  // Options are only fetched under the policy.
  assert.match(app, /const key = stripeOnly \? storeIds\.filter\(Boolean\)\.join\(","\) : "";/);
});

test("food-stripe-checkout validates the method server-side and keeps the session short-lived", () => {
  const checkout = read("../../supabase/functions/food-stripe-checkout/index.ts");
  const cancel = read("../../supabase/functions/food-stripe-cancel/index.ts");
  assert.match(checkout, /const method = parseCheckoutMethod\(rawMethod\);\s*if \(method === null\) return json\(\{ error: "invalid_payment_method" \}, 400\);/);
  assert.match(checkout, /if \(method === "promptpay" && account\.promptpay_enabled !== true\) \{\s*return json\(\{ error: "promptpay_unavailable"[^\n]*\}, 422\);/);
  assert.match(checkout, /sessionMatchesMethod\(session, method\)/);
  assert.match(checkout, /const expireError = await expireOpenSession\(/);
  assert.match(checkout, /params\.set\("expires_at", String\(expiresAt\)\)/);
  // Existing checks are kept.
  assert.match(checkout, /if \(stripeLiveMode && !isFoodWebOrigin\(requestOrigin\)\)/);
  assert.match(checkout, /if \(!order \|\| order\.buyer_id !== user\.id\) return json\(\{ error: "order_not_found" \}, 404\);/);
  assert.match(checkout, /Math\.round\(Number\(order\.total\) \* 100\)/);
  // food-stripe-cancel: the reason only changes the ledger note.
  assert.match(cancel, /ledgerNote = stripeCancelLedgerNote\(body\.reason\);/);
  assert.match(cancel, /last_error: ledgerNote,/);
});
