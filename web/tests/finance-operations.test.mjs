import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { runInNewContext } from "node:vm";
import { test } from "node:test";
import ts from "typescript";
function load(path, globals = {}) {
  const result = { exports: {} };
  runInNewContext(ts.transpileModule(readFileSync(new URL(path, import.meta.url), "utf8"), { compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022 } }).outputText,
    { exports: result.exports, module: result, URLSearchParams, AbortSignal, btoa, Intl, Date, ...globals });
  return result.exports;
}
const math = load("../../supabase/functions/food-finance-sync/_lib.ts");
const docs = load("../lib/merchant-finance-operations.ts");
const refund = load("../../supabase/functions/food-finance-refund/_lib.ts");
test("processor fees exclude GP and reject incomplete fee breakdowns", () => {
  assert.equal(math.processorFee({ fee: 500, fee_details: [{ type: "stripe_fee", amount: 200 }, { type: "application_fee", amount: 300 }] }), 200);
  assert.equal(math.processorFee({ fee: 500, fee_details: [{ type: "stripe_fee", amount: 200 }] }), null);
  assert.equal(math.processorFee({ fee: 0, fee_details: [] }), 0);
  assert.equal(math.processorFee({ fee: 500 }), null);
});
test("Bangkok 00:00 closes previous day and 08:00 starts initiation", () => {
  const midnight = math.bangkokPayoutWindow(new Date("2026-10-21T17:00:00Z"));
  assert.equal(midnight.businessDay, "2026-10-21"); assert.equal(midnight.cutoff, "2026-10-21T17:00:00.000Z"); assert.equal(midnight.mayInitiate, false);
  assert.equal(math.bangkokPayoutWindow(new Date("2026-10-22T00:59:59Z")).mayInitiate, false);
  assert.equal(math.bangkokPayoutWindow(new Date("2026-10-22T01:00:00Z")).mayInitiate, true);
});
test("statements escape identity/order fields and label unknown fees honestly", () => {
  const html = docs.statementHtml({ issuer: { name: '<script>alert(1)</script>', address: '"address"' }, document_number: "ST1", store_name: "<img src=x>", from: "2026-10-21", to: "2026-10-21", generated_at: "2026-10-22",
    orders: [{ order_number: "<iframe>", paid_satang: 3000, gp_satang: 300, processor_fee_satang: null, refunded_satang: 0, gp_refunded_satang: 0, net_satang: null }] });
  assert.doesNotMatch(html, /<script>|<iframe>|<img src=x>/); assert.match(html, /รอยืนยัน/); assert.match(html, /ไม่ใช่ใบกำกับภาษี VAT/);
});
test("CSV exports resist spreadsheet formula injection", () => {
  const csv = docs.operationsCsv({ orders: [{ order_number: '=HYPERLINK("bad")' }] });
  assert.match(csv, /'=HYPERLINK/);
});
const job = { request_id: "request1", order_id: "order1", lease: "lease1", refund_id: null, food_satang: 1000, delivery_satang: 0, gp_satang: 100, payment_intent_id: "pi_test", stripe_account_id: "acct_test", livemode: false };
function gateway(rows) { const calls = []; return { calls, request: async (url, init) => { calls.push({ url, init }); const next = rows.shift(); assert.ok(next, "Unexpected provider call"); return next instanceof Response ? next : Response.json(next); } }; }
const paymentRefund = { id: "re_test", payment_intent: "pi_test", amount: 1000, currency: "thb", status: "succeeded", charge: "ch_test" };
const gpResults = () => [{ payment_intent: "pi_test", application_fee: "fee_test" }, { account: "acct_test", charge: "ch_test", currency: "thb" }, { id: "fr_test", fee: "fee_test", amount: 100 }];
test("partial refunds explicitly return item value and corresponding GP, not delivery-based proportional GP", async () => {
  const g = gateway([paymentRefund, ...gpResults()]); const result = await refund.executeRefund(job, "sk_test_fixture", g.request);
  assert.equal(result.state, "succeeded"); assert.equal(g.calls[0].init.body.get("amount"), "1000");
  assert.equal(g.calls[0].init.body.has("refund_application_fee"), false);
  assert.equal(g.calls[3].init.body.get("amount"), "100"); assert.equal(g.calls[3].init.headers["Stripe-Account"], undefined);
});
test("pending customer refunds do not refund GP prematurely", async () => {
  const g = gateway([{ ...paymentRefund, status: "pending" }]);
  assert.equal((await refund.executeRefund(job, "sk_test_fixture", g.request)).state, "pending"); assert.equal(g.calls.length, 1);
});
test("delivery-only remaining refunds do not return GP twice", async () => {
  const g = gateway([paymentRefund]);
  await refund.executeRefund({ ...job, food_satang: 0, delivery_satang: 1000, gp_satang: 0 }, "sk_test_fixture", g.request); assert.equal(g.calls.length, 1);
});
test("wrong account mode and unexpected refund amounts fail closed", async () => {
  await assert.rejects(refund.executeRefund(job, "sk_live_fixture", gateway([]).request), /invalid_refund_job/);
  await assert.rejects(refund.executeRefund(job, "sk_test_fixture", gateway([{ ...paymentRefund, amount: 2000 }]).request), /response_mismatch/);
});
test("known refunds are retrieved and GP retries use one fixed request key", async () => {
  const g = gateway([paymentRefund, ...gpResults()]);
  await refund.executeRefund({ ...job, refund_id: "re_test" }, "sk_test_fixture", g.request);
  assert.equal(g.calls[0].init.method, "GET"); assert.equal(g.calls[3].init.headers["Idempotency-Key"], "zoky-refund-request1-gp");
});
test("unrelated application fees cannot be returned", async () => {
  const results = gpResults(); results[1].account = "acct_other";
  await assert.rejects(refund.executeRefund(job, "sk_test_fixture", gateway([paymentRefund, ...results]).request), /application_fee_mismatch/);
});
test("lost payment and GP responses recover by request metadata without another POST", async () => {
  const payment = { ...paymentRefund, metadata: { wynos_refund_request_id: job.request_id } };
  const fees = gpResults(); const returned = { ...fees[2], metadata: { wynos_refund_request_id: job.request_id } };
  const g = gateway([{ data: [payment], has_more: false }, fees[0], fees[1], { data: [returned], has_more: false }]);
  const result = await refund.executeRefund({ ...job, attempts: 2 }, "sk_test_fixture", g.request);
  assert.equal(result.state, "succeeded"); assert.equal(g.calls.some((c) => c.init.method === "POST"), false);
});
test("old untraceable requests cannot create a new refund after the idempotency window", async () => {
  const g = gateway([{ data: [], has_more: false }]);
  await assert.rejects(refund.executeRefund({ ...job, attempts: 2, created_at: "2020-01-01T00:00:00Z" }, "sk_test_fixture", g.request), /reconciliation_required/);
  assert.equal(g.calls.some((c) => c.init.method === "POST"), false);
});
