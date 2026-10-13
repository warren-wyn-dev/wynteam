import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";
import { test } from "node:test";
import { runInNewContext } from "node:vm";

import { applicationFeeSatang } from "../../supabase/functions/food-stripe-checkout/_lib.ts";

// Run the actual handler. Auth/SQL/Stripe boundaries are synthetic; unknown
// URLs throw inside the mock so no test can send network traffic accidentally.
const raw = readFileSync(new URL("../../supabase/functions/food-stripe-checkout/index.ts", import.meta.url), "utf8");
const source = stripTypeScriptTypes(raw.replace(/^import .*;\s*$/gm, ""));

async function runCheckout({ oldSession = { id: "cs_old", status: "open", payment_status: "unpaid", url: "https://fixture.invalid/old" }, networkError = false, providerError = false, ledgerError = false, ledgerStatus = "pending" } = {}) {
  const order = { id: "order_test", order_number: "WF_test", buyer_id: "buyer_test", store_id: "store_test", total: 100, status: "pending_acceptance", payment_status: "pending", payment_due_at: new Date(Date.now() + 600000).toISOString() };
  const account = { stripe_account_id: "acct_test", livemode: false, status: "ready", details_submitted: true, charges_enabled: true };
  const payment = { order_id: order.id, checkout_session_id: "cs_old", attempt: 1, status: ledgerStatus };
  const requests = [];
  const writes = [];
  const client = {
    auth: { getUser: async () => ({ data: { user: { id: order.buyer_id } }, error: null }) },
    rpc: async (name) => {
      assert.equal(name, "food_order_gp_quote");
      return { data: { gp_satang: 0, total_satang: 10000 }, error: null };
    },
    from(table) {
      let patch = null;
      const filters = [];
      const result = () => {
        if (table === "food_stripe_payments" && ledgerError) return { data: null, error: { code: "synthetic_read_failure" } };
        const target = table === "food_orders" ? order : table === "food_stripe_accounts" ? account : payment;
        if (!patch) return { data: { ...target }, error: null };
        if (!filters.every(([key, value]) => target[key] === value)) return { data: null, error: null };
        Object.assign(target, patch);
        writes.push({ table, patch: { ...patch } });
        return { data: { id: order.id }, error: null };
      };
      const query = {
        select: () => query,
        eq: (key, value) => { filters.push([key, value]); return query; },
        in: () => query,
        or: () => query,
        update: (value) => { patch = value; return query; },
        upsert: (value) => { patch = value; return query; },
        maybeSingle: async () => result(),
        then: (resolve, reject) => Promise.resolve().then(result).then(resolve, reject),
      };
      return query;
    },
  };
  let handler;
  const syntheticEnv = { SUPABASE_URL: "https://mock.invalid", SUPABASE_SERVICE_ROLE_KEY: "synthetic-service-key", STRIPE_SECRET_KEY: "sk_test_synthetic_fixture" };
  runInNewContext(source, {
    createClient: () => client, applicationFeeSatang,
    Deno: { env: { get: (name) => syntheticEnv[name] }, serve: (value) => { handler = value; } },
    fetch: async (url, init) => {
      requests.push({ url, init });
      if (url === "https://api.stripe.com/v1/checkout/sessions/cs_old") {
        if (networkError) throw new Error("synthetic_network_failure");
        if (providerError) return Response.json({ error: { code: "synthetic_provider_unavailable" } }, { status: 503 });
        return Response.json(oldSession);
      }
      if (url === "https://api.stripe.com/v1/checkout/sessions" && init.method === "POST") {
        return Response.json({ id: "cs_new", url: "https://fixture.invalid/new" });
      }
      throw new Error("unexpected_synthetic_provider_request");
    },
    Response, Request, URLSearchParams, Date, btoa,
    console: { error: () => {}, warn: () => {} },
  });
  const response = await handler(new Request("https://mock.invalid/checkout", {
    method: "POST", headers: { Authorization: "Bearer synthetic-session", "Content-Type": "application/json" },
    body: JSON.stringify({ orderId: order.id }),
  }));
  return { code: response.status, payload: await response.json(), requests, writes };
}

test("actual handler reuses a known open Checkout without another payment or ledger write", async () => {
  const result = await runCheckout();
  assert.equal(result.code, 200);
  assert.equal(result.payload.reused, true);
  assert.equal(result.payload.sessionId, "cs_old");
  assert.equal(result.requests.length, 1);
  assert.equal(result.writes.length, 0);
});

test("network or provider retrieval failure returns 503 without another Checkout or write", async () => {
  for (const options of [{ networkError: true }, { providerError: true }]) {
    const result = await runCheckout(options);
    assert.equal(result.code, 503);
    assert.equal(result.requests.length, 1);
    assert.equal(result.writes.length, 0);
  }
});

test("unknown, incomplete and asynchronous sessions cannot create a second payable Checkout", async () => {
  for (const oldSession of [
    { status: "complete", payment_status: "unpaid" },
    { status: "open", payment_status: "unpaid" },
    { status: "unknown", payment_status: "unpaid" },
    { status: "open", url: "https://fixture.invalid/unknown-payment" },
    { status: "expired" },
  ]) {
    const result = await runCheckout({ oldSession });
    assert.equal(result.code, 503);
    assert.equal(result.requests.length, 1);
    assert.equal(result.writes.length, 0);
  }
});

test("positively expired unpaid session alone permits the next idempotent attempt", async () => {
  const result = await runCheckout({ oldSession: { status: "expired", payment_status: "unpaid" } });
  assert.equal(result.code, 200);
  assert.equal(result.payload.reused, false);
  assert.equal(result.requests.length, 2);
  assert.equal(result.requests[1].init.headers["Idempotency-Key"], "wynos-food-order_test-2");
  assert.equal(result.requests[1].init.headers["Stripe-Account"], "acct_test");
  assert.equal(result.writes[0].patch.checkout_session_id, "cs_new");
  assert.equal(result.writes[0].patch.attempt, 2);
});

test("paid provider session or settled ledger cannot start another payment", async () => {
  for (const status of ["complete", "open"]) {
    const remotePaid = await runCheckout({ oldSession: { status, payment_status: "paid", url: "https://fixture.invalid/paid" } });
    assert.equal(remotePaid.code, 409);
    assert.equal(remotePaid.requests.length, 1);
    assert.equal(remotePaid.writes.length, 0);
  }
  for (const ledgerStatus of ["paid", "refunded"]) {
    const result = await runCheckout({ ledgerStatus });
    assert.equal(result.code, 409);
    assert.equal(result.requests.length, 0);
    assert.equal(result.writes.length, 0);
  }
});

test("ledger read failure cannot be interpreted as the absence of a Checkout", async () => {
  const result = await runCheckout({ ledgerError: true });
  assert.equal(result.code, 503);
  assert.equal(result.requests.length, 0);
  assert.equal(result.writes.length, 0);
});

test("a failed ledger still verifies its prior Checkout before another attempt", async () => {
  const result = await runCheckout({ ledgerStatus: "failed", networkError: true });
  assert.equal(result.code, 503);
  assert.equal(result.requests.length, 1);
  assert.equal(result.writes.length, 0);
});
