import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../../supabase/functions/food-stripe-checkout/index.ts", import.meta.url), "utf8");
const libSource = readFileSync(new URL("../../supabase/functions/food-stripe-checkout/_lib.ts", import.meta.url), "utf8");
const compile = (input) => ts.transpileModule(input, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 },
}).outputText;
const library = { exports: {} };
runInNewContext(compile(libSource), { module: library, exports: library.exports, URL });

// Run the real Edge Function handler with in-memory database and gateway
// boundaries. No Stripe, Supabase, account or transaction is contacted.
function checkoutHarness({
  existing = { checkout_session_id: "cs_existing", attempt: 3, status: "pending" },
  lookupError = null,
  onCreate = () => {},
  gatewayLookup = () => Response.json({ id: "cs_existing", status: "open", payment_status: "unpaid", url: "https://checkout.stripe.test/existing" }),
  stripeSecret = "sk_test_fixture_only",
  requestOrigin,
  testReturnOrigins,
} = {}) {
  const gatewayCalls = [];
  const writes = [];
  const order = {
    id: "order_fixture", order_number: "FIXTURE1", buyer_id: "buyer_fixture", store_id: "store_fixture",
    total: 100, status: "pending_acceptance", payment_status: "pending",
    payment_due_at: new Date(Date.now() + 300_000).toISOString(),
  };
  const ledger = { current: existing ? { ...existing, order_id: order.id } : null };
  const account = {
    stripe_account_id: "acct_fixture", livemode: /^(?:sk|rk)_live_/.test(stripeSecret), status: "ready",
    details_submitted: true, charges_enabled: true,
  };
  const admin = {
    auth: { getUser: async () => ({ data: { user: { id: "buyer_fixture" } }, error: null }) },
    rpc: async (name) => {
      assert.equal(name, "food_order_gp_quote");
      return { data: { gp_satang: 0, total_satang: 10_000 }, error: null };
    },
    from(table) {
      let mutation = null;
      const predicates = [];
      const matches = (row) => row && predicates.every((predicate) => predicate(row));
      const query = {
        select() { return query; },
        eq(key, value) { predicates.push((row) => row[key] === value); return query; },
        is(key, value) { predicates.push((row) => row[key] === value); return query; },
        in(key, values) { predicates.push((row) => values.includes(row[key])); return query; },
        or() { return query; },
        update(value) { mutation = value; return query; },
        async upsert(value, options) {
          assert.equal(table, "food_stripe_payments");
          if (!ledger.current || !options?.ignoreDuplicates) {
            ledger.current = { ...ledger.current, ...value };
            writes.push({ table, value });
          }
          return { error: null };
        },
        async maybeSingle() {
          if (table === "food_orders") {
            if (!mutation) return { data: { ...order }, error: null };
            if (!matches(order)) return { data: null, error: null };
            Object.assign(order, mutation);
            writes.push({ table, value: mutation });
            return { data: { id: order.id }, error: null };
          }
          if (table === "food_stripe_accounts") return { data: account, error: null };
          if (table === "food_stripe_payments") {
            if (mutation) {
              if (!matches(ledger.current)) return { data: null, error: null };
              Object.assign(ledger.current, mutation);
              writes.push({ table, value: mutation });
            }
            return { data: ledger.current ? { ...ledger.current } : null, error: lookupError };
          }
          assert.fail(`Unexpected table: ${table}`);
        },
      };
      return query;
    },
  };
  let handler;
  const env = {
    SUPABASE_URL: "https://supabase.test", SUPABASE_SERVICE_ROLE_KEY: "fixture-service-key",
    STRIPE_SECRET_KEY: stripeSecret,
    STRIPE_TEST_RETURN_ORIGINS: testReturnOrigins,
  };
  runInNewContext(compile(source), {
    exports: {},
    require: (path) => path === "./_lib.ts" ? library.exports : { createClient: () => admin },
    Deno: { env: { get: (name) => env[name] }, serve: (callback) => { handler = callback; } },
    Request, Response, URLSearchParams, btoa, console,
    fetch: async (url, init) => {
      gatewayCalls.push({ url, init });
      if (init?.method === "POST" && url.endsWith("/checkout/sessions")) {
        await onCreate({ ledger, order });
        return Response.json({ id: "cs_new", url: "https://checkout.stripe.test/new" });
      }
      assert.equal(url, "https://api.stripe.com/v1/checkout/sessions/cs_existing");
      return gatewayLookup();
    },
  });
  return {
    gatewayCalls,
    writes,
    ledger,
    async run() {
      const response = await handler(new Request("https://function.test", {
        method: "POST", headers: {
          Authorization: "Bearer fixture-user-token", "Content-Type": "application/json",
          ...(requestOrigin === undefined ? {} : { Origin: requestOrigin }),
        },
        body: JSON.stringify({ orderId: order.id }),
      }));
      return { status: response.status, body: await response.json() };
    },
  };
}

test("configured Sandbox Checkout returns stay in the preview Food route", async () => {
  const origin = "https://zoky-qa.example.test";
  const harness = checkoutHarness({ existing: null, requestOrigin: origin, testReturnOrigins: origin });
  assert.equal((await harness.run()).status, 200);
  const params = harness.gatewayCalls[0].init.body;
  assert.equal(params.get("success_url"), `${origin}/food/?order=FIXTURE1&stripe=success`);
  assert.equal(params.get("cancel_url"), `${origin}/food/?order=FIXTURE1&stripe=cancelled`);
});

test("a configured Sandbox origin never authorizes live Checkout", async () => {
  const origin = "https://zoky-qa.example.test";
  const harness = checkoutHarness({
    existing: null, stripeSecret: "sk_live_fixture_only", requestOrigin: origin, testReturnOrigins: origin,
  });
  const result = await harness.run();
  assert.equal(result.status, 403);
  assert.equal(result.body.error, "live_stripe_origin_required");
  assert.equal(harness.gatewayCalls.length, 0);
  assert.equal(harness.writes.length, 0);
});

test("live Checkout keeps its canonical return even when test origins are configured", async () => {
  const harness = checkoutHarness({
    existing: null, stripeSecret: "rk_live_fixture_only", requestOrigin: "https://food.wynos.online",
    testReturnOrigins: "https://zoky-qa.example.test",
  });
  assert.equal((await harness.run()).status, 200);
  assert.equal(harness.gatewayCalls[0].init.body.get("success_url"), "https://food.wynos.online/?order=FIXTURE1&stripe=success");
});

test("gateway lookup failures never create a second payable Checkout or overwrite the ledger", async () => {
  for (const gatewayLookup of [
    () => { throw new Error("network unavailable"); },
    () => Response.json({ error: { code: "api_error" } }, { status: 503 }),
    () => new Response("invalid JSON", { status: 200 }),
  ]) {
    const harness = checkoutHarness({ gatewayLookup });
    const result = await harness.run();
    assert.equal(result.status, 503);
    assert.equal(result.body.error, "stripe_session_lookup_failed");
    assert.equal(harness.gatewayCalls.length, 1);
    assert.equal(harness.writes.length, 0);
  }
});

test("database payment lookup failures never create a Checkout with incomplete history", async () => {
  const harness = checkoutHarness({ existing: null, lookupError: { message: "database unavailable" } });
  const result = await harness.run();
  assert.equal(result.status, 503);
  assert.equal(result.body.error, "payment_lookup_failed");
  assert.equal(harness.gatewayCalls.length, 0);
  assert.equal(harness.writes.length, 0);
});

test("a completed asynchronous Checkout waits for its payment webhook", async () => {
  const harness = checkoutHarness({ gatewayLookup: () => Response.json({ id: "cs_existing", status: "complete", payment_status: "unpaid" }) });
  const result = await harness.run();
  assert.equal(result.status, 409);
  assert.equal(result.body.error, "payment_processing");
  assert.equal(harness.gatewayCalls.length, 1);
  assert.equal(harness.writes.length, 0);
});

test("paid Checkout blocks another payment while the order webhook is pending", async () => {
  const harness = checkoutHarness({ gatewayLookup: () => Response.json({ id: "cs_existing", status: "complete", payment_status: "paid" }) });
  const result = await harness.run();
  assert.equal(result.status, 409);
  assert.equal(result.body.error, "payment_already_completed");
  assert.equal(harness.gatewayCalls.length, 1);
  assert.equal(harness.writes.length, 0);
});

test("an open Checkout is reused after pending or failed card attempts", async () => {
  for (const status of ["pending", "failed"]) {
    const harness = checkoutHarness({ existing: { checkout_session_id: "cs_existing", attempt: 3, status } });
    const result = await harness.run();
    assert.equal(result.status, 200);
    assert.equal(result.body.url, "https://checkout.stripe.test/existing");
    assert.equal(result.body.reused, true);
    assert.equal(harness.gatewayCalls.length, 1);
    assert.equal(harness.writes.length, 0);
  }
});

test("unknown states and open sessions without a URL cannot create a replacement", async () => {
  for (const session of [{ status: "unknown" }, { status: "open", url: null }]) {
    const harness = checkoutHarness({ gatewayLookup: () => Response.json(session) });
    const result = await harness.run();
    assert.equal(result.status, 503);
    assert.equal(harness.gatewayCalls.length, 1);
    assert.equal(harness.writes.length, 0);
  }
});

test("only confirmed expiry advances the idempotency attempt and records a new Checkout", async () => {
  const harness = checkoutHarness({ gatewayLookup: () => Response.json({ id: "cs_existing", status: "expired", payment_status: "unpaid" }) });
  const result = await harness.run();
  assert.equal(result.status, 200);
  assert.equal(result.body.reused, false);
  assert.equal(harness.gatewayCalls.length, 2);
  const create = harness.gatewayCalls[1];
  assert.equal(create.init.headers["Idempotency-Key"], "wynos-food-order_fixture-4");
  assert.equal(create.init.body.get("line_items[0][price_data][unit_amount]"), "10000");
  assert.equal(harness.writes[0].value.checkout_session_id, "cs_new");
  assert.equal(harness.writes[0].value.attempt, 4);
  assert.equal(harness.writes[1].value.stripe_checkout_session_id, "cs_new");
});

test("an order without an earlier Checkout keeps its original idempotency attempt", async () => {
  const harness = checkoutHarness({ existing: null });
  const result = await harness.run();
  assert.equal(result.status, 200);
  assert.equal(harness.gatewayCalls.length, 1);
  assert.equal(harness.gatewayCalls[0].init.headers["Idempotency-Key"], "wynos-food-order_fixture-1");
  assert.equal(harness.writes[0].value.attempt, 1);
});

test("an already-terminal ledger blocks Checkout even when the order snapshot was stale", async () => {
  for (const status of ["paid", "refunded"]) {
    const harness = checkoutHarness({ existing: { checkout_session_id: "cs_existing", attempt: 3, status } });
    const result = await harness.run();
    assert.equal(result.status, 409);
    assert.equal(result.body.error, "payment_already_completed");
    assert.equal(harness.gatewayCalls.length, 0);
    assert.equal(harness.writes.length, 0);
    assert.equal(harness.ledger.current.status, status);
  }
});

test("concurrent first-attempt webhooks cannot be overwritten by an insert retry", async () => {
  for (const status of ["paid", "refunded"]) {
    const harness = checkoutHarness({
      existing: null,
      onCreate: ({ ledger, order }) => {
        // Another request inserted the idempotent session, returned its URL,
        // and the authoritative webhook committed before this response arrived.
        ledger.current = { order_id: order.id, checkout_session_id: "cs_new", attempt: 1, status };
        order.payment_status = status;
      },
    });
    const result = await harness.run();
    assert.equal(harness.ledger.current.status, status);
    assert.equal(result.status, 409);
    assert.equal(result.body.error, "payment_state_changed");
    assert.equal(result.body.url, undefined);
    assert.equal(harness.writes.length, 0);
  }
});

test("expired-session replacements cannot regress a webhook's terminal ledger", async () => {
  for (const status of ["paid", "refunded"]) {
    const harness = checkoutHarness({
      gatewayLookup: () => Response.json({ id: "cs_existing", status: "expired", payment_status: "unpaid" }),
      onCreate: ({ ledger, order }) => {
        ledger.current.status = status;
        order.payment_status = status;
      },
    });
    const result = await harness.run();
    assert.equal(harness.ledger.current.status, status);
    assert.equal(harness.ledger.current.checkout_session_id, "cs_existing");
    assert.equal(result.status, 409);
    assert.equal(result.body.error, "payment_state_changed");
    assert.equal(result.body.url, undefined);
    assert.equal(harness.writes.length, 0);
  }
});

test("concurrent replacement preserves the newer mapping and does not expire its URL", async () => {
  const harness = checkoutHarness({
    gatewayLookup: () => Response.json({ id: "cs_existing", status: "expired", payment_status: "unpaid" }),
    onCreate: ({ ledger }) => {
      ledger.current.checkout_session_id = "cs_newer_attempt";
      ledger.current.attempt = 5;
    },
  });
  const result = await harness.run();
  assert.equal(result.status, 409);
  assert.equal(result.body.url, undefined);
  assert.equal(harness.ledger.current.checkout_session_id, "cs_newer_attempt");
  assert.equal(harness.ledger.current.attempt, 5);
  assert.equal(harness.ledger.current.status, "pending");
  assert.equal(harness.writes.length, 0);
  assert.equal(harness.gatewayCalls.length, 2);
});

test("a concurrent initial insert for the same pending session can finish without an overwrite", async () => {
  const harness = checkoutHarness({
    existing: null,
    onCreate: ({ ledger, order }) => {
      ledger.current = { order_id: order.id, checkout_session_id: "cs_new", attempt: 1, status: "pending" };
    },
  });
  const result = await harness.run();
  assert.equal(result.status, 200);
  assert.equal(result.body.sessionId, "cs_new");
  assert.equal(harness.writes.length, 1);
  assert.equal(harness.writes[0].table, "food_orders");
});
