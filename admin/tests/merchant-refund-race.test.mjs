import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../../supabase/functions/merchant-stripe-refund/index.ts", import.meta.url), "utf8");
const { outputText } = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } });

function fixture({ fee = 0, status = "succeeded", gatewayError = false, webhookFirst = false, webhookOutcome = "refunded", trackingError = false, trackingThrows = false } = {}) {
  const order = { id: "fixture-order", store_id: "fixture-store", status: "cancelled", payment_status: "paid", payment_provider: "stripe", stripe_payment_intent_id: "pi_fixture", refund_status: "pending" };
  const payment = { stripe_account_id: "acct_fixture", livemode: false, application_fee_satang: fee, application_fee_refunded_satang: 0 };
  const writes = [];
  const requests = [];
  let handler;
  const client = {
    auth: { getUser: async () => ({ data: { user: { id: "fixture-user" } }, error: null }) },
    from(table) {
      let update = null;
      const filters = [];
      const builder = {
        select() { return builder; },
        eq(key, value) { filters.push([key, value, true]); return builder; },
        neq(key, value) { filters.push([key, value, false]); return builder; },
        update(value) { update = value; return builder; },
        async maybeSingle() {
          const row = table === "food_orders" ? order : table === "food_stores" ? { merchant_account_id: "fixture-account" }
            : table === "merchant_memberships" ? { role: "owner" } : table === "food_stripe_payments" ? payment : null;
          return { data: row ? { ...row } : null, error: null };
        },
        async then(resolve, reject) {
          try {
            writes.push({ table, update: { ...update }, filters });
            if (trackingThrows && table === "food_orders") throw new Error("fixture tracking exception");
            if (trackingError && table === "food_orders") return resolve({ error: { code: "fixture_database_unavailable" } });
            const row = table === "food_orders" ? order : payment;
            const matches = filters.every(([key, value, equal]) => key === "id" || key === "order_id" || (row[key] === value) === equal);
            if (matches) Object.assign(row, update);
            return resolve({ error: null });
          } catch (error) { return reject(error); }
        },
      };
      return builder;
    },
  };
  runInNewContext(outputText, {
    exports: {}, require: () => ({ createClient: () => client }), URLSearchParams, Response, Date,
    btoa, console: { error() {}, warn() {} },
    Deno: {
      env: { get: name => ({ SUPABASE_URL: "https://fixture.invalid", SUPABASE_SERVICE_ROLE_KEY: "fixture-key", STRIPE_SECRET_KEY: "sk_test_fixture" })[name] },
      serve: value => { handler = value; },
    },
    fetch: async (url, init) => {
      requests.push({ url, method: init.method, account: init.headers["Stripe-Account"], idempotencyKey: init.headers["Idempotency-Key"], body: new URLSearchParams(init.body) });
      if (webhookFirst) Object.assign(order, { payment_status: webhookOutcome === "refunded" ? "refunded" : "paid", refund_status: webhookOutcome });
      return new Response(JSON.stringify(gatewayError ? { error: { code: "fixture_failure" } } : { id: "re_fixture", status }), { status: gatewayError ? 400 : 200 });
    },
  });
  return { order, payment, writes, requests, run: () => handler(new Request("https://fixture.invalid/refund", {
    method: "POST", headers: { Authorization: "Bearer fixture-token", "Content-Type": "application/json" },
    body: JSON.stringify({ orderId: order.id }),
  })) };
}

test("a successful refund webhook racing the gateway response stays refunded", async () => {
  const f = fixture({ webhookFirst: true });
  const response = await f.run();
  assert.equal(response.status, 200);
  assert.equal(f.order.refund_status, "refunded");
  assert.equal(f.order.payment_status, "refunded");
  assert.equal(f.requests.length, 1);
  assert.equal(f.requests[0].account, "acct_fixture");
  assert.equal(f.requests[0].idempotencyKey, "wynos-refund-fixture-order");
});

test("a failed gateway response cannot downgrade a refund already confirmed by webhook", async () => {
  const f = fixture({ webhookFirst: true, gatewayError: true });
  assert.equal((await f.run()).status, 502);
  assert.equal(f.order.refund_status, "refunded");
  assert.equal(f.order.payment_status, "refunded");
});

test("a pending gateway refund cannot record application fees as already returned", async () => {
  const f = fixture({ fee: 100, status: "pending" });
  const response = await f.run();
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.status, "pending");
  assert.equal(body.gpRecordPending, true);
  assert.equal(f.payment.application_fee_refunded_satang, 0);
  assert.equal(f.writes.filter(w => w.table === "food_stripe_payments").length, 0);
  assert.equal(f.requests[0].body.get("refund_application_fee"), "true");
});

test("a succeeded charge refund still awaits authoritative fee-refund evidence", async () => {
  const f = fixture({ fee: 100, status: "succeeded" });
  const body = await (await f.run()).json();
  assert.equal(body.gpRecordPending, true);
  assert.equal(f.payment.application_fee_refunded_satang, 0);
  assert.equal(f.writes.filter(w => w.table === "food_stripe_payments").length, 0);
});

test("GP zero keeps merchant direct charges and does not request an application-fee refund", async () => {
  const f = fixture();
  const response = await f.run();
  assert.equal(response.status, 200);
  assert.equal(f.order.refund_status, "pending", "final order status remains webhook-authoritative");
  assert.equal(f.requests[0].body.has("refund_application_fee"), false);
  assert.equal(f.writes.filter(w => w.table === "food_stripe_payments").length, 0);
});

test("an accepted gateway refund with failed tracking is returned as accepted and reconciliation pending", async () => {
  const f = fixture({ trackingError: true });
  const response = await f.run();
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.orderRecordPending, true);
  assert.equal(body.refundId, "re_fixture");
  assert.equal(body.error, undefined);
  assert.equal(f.requests.length, 1);
});

test("a rejected gateway refund keeps existing failure behaviour when no webhook completed it", async () => {
  const f = fixture({ gatewayError: true });
  const response = await f.run();
  assert.equal(response.status, 502);
  assert.equal(f.order.refund_status, "failed");
  assert.equal(f.order.payment_status, "paid");
});

test("an asynchronous failure observed before the older pending response stays failed", async () => {
  const f = fixture({ webhookFirst: true, webhookOutcome: "failed", status: "pending" });
  assert.equal((await f.run()).status, 200);
  assert.equal(f.order.refund_status, "failed");
  assert.equal(f.order.payment_status, "paid");
});

test("a thrown tracking exception after gateway acceptance does not claim a failed refund", async () => {
  const f = fixture({ trackingThrows: true });
  const response = await f.run();
  const body = await response.json();
  assert.equal(response.status, 200);
  assert.equal(body.refundId, "re_fixture");
  assert.equal(body.orderRecordPending, true);
  assert.equal(f.order.refund_status, "pending");
  assert.equal(f.writes.length, 1, "must not attempt a failure write after accepted gateway operation");
});
