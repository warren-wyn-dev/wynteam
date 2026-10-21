import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const read = (path) => readFileSync(new URL(path, import.meta.url), "utf8");
const compile = (input) => ts.transpileModule(input, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const edgeSource = compile(read("../../supabase/functions/food-stripe-cancel/index.ts"));
const clientModule = { exports: {} };
runInNewContext(compile(read("../lib/food-customer.ts")), {
  exports: clientModule.exports, module: clientModule, Response,
  require: () => ({}),
});
const { cancelFoodCustomerOrder, prepareFoodManualPayment } = clientModule.exports;

function cancelHarness({
  sessionId = "cs_existing",
  buyer = "buyer_fixture",
  paymentStatus = "pending",
  orderStatus = "pending_acceptance",
  purpose = "",
  clearSucceeds = true,
  ledgerAfterClear = null,
  responses = [
    { id: "cs_existing", status: "open", payment_status: "unpaid" },
    { id: "cs_existing", status: "expired", payment_status: "unpaid" },
  ],
} = {}) {
  const calls = [];
  const writes = [];
  const ledger = { status: "pending", checkout_session_id: sessionId, order_id: "order_fixture" };
  const order = {
    id: "order_fixture", buyer_id: buyer, store_id: "store_fixture",
    payment_status: paymentStatus, status: orderStatus, payment_provider: "stripe", stripe_checkout_session_id: sessionId,
  };
  const admin = {
    auth: { getUser: async () => ({ data: { user: { id: "buyer_fixture" } }, error: null }) },
    from(table) {
      let mutation = false;
      let updateValue;
      const filters = [];
      const query = {
        select() { return query; },
        eq(key, value) { filters.push((row) => row[key] === value); return query; },
        in(key, values) { filters.push((row) => values.includes(row[key])); return query; },
        update(value) { mutation = true; updateValue = value; writes.push({ table, value }); return query; },
        then(resolve) {
          if (table === "food_stripe_payments" && updateValue && filters.every((filter) => filter(ledger))) {
            Object.assign(ledger, updateValue);
          }
          return Promise.resolve({ error: null }).then(resolve);
        },
        async maybeSingle() {
          if (table === "food_orders") {
            if (mutation && clearSucceeds && ledgerAfterClear) ledger.status = ledgerAfterClear;
            return { data: mutation ? (clearSucceeds ? { id: order.id } : null) : order, error: null };
          }
          if (table === "food_stripe_payments") return { data: { stripe_account_id: "acct_fixture", livemode: false }, error: null };
          assert.fail(`Unexpected table ${table}`);
        },
      };
      return query;
    },
  };
  let handler;
  const env = { SUPABASE_URL: "https://supabase.test", SUPABASE_SERVICE_ROLE_KEY: "fixture-key", STRIPE_SECRET_KEY: "sk_test_fixture_only" };
  runInNewContext(edgeSource, {
    exports: {}, Response, URLSearchParams, btoa,
    require: (path) => path.includes("_lib") ? { isFoodWebOrigin: () => false } : { createClient: () => admin },
    Deno: { env: { get: (name) => env[name] }, serve: (callback) => { handler = callback; } },
    fetch: async (url, init) => {
      calls.push({ url, init });
      const response = responses[calls.length - 1];
      if (response instanceof Error) throw response;
      if (response instanceof Response) return response;
      assert.ok(response, "Unexpected gateway request");
      return Response.json(response);
    },
  });
  return {
    calls, writes, ledger,
    async run() {
      const response = await handler(new Request("https://function.test", {
        method: "POST", headers: { Authorization: "Bearer fixture-token", "Content-Type": "application/json" },
        body: JSON.stringify({ orderId: order.id, purpose }),
      }));
      return { status: response.status, body: await response.json() };
    },
  };
}

test("order cancellation expires its Checkout before clearing the locked session mapping", async () => {
  const harness = cancelHarness();
  const result = await harness.run();
  assert.equal(result.status, 200);
  assert.equal(result.body.cancelled, true);
  assert.equal(harness.calls.length, 2);
  assert.ok(harness.calls[1].url.endsWith("/cs_existing/expire"));
  assert.equal(harness.calls[1].init.method, "POST");
  assert.equal(harness.writes[0].table, "food_orders");
  assert.equal(harness.writes[0].value.stripe_checkout_session_id, null);
  assert.equal(harness.writes[1].table, "food_stripe_payments");
});

test("paid Stripe order may proceed to cancellation RPC only before merchant acceptance", async () => {
  const allowed = cancelHarness({ paymentStatus: "paid", purpose: "cancel_order" });
  assert.equal((await allowed.run()).body.reason, "paid_order_cancel_allowed"); assert.equal(allowed.calls.length, 0);
  const accepted = cancelHarness({ paymentStatus: "paid", orderStatus: "accepted", purpose: "cancel_order" });
  assert.equal((await accepted.run()).status, 409);
  const switchPayment = cancelHarness({ paymentStatus: "paid" });
  assert.equal((await switchPayment.run()).status, 409);
});

test("already-expired Checkout can be safely cleared without expiring again", async () => {
  const harness = cancelHarness({ responses: [{ status: "expired", payment_status: "unpaid" }] });
  assert.equal((await harness.run()).status, 200);
  assert.equal(harness.calls.length, 1);
  assert.equal(harness.writes.length, 2);
});

test("paid and asynchronous completed Checkout block order cancellation", async () => {
  for (const payment_status of ["paid", "unpaid"]) {
    const harness = cancelHarness({ responses: [{ status: "complete", payment_status }] });
    const result = await harness.run();
    assert.equal(result.status, 409);
    assert.equal(result.body.error, "stripe_payment_already_completed");
    assert.equal(harness.writes.length, 0);
  }
});

test("network, gateway, malformed and unknown lookup results never clear a payable URL", async () => {
  for (const response of [
    new Error("network unavailable"),
    Response.json({}, { status: 503 }),
    Response.json(null),
    new Response("malformed", { status: 200 }),
    { status: "unknown" },
  ]) {
    const harness = cancelHarness({ responses: [response] });
    const result = await harness.run();
    assert.equal(result.status, 502);
    assert.equal(result.body.error, "stripe_session_lookup_failed");
    assert.equal(harness.writes.length, 0);
  }
});

test("HTTP success without confirmed expiry cannot clear the session mapping", async () => {
  const harness = cancelHarness({ responses: [{ status: "open" }, {}, { status: "open" }] });
  const result = await harness.run();
  assert.equal(result.status, 502);
  assert.equal(result.body.error, "stripe_session_expire_failed");
  assert.equal(harness.writes.length, 0);
});

test("payment completing during expiry blocks cancellation", async () => {
  const harness = cancelHarness({ responses: [{ status: "open" }, Response.json({}, { status: 400 }), { status: "complete", payment_status: "paid" }] });
  const result = await harness.run();
  assert.equal(result.status, 409);
  assert.equal(result.body.error, "stripe_payment_already_completed");
  assert.equal(harness.writes.length, 0);
});

test("an expiry retry can recover only when Stripe confirms expired", async () => {
  const harness = cancelHarness({ responses: [{ status: "open" }, Response.json({}, { status: 400 }), { status: "expired", payment_status: "unpaid" }] });
  assert.equal((await harness.run()).status, 200);
  assert.equal(harness.calls.length, 3);
  assert.equal(harness.writes.length, 2);
});

test("another buyer cannot expire an order's Checkout", async () => {
  const harness = cancelHarness({ buyer: "another_buyer" });
  assert.equal((await harness.run()).status, 404);
  assert.equal(harness.calls.length, 0);
  assert.equal(harness.writes.length, 0);
});

test("changed payment mapping cannot overwrite the payment ledger", async () => {
  const harness = cancelHarness({ clearSucceeds: false });
  const result = await harness.run();
  assert.equal(result.status, 409);
  assert.equal(result.body.error, "payment_state_changed");
  assert.equal(harness.writes.length, 1);
});

test("a webhook settling after session cleanup cannot be demoted by cancellation bookkeeping", async () => {
  for (const status of ["paid", "refunded"]) {
    const harness = cancelHarness({ ledgerAfterClear: status });
    assert.equal((await harness.run()).status, 200);
    assert.equal(harness.ledger.status, status);
  }
});

test("customer cancel checks the server's latest Checkout even without a client session snapshot", async () => {
  for (const data of [{ cancelled: true }, { cancelled: false, reason: "no_stripe_session" }, { cancelled: false, reason: "paid_order_cancel_allowed" }]) {
    const sequence = [];
    await cancelFoodCustomerOrder({
      functions: { invoke: async (name) => { sequence.push(name); return { data, error: null }; } },
      rpc: async (name, params) => { sequence.push(name); assert.equal(params.p_order_id, "order_fixture"); return { error: null }; },
    }, "order_fixture", "fixture cancellation");
    assert.deepEqual(sequence, ["food-stripe-cancel", "food_cancel_order"]);
  }
});

test("paid-order cancellation permission cannot be used to switch to a manual payment", async () => {
  await assert.rejects(() => prepareFoodManualPayment({
    functions: { invoke: async () => ({ data: { cancelled: false, reason: "paid_order_cancel_allowed" }, error: null }) },
  }, "order_fixture"), /ตรวจสอบและยกเลิกการชำระเงินไม่สำเร็จ/);
});

test("customer cancel stops before RPC on failed or uncertain payment cleanup", async () => {
  for (const result of [
    { data: null, error: { message: "network failure" } },
    { data: {}, error: null },
    { data: { cancelled: false, reason: "unknown" }, error: null },
  ]) {
    let cancelled = false;
    await assert.rejects(() => cancelFoodCustomerOrder({
      functions: { invoke: async () => result },
      rpc: async () => { cancelled = true; return { error: null }; },
    }, "order_fixture"), /ตรวจสอบและยกเลิกการชำระเงินไม่สำเร็จ/);
    assert.equal(cancelled, false);
  }
});

test("completed payment errors are read from Supabase's non-2xx response context", async () => {
  await assert.rejects(() => prepareFoodManualPayment({
    functions: { invoke: async () => ({ data: null, error: { context: Response.json({ error: "stripe_payment_already_completed" }, { status: 409 }) } }) },
  }, "order_fixture"), /กำลังยืนยันการชำระเงิน/);
});
