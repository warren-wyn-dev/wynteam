import assert from "node:assert/strict";
import { createHmac, webcrypto } from "node:crypto";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext } from "node:vm";
import ts from "typescript";

const source = readFileSync(new URL("../../supabase/functions/stripe-webhook/index.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText;
const signingSecret = "whsec_synthetic_fee_fixture";
const created = 1_790_000_000;
function fixture({ charge = {}, rpcError = false, result = { recorded: true, reason: "full_fee_returned" }, results } = {}) {
  const calls = [], requests = [];
  let handler;
  const client = {
    async rpc(name, params) {
      calls.push({ name, params });
      if (name === "food_get_stripe_webhook_secret") return { data: "", error: null };
      if (name === "food_apply_stripe_event") return { data: true, error: null };
      if (name !== "food_record_stripe_fee_refund_event") throw new Error(`Unexpected RPC ${name}`);
      return { data: rpcError ? null : results?.shift() ?? result, error: rpcError ? { code: "synthetic_database_failure" } : null };
    },
    from() { throw new Error("Fee handler must not write tables or resolve customer metadata"); },
  };
  runInNewContext(compiled, {
    exports: {}, require: () => ({ createClient: () => client }), crypto: webcrypto, TextEncoder, Response, Date, btoa,
    console: { error() {}, warn() {} },
    Deno: { env: { get: name => ({ SUPABASE_URL: "https://synthetic.invalid", SUPABASE_SERVICE_ROLE_KEY: "synthetic-key", STRIPE_SECRET_KEY: "sk_test_synthetic", STRIPE_WEBHOOK_SECRET: signingSecret })[name] }, serve: value => { handler = value; } },
    fetch: async (url, init) => {
      requests.push({ url, method: init.method ?? "GET", account: init.headers["Stripe-Account"] });
      return Response.json({ id: "ch_synthetic", application_fee: "fee_synthetic", payment_intent: "pi_pinned", currency: "thb", livemode: false, ...charge });
    },
  });
  const event = { id: "evt_synthetic_fee", type: "application_fee.refunded", created, livemode: false,
    data: { object: { object: "application_fee", id: "fee_synthetic", account: "acct_original", charge: "ch_synthetic", amount: 100, amount_refunded: 100, currency: "thb", livemode: false,
      metadata: { order_id: "wrong_order", payment_intent: "pi_attacker" } } } };
  return { calls, requests, event, async run(value = event, validSignature = true) {
    const raw = JSON.stringify(value), timestamp = String(Math.floor(Date.now() / 1000));
    const signature = createHmac("sha256", signingSecret).update(`${timestamp}.${raw}`).digest("hex");
    return handler(new Request("https://synthetic.invalid/webhook", { method: "POST", headers: { "stripe-signature": `t=${timestamp},v1=${validSignature ? signature : "invalid"}` }, body: raw }));
  } };
}
const feeWrites = f => f.calls.filter(call => call.name === "food_record_stripe_fee_refund_event");

test("a verified platform fee event uses its original charge/account and ignores customer metadata", async () => {
  const f = fixture();
  assert.equal((await f.run()).status, 200);
  assert.deepEqual(f.requests, [{ url: "https://api.stripe.com/v1/charges/ch_synthetic", method: "GET", account: "acct_original" }]);
  assert.deepEqual(JSON.parse(JSON.stringify(feeWrites(f)[0].params)), {
    p_event_id: "evt_synthetic_fee", p_stripe_account_id: "acct_original", p_payment_intent_id: "pi_pinned", p_fee_id: "fee_synthetic",
    p_fee_amount_satang: 100, p_refunded_satang: 100, p_currency: "thb", p_livemode: false,
    p_refunded_at: new Date(created * 1000).toISOString(),
  });
});

test("bad signatures cannot fetch a charge or reach the financial RPC", async () => {
  const f = fixture();
  assert.equal((await f.run(f.event, false)).status, 400);
  assert.equal(f.requests.length, 0); assert.equal(feeWrites(f).length, 0);
});

test("cross-environment and conflicting connected-account events are ignored before fetching", async () => {
  for (const alter of [f => { f.event.livemode = true; }, f => { f.event.data.object.livemode = true; }, f => { f.event.account = "acct_other"; }]) {
    const f = fixture(); alter(f);
    assert.equal((await f.run()).status, 200);
    assert.equal(f.requests.length, 0); assert.equal(feeWrites(f).length, 0);
  }
});

test("unsafe amounts, invalid dates and non-THB fee events cannot reach the writer", async () => {
  for (const alter of [f => { f.event.data.object.amount = Number.MAX_SAFE_INTEGER + 1; }, f => { f.event.data.object.amount_refunded = -1; },
    f => { f.event.data.object.amount_refunded = 101; }, f => { f.event.data.object.amount = 100.5; },
    f => { f.event.data.object.currency = "usd"; }, f => { f.event.created = 1e15; },
    f => { f.event.data.object.object = "refund"; }, f => { delete f.event.data.object.livemode; }]) {
    const f = fixture(); alter(f);
    assert.equal((await f.run()).status, 400);
    assert.equal(f.requests.length, 0); assert.equal(feeWrites(f).length, 0);
  }
});

test("other signed event types cannot request a fee reversal or provider mutation", async () => {
  for (const type of ["application_fee.created", "application_fee.refund.updated", "refund.updated"]) {
    const f = fixture(); f.event.type = type; f.event.data.object.metadata = {};
    assert.equal((await f.run()).status, 200);
    assert.equal(feeWrites(f).length, 0); assert.equal(f.requests.length, 0);
    const receipt = f.calls.find(call => call.name === "food_apply_stripe_event");
    assert.equal(receipt.params.p_state, "noop");
  }
});

test("a mismatched charge, fee identity, currency or environment remains retryable without a receipt claim", async () => {
  for (const charge of [{ id: "ch_other" }, { application_fee: "fee_other" }, { payment_intent: null }, { currency: "usd" }, { livemode: true }]) {
    const f = fixture({ charge });
    assert.equal((await f.run()).status, 500);
    assert.equal(feeWrites(f).length, 0);
    assert.ok(f.calls.every(call => call.name === "food_get_stripe_webhook_secret"));
  }
});

test("database failures return 500 so the same signed event can be retried atomically", async () => {
  const f = fixture({ rpcError: true });
  assert.equal((await f.run()).status, 500);
  assert.equal((await f.run()).status, 500);
  assert.equal(feeWrites(f).length, 2);
  assert.ok(feeWrites(f).every(call => call.params.p_event_id === f.event.id));
  assert.ok(f.calls.every(call => !call.name.includes("claim")));
});

test("partial fee events preserve the cumulative receipt amount without inferring a full return", async () => {
  const f = fixture({ result: { recorded: false, reason: "partial_fee_reconciliation_required" } });
  f.event.data.object.amount_refunded = 40;
  const response = await f.run();
  assert.equal(response.status, 200);
  assert.equal((await response.json()).reason, "partial_fee_reconciliation_required");
  assert.equal(feeWrites(f)[0].params.p_refunded_satang, 40);
  assert.ok(f.requests.every(request => request.method === "GET"));
});

test("duplicate receipts complete without order mutations or provider writes", async () => {
  const f = fixture({ result: { recorded: false, reason: "duplicate" } });
  assert.equal((await f.run()).status, 200);
  assert.equal(feeWrites(f).length, 1);
  assert.ok(f.requests.every(request => request.method === "GET"));
});

test("an unmapped fee event retries successfully after its payment row becomes available", async () => {
  const f = fixture({ results: [{ recorded: false, reason: "unmapped" }, { recorded: true, reason: "full_fee_returned" }] });
  assert.equal((await f.run()).status, 500);
  const recovered = await f.run();
  assert.equal(recovered.status, 200);
  assert.equal((await recovered.json()).recorded, true);
  assert.equal(feeWrites(f).length, 2);
  assert.deepEqual(feeWrites(f)[0].params, feeWrites(f)[1].params);
  assert.ok(f.calls.every(call => !call.name.includes("claim")));
  assert.equal(f.requests.length, 2);
  assert.ok(f.requests.every(request => request.method === "GET"));
});
