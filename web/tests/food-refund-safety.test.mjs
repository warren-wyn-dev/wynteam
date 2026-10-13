import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

import { refundResponseState, verifiedApplicationFeeRefund } from "../../supabase/functions/merchant-stripe-refund/_lib.ts";

// Execute the actual handler with synthetic auth/database/provider boundaries.
// No environment variables, credentials, network or database services are used.
const raw = readFileSync(new URL("../../supabase/functions/merchant-stripe-refund/index.ts", import.meta.url), "utf8");
const source = stripTypeScriptTypes(raw.replace(/^import .*;\s*$/gm, ""));

async function runRefund({ status = "pending", databaseError = false, webhookWins = false, networkError = false, feeRefunded = 1500, paymentReadError = false, memberRole = "owner" } = {}) {
  const order = { id: "order_test", store_id: "store_test", status: "cancelled", payment_status: "paid", payment_provider: "stripe", stripe_payment_intent_id: "pi_test", refund_status: "pending" };
  const payment = { order_id: "order_test", stripe_account_id: "acct_test", livemode: false, application_fee_satang: 1500, application_fee_refunded_satang: 0 };
  const writes = [];
  const requests = [];
  const client = {
    auth: { getUser: async () => ({ data: { user: { id: "merchant_test" } }, error: null }) },
    from(table) {
      let patch = null;
      const filters = [];
      const result = () => {
        if (!patch) {
          if (table === "food_stripe_payments" && paymentReadError) return { data: null, error: { code: "synthetic_read_failure" } };
          const data = table === "food_orders" ? order
            : table === "food_stores" ? { merchant_account_id: "business_test" }
            : table === "merchant_memberships" ? memberRole == null ? null : { role: memberRole }
            : table === "food_stripe_payments" ? payment : null;
          return { data: data && { ...data }, error: null };
        }
        if (databaseError) return { data: null, error: { code: "synthetic_write_failure" } };
        if (table === "food_orders" && webhookWins) {
          order.payment_status = "refunded";
          order.refund_status = "refunded";
        }
        const target = table === "food_orders" ? order : payment;
        const matches = filters.every(([operation, key, value]) => operation === "eq" ? target[key] === value : target[key] !== value);
        if (!matches) return { data: null, error: null };
        Object.assign(target, patch);
        writes.push({ table, patch: { ...patch } });
        return { data: table === "food_orders" ? { id: order.id } : { order_id: order.id }, error: null };
      };
      const query = {
        select: () => query,
        update: (value) => { patch = value; return query; },
        eq: (key, value) => { filters.push(["eq", key, value]); return query; },
        neq: (key, value) => { filters.push(["neq", key, value]); return query; },
        maybeSingle: async () => result(),
        then: (resolve, reject) => Promise.resolve().then(result).then(resolve, reject),
      };
      return query;
    },
  };
  let handler;
  const syntheticEnv = { SUPABASE_URL: "https://mock.invalid", SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-key", STRIPE_SECRET_KEY: "sk_test_synthetic_fixture" };
  runInNewContext(source, {
    createClient: () => client,
    refundResponseState,
    verifiedApplicationFeeRefund,
    Deno: { env: { get: (name) => syntheticEnv[name] }, serve: (value) => { handler = value; } },
    fetch: async (url, init) => {
      requests.push({ url, init });
      if (networkError) throw new Error("synthetic_network_failure");
      if (url === "https://api.stripe.com/v1/refunds") return Response.json({ id: "re_test", status, charge: "ch_test" });
      if (url === "https://api.stripe.com/v1/charges/ch_test") return Response.json({ id: "ch_test", application_fee: "fee_test" });
      if (url === "https://api.stripe.com/v1/application_fees/fee_test") return Response.json({ id: "fee_test", account: "acct_test", charge: "ch_test", currency: "thb", amount: 1500, amount_refunded: feeRefunded });
      throw new Error("unexpected_synthetic_provider_request");
    },
    Response, Request, URLSearchParams, Date, btoa,
    console: { error: () => {}, warn: () => {} },
  });
  const response = await handler(new Request("https://mock.invalid/refund", {
    method: "POST", headers: { Authorization: "Bearer synthetic-session", "Content-Type": "application/json" },
    body: JSON.stringify({ orderId: order.id }),
  }));
  return { code: response.status, payload: await response.json(), order, payment, writes, requests };
}

test("actual handler leaves pending/action-required refunds pending without GP credit", async () => {
  for (const status of ["pending", "requires_action"]) {
    const result = await runRefund({ status });
    assert.equal(result.code, 200);
    assert.equal(result.order.refund_status, "pending");
    assert.equal(result.payment.application_fee_refunded_satang, 0);
    assert.equal(result.payload.gpRecordPending, true);
    assert.equal(result.requests.length, 1);
    assert.equal(result.requests[0].init.headers["Idempotency-Key"], "wynos-refund-order_test");
  }
});

test("actual handler reports failed/canceled provider refund instead of success", async () => {
  for (const status of ["failed", "canceled"]) {
    const result = await runRefund({ status });
    assert.equal(result.code, 502);
    assert.equal(result.order.refund_status, "failed");
    assert.equal(result.payment.application_fee_refunded_satang, 0);
  }
});

test("provider success followed by database failure remains a reconciliation issue", async () => {
  const result = await runRefund({ status: "succeeded", databaseError: true });
  assert.equal(result.code, 200);
  assert.equal(result.payload.status, "succeeded");
  assert.equal(result.payload.orderRecordPending, true);
  assert.equal(result.payload.gpRecordPending, true);
  assert.equal(result.order.refund_status, "pending");
  assert.equal(result.writes.length, 0);
});

test("a webhook that finishes first cannot be regressed to pending or failed", async () => {
  for (const status of ["pending", "failed"]) {
    const result = await runRefund({ status, webhookWins: true });
    assert.equal(result.order.refund_status, "refunded");
    assert.equal(result.order.payment_status, "refunded");
    assert.equal(result.writes.length, 0);
  }
});

test("unknown/network outcome does not overwrite persisted financial state", async () => {
  for (const options of [{ status: "new_provider_state" }, { networkError: true }]) {
    const result = await runRefund(options);
    assert.equal(result.code, 502);
    assert.equal(result.order.refund_status, "pending");
    assert.equal(result.writes.length, 0);
  }
});

test("GP credit requires separate full fee evidence from the platform account", async () => {
  const result = await runRefund({ status: "succeeded" });
  assert.equal(result.code, 200);
  assert.equal(result.payment.application_fee_refunded_satang, 1500);
  assert.equal(result.payload.gpRecordPending, false);
  assert.equal(result.requests[1].init.headers["Stripe-Account"], "acct_test");
  assert.equal(result.requests[2].init.headers["Stripe-Account"], undefined);
  assert.equal(result.order.refund_status, "pending", "final order state still comes from webhook");
});

test("a partial or missing application fee refund cannot credit a full GP refund", async () => {
  for (const feeRefunded of [0, 500, null]) {
    const result = await runRefund({ status: "succeeded", feeRefunded });
    assert.equal(result.payment.application_fee_refunded_satang, 0);
    assert.equal(result.payload.gpRecordPending, true);
  }
});

test("failed payment ledger reads cannot fall back to another active account", async () => {
  const result = await runRefund({ paymentReadError: true });
  assert.equal(result.code, 503);
  assert.equal(result.requests.length, 0);
  assert.equal(result.writes.length, 0);
});

test("a missing store membership or disallowed role cannot request money movement", async () => {
  for (const memberRole of [null, "menu", "delivery"]) {
    const result = await runRefund({ memberRole });
    assert.equal(result.code, 403);
    assert.equal(result.requests.length, 0);
    assert.equal(result.writes.length, 0);
  }
});
