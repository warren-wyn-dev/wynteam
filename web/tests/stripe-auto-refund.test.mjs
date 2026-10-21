import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { test } from "node:test";
import ts from "typescript";

const input = readFileSync(new URL("../../supabase/functions/food-auto-refund/_lib.ts", import.meta.url), "utf8");
const libModule = { exports: {} };
runInNewContext(ts.transpileModule(input, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText,
  { module: libModule, exports: libModule.exports, URLSearchParams, AbortSignal, btoa });
const { processRefund } = libModule.exports;
const target = { orderId: "order1", paymentIntent: "pi_test1", account: "acct_test1", amount: 3000, fee: 300, livemode: false, refundId: null };
const refund = { id: "re_test1", payment_intent: "pi_test1", amount: 3000, currency: "thb", status: "succeeded", charge: "ch_test1" };
function gateway(responses) {
  const calls = [];
  return { calls, request: async (url, init) => {
    calls.push({ url, init });
    const next = responses.shift();
    if (next instanceof Error) throw next;
    assert.ok(next, "Unexpected request");
    return next instanceof Response ? next : Response.json(next);
  } };
}
const feeResponses = () => [{ application_fee: "fee_test1" }, { account: "acct_test1", charge: "ch_test1", currency: "thb", amount: 300, amount_refunded: 300 }];

test("automatic refund returns the full payment and verifies GP on the platform account", async () => {
  const g = gateway([refund, ...feeResponses()]);
  const result = await processRefund(target, "sk_test_fixture", g.request);
  assert.equal(result.status, "succeeded");
  assert.equal(g.calls[0].init.body.get("refund_application_fee"), "true");
  assert.equal(g.calls[0].init.body.has("amount"), false);
  assert.equal(g.calls[0].init.headers["Stripe-Account"], target.account);
  assert.equal(g.calls[2].init.headers["Stripe-Account"], undefined);
});
test("retries use the exact immutable idempotency key and parameters", async () => {
  const g = gateway([{ ...refund, status: "pending" }, { ...refund, status: "pending" }]);
  await processRefund(target, "sk_test_fixture", g.request);
  await processRefund(target, "sk_test_fixture", g.request);
  assert.equal(g.calls[0].init.headers["Idempotency-Key"], "wynos-refund-order1");
  assert.equal(g.calls[0].init.body.toString(), g.calls[1].init.body.toString());
});
test("pending refunds do not claim GP has been returned", async () => {
  const g = gateway([{ ...refund, status: "pending" }]);
  assert.equal((await processRefund(target, "sk_test_fixture", g.request)).status, "pending");
  assert.equal(g.calls.length, 1);
});
test("known refunds are polled without creating another refund", async () => {
  const g = gateway([refund, ...feeResponses()]);
  await processRefund({ ...target, refundId: "re_test1" }, "sk_test_fixture", g.request);
  assert.equal(g.calls[0].init.method, "GET");
  assert.equal(g.calls[0].init.body, undefined);
});
test("live/test mismatch refuses all provider calls", async () => {
  const g = gateway([]);
  await assert.rejects(processRefund(target, "sk_live_fixture", g.request), /environment_mismatch/);
  assert.equal(g.calls.length, 0);
});
test("wrong payment, currency or partial refund cannot complete the job", async () => {
  for (const wrong of [{ payment_intent: "pi_other" }, { amount: 1000 }, { currency: "usd" }]) {
    const g = gateway([{ ...refund, ...wrong }]);
    await assert.rejects(processRefund(target, "sk_test_fixture", g.request), /response_mismatch/);
  }
});
test("a payment refund without the GP return is not recorded as complete", async () => {
  const fee = feeResponses(); fee[1].amount_refunded = 0;
  const g = gateway([refund, ...fee]);
  await assert.rejects(processRefund(target, "sk_test_fixture", g.request), /fee_not_returned/);
});
test("zero GP requires no application fee call", async () => {
  const g = gateway([refund]);
  await processRefund({ ...target, fee: 0 }, "sk_test_fixture", g.request);
  assert.equal(g.calls.length, 1);
  assert.equal(g.calls[0].init.body.has("refund_application_fee"), false);
});
test("provider failures propagate for a durable retry", async () => {
  const g = gateway([new Response("unavailable", { status: 503 })]);
  await assert.rejects(processRefund(target, "sk_test_fixture", g.request), /stripe_transient/);
});

const workerInput = readFileSync(new URL("../../supabase/functions/food-auto-refund/index.ts", import.meta.url), "utf8");
function worker({ authorized = true, providerStatus = "succeeded", finishOk = true, providerError = false } = {}) {
  const calls = []; let handler;
  const admin = {
    rpc: async (name, args) => {
      calls.push({ name, args });
      if (name === "food_auto_refund_authorized") return { data: authorized };
      if (name === "food_claim_auto_refunds") return { data: [{ order_id: "order1", lease_token: "lease1", refund_id: null }] };
      if (name === "food_finish_auto_refund") return { data: finishOk };
      assert.fail(name);
    },
    from(table) {
      const q = { select: () => q, eq: () => q, maybeSingle: async () => ({ data: table === "food_orders"
        ? { id: "order1", status: "cancelled", payment_status: "paid", payment_provider: "stripe", stripe_payment_intent_id: "pi_test1", total: 30 }
        : { stripe_account_id: "acct_test1", livemode: false, amount_satang: 3000, application_fee_satang: 300 } }) };
      return q;
    },
  };
  runInNewContext(ts.transpileModule(workerInput, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText, {
    exports: {}, Response, console: { warn() {} },
    Deno: { env: { get: (name) => ({ SUPABASE_URL: "https://qa.supabase.co", SUPABASE_SERVICE_ROLE_KEY: "fixture", STRIPE_SECRET_KEY: "sk_test_fixture" })[name] }, serve: (cb) => { handler = cb; } },
    require: (path) => path.includes("_lib") ? { processRefund: async () => {
      calls.push({ name: "provider" }); if (providerError) throw Error("stripe_transient");
      return { id: "re_test1", status: providerStatus };
    } } : { createClient: () => admin },
  });
  return { calls, run: async (key = "fixture-cron-token") => handler(new Request("https://worker.test", { method: "POST", headers: key ? { "x-wynos-cron-key": key } : {} })) };
}
test("worker denies missing or wrong scheduler credentials before claiming jobs", async () => {
  const missing = worker(); assert.equal((await missing.run("")).status, 401); assert.equal(missing.calls.length, 0);
  const wrong = worker({ authorized: false }); assert.equal((await wrong.run()).status, 401);
  assert.equal(wrong.calls.some((x) => x.name === "food_claim_auto_refunds"), false);
});
test("worker persists verified success through the leased database completion", async () => {
  const h = worker(); const response = await h.run();
  assert.equal((await response.json()).completed, 1);
  const finish = h.calls.find((x) => x.name === "food_finish_auto_refund");
  assert.equal(finish.args.p_lease, "lease1"); assert.equal(finish.args.p_outcome, "succeeded");
});
test("worker preserves provider pending status", async () => {
  const h = worker({ providerStatus: "pending" }); await h.run();
  assert.equal(h.calls.find((x) => x.name === "food_finish_auto_refund").args.p_outcome, "pending");
});
test("worker retains a durable retry after a provider failure", async () => {
  const h = worker({ providerError: true }); await h.run();
  assert.equal(h.calls.find((x) => x.name === "food_finish_auto_refund").args.p_outcome, "retry");
});
test("failed database completion never reports refund complete", async () => {
  const h = worker({ finishOk: false }); const response = await h.run();
  assert.equal((await response.json()).completed, 0);
});
