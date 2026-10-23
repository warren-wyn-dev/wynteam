import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  adoptExisting,
  awaitingCustomer,
  type Context,
  isTransient,
  type Job,
  processJob,
  refundIdempotencyKey,
  runWorker,
  stripeLivemode,
} from "./_lib.ts";

// Synthetic ids only; no real Stripe objects or customer data.
type Call = { method: string; url: string; headers: Record<string, string>; body: string };
type Reply = { status?: number; body?: unknown } | "network";

function mockStripe(replies: Reply[]) {
  const calls: Call[] = [];
  const fetch = (input: string, init?: RequestInit) => {
    calls.push({
      method: String(init?.method ?? "GET"),
      url: input,
      headers: (init?.headers ?? {}) as Record<string, string>,
      body: typeof init?.body === "string" ? init.body : "",
    });
    const reply = replies.shift();
    if (!reply) throw new Error(`unexpected Stripe call ${init?.method} ${input}`);
    if (reply === "network") return Promise.reject(new TypeError("network down"));
    return Promise.resolve(new Response(JSON.stringify(reply.body ?? {}), { status: reply.status ?? 200 }));
  };
  const ctx: Context = { secret: "sk_test_synthetic", livemode: false, fetch };
  return { ctx, calls, replies };
}

function refundJob(overrides: Partial<Job> = {}): Job {
  return {
    job_id: "00000000-0000-0000-0000-00000000j001",
    kind: "refund",
    status: "queued",
    reason: "store_cancelled",
    order_id: "00000000-0000-0000-0000-00000000o001",
    attempts: 1,
    requeue_count: 0,
    checkout_session_id: "cs_test_1",
    payment_intent_id: "pi_test_1",
    stripe_refund_id: null,
    stripe_account_id: "acct_test_1",
    livemode: false,
    amount_satang: 12000,
    application_fee_satang: 0,
    order_status: "cancelled",
    order_payment_status: "paid",
    order_payment_provider: "stripe",
    order_refund_status: "pending",
    payment_method: "promptpay",
    ...overrides,
  };
}

function expireJob(overrides: Partial<Job> = {}): Job {
  return refundJob({ kind: "expire_checkout", reason: "order_cancelled", payment_intent_id: null,
    order_payment_status: "pending", order_payment_provider: null, order_refund_status: "none", ...overrides });
}

Deno.test("secret mode detection", () => {
  assertEquals(stripeLivemode("sk_live_x"), true);
  assertEquals(stripeLivemode("rk_test_x"), false);
  assertEquals(stripeLivemode("pk_live_x"), null);
});

Deno.test("idempotency key: per job, new key only after a merchant requeue", () => {
  assertEquals(refundIdempotencyKey("J", 0), "wynos-refund-job-J");
  assertEquals(refundIdempotencyKey("J", 2), "wynos-refund-job-J-r2");
});

Deno.test("error classification", () => {
  for (const s of [0, 401, 409, 429, 500, 503]) assert(isTransient(s), `transient ${s}`);
  for (const s of [400, 402, 403, 404]) assert(!isTransient(s), `permanent ${s}`);
});

Deno.test("refund: lists first, then creates a full refund on the paying account", async () => {
  const { ctx, calls } = mockStripe([
    { body: { data: [{ id: "re_old", status: "failed", amount: 12000 }] } },
    { body: { id: "re_new", status: "succeeded", amount: 12000 } },
  ]);
  const out = await processJob(refundJob(), ctx);
  assertEquals(out, { outcome: "refunded", refundId: "re_new", feeRefunded: false });
  assertEquals(calls.length, 2);
  assertEquals(calls[0].method, "GET");
  assert(calls[0].url.endsWith("/v1/refunds?payment_intent=pi_test_1&limit=100"));
  assertEquals(calls[1].method, "POST");
  assert(calls[1].url.endsWith("/v1/refunds"));
  for (const c of calls) assertEquals(c.headers["Stripe-Account"], "acct_test_1");
  assertEquals(calls[1].headers["Idempotency-Key"], "wynos-refund-job-00000000-0000-0000-0000-00000000j001");
  const body = new URLSearchParams(calls[1].body);
  assertEquals(body.get("payment_intent"), "pi_test_1");
  assertEquals(body.get("reason"), "requested_by_customer");
  assertEquals(body.get("amount"), null, "never a partial amount");
  assertEquals(body.get("refund_application_fee"), null, "no GP, no fee refund");
  assertEquals(body.get("metadata[wynos_refund_job_id]"), "00000000-0000-0000-0000-00000000j001");
});

Deno.test("refund: GP > 0 asks Stripe to return the application fee", async () => {
  const { ctx, calls } = mockStripe([
    { body: { data: [] } },
    { body: { id: "re_fee", status: "pending" } },
  ]);
  const out = await processJob(refundJob({ application_fee_satang: 1410 }), ctx);
  // Pending PromptPay refund: waiting for the customer; GP not booked yet.
  assertEquals(out, { outcome: "refund_requested", refundId: "re_fee", awaitingCustomer: true });
  assertEquals(new URLSearchParams(calls[1].body).get("refund_application_fee"), "true");
});

Deno.test("refund: an existing refund is adopted, never a second one", async () => {
  const { ctx, calls } = mockStripe([
    { body: { data: [{ id: "re_prev", status: "pending", amount: 12000, metadata: { wynos_refund_job_id: "00000000-0000-0000-0000-00000000j001" } }] } },
  ]);
  const out = await processJob(refundJob({ application_fee_satang: 500 }), ctx);
  assertEquals(out, { outcome: "refund_requested", refundId: "re_prev", awaitingCustomer: true });
  assertEquals(calls.length, 1);
});

Deno.test("refund: a refund made outside WYNOS is adopted without claiming the fee", () => {
  const out = adoptExisting([{ id: "re_dash", status: "succeeded", amount: 12000 }], 12000, "J", 500);
  assertEquals(out, { outcome: "refunded", refundId: "re_dash", feeRefunded: false });
});

Deno.test("refund: partial refund already present needs an operator", () => {
  const out = adoptExisting([{ id: "re_part", status: "succeeded", amount: 5000 }], 12000, "J", 0);
  assertEquals(out, { outcome: "needs_attention", errorCode: "partial_refund_exists" });
});

Deno.test("refund: charge_already_refunded re-lists and adopts", async () => {
  const { ctx, calls } = mockStripe([
    { body: { data: [] } },
    { status: 400, body: { error: { code: "charge_already_refunded" } } },
    { body: { data: [{ id: "re_race", status: "succeeded", amount: 12000 }] } },
  ]);
  const out = await processJob(refundJob(), ctx);
  assertEquals(out, { outcome: "refunded", refundId: "re_race", feeRefunded: false });
  assertEquals(calls.length, 3);
});

Deno.test("refund: transient errors retry, permanent errors fail", async () => {
  let m = mockStripe(["network"]);
  assertEquals(await processJob(refundJob(), m.ctx), { outcome: "retry", errorCode: "network_error" });
  m = mockStripe([{ body: { data: [] } }, { status: 500, body: { error: { type: "api_error" } } }]);
  assertEquals(await processJob(refundJob(), m.ctx), { outcome: "retry", errorCode: "refund_create_500" });
  m = mockStripe([{ body: { data: [] } }, { status: 429, body: { error: { code: "rate_limit" } } }]);
  assertEquals((await processJob(refundJob(), m.ctx)).outcome, "retry");
  m = mockStripe([{ body: { data: [] } }, { status: 400, body: { error: { code: "balance_insufficient" } } }]);
  assertEquals(await processJob(refundJob(), m.ctx), { outcome: "failed", errorCode: "balance_insufficient" });
  m = mockStripe([{ status: 404, body: { error: { code: "resource_missing" } } }]);
  assertEquals(await processJob(refundJob(), m.ctx), { outcome: "failed", errorCode: "resource_missing" });
});

Deno.test("refund: livemode guard and missing account make no Stripe call", async () => {
  const m = mockStripe([]);
  assertEquals(await processJob(refundJob({ livemode: true }), m.ctx),
    { outcome: "needs_attention", errorCode: "stripe_environment_mismatch" });
  assertEquals(await processJob(refundJob({ livemode: null }), m.ctx),
    { outcome: "needs_attention", errorCode: "stripe_environment_mismatch" });
  assertEquals(await processJob(refundJob({ stripe_account_id: null }), m.ctx),
    { outcome: "failed", errorCode: "stripe_account_missing" });
  assertEquals(m.calls.length, 0);
});

Deno.test("refund: order no longer refundable", async () => {
  const m = mockStripe([]);
  assertEquals((await processJob(refundJob({ order_status: "preparing" }), m.ctx)).outcome, "needs_attention");
  assertEquals(m.calls.length, 0);
});

Deno.test("ZOKY-147: an order flagged refunded is never closed without asking Stripe", async () => {
  // Queued job, order already says refunded: Stripe has a live refund -> adopt it.
  let m = mockStripe([{ body: { data: [{ id: "re_live", status: "succeeded", amount: 12000 }] } }]);
  assertEquals(await processJob(refundJob({ order_payment_status: "refunded", order_refund_status: "refunded" }), m.ctx),
    { outcome: "refunded", refundId: "re_live", feeRefunded: false });
  assertEquals(m.calls.length, 1);
  // ...and no live refund at Stripe: an operator looks, no refund is created.
  m = mockStripe([{ body: { data: [{ id: "re_dead", status: "failed", amount: 12000 }] } }]);
  assertEquals(await processJob(refundJob({ order_payment_status: "refunded", order_refund_status: "refunded" }), m.ctx),
    { outcome: "needs_attention", errorCode: "order_refunded_without_stripe_refund" });
  assertEquals(m.calls.length, 1);
  // Missing account on a refunded-looking order is parked, never failed.
  m = mockStripe([]);
  assertEquals((await processJob(refundJob({ order_payment_status: "refunded", stripe_account_id: null }), m.ctx)).outcome,
    "needs_attention");
});

Deno.test("ZOKY-147: awaiting PromptPay refund keeps polling after the webhook flagged the order refunded", async () => {
  const job = refundJob({ status: "awaiting_refund", stripe_refund_id: "re_pp",
    order_payment_status: "refunded", order_refund_status: "refunded" });
  // Still waiting for the customer's bank account.
  let m = mockStripe([{ body: { id: "re_pp", status: "requires_action",
    next_action: { type: "display_details", display_details: { email_sent: { email_sent_at: 1 } } } } }]);
  assertEquals(await processJob(job, m.ctx), { outcome: "refund_requested", refundId: "re_pp", awaitingCustomer: true });
  assert(m.calls[0].url.endsWith("/v1/refunds/re_pp"));
  // The customer never answered: the refund fails, nothing else covers it.
  m = mockStripe([
    { body: { id: "re_pp", status: "failed", failure_reason: "unknown" } },
    { body: { data: [{ id: "re_pp", status: "failed", amount: 12000 }] } },
  ]);
  assertEquals(await processJob(job, m.ctx), { outcome: "failed", refundId: "re_pp", errorCode: "refund_failed_unknown" });
  assertEquals(m.calls.length, 2);
  // Canceled, but another live refund covers the payment: adopt it.
  m = mockStripe([
    { body: { id: "re_pp", status: "canceled" } },
    { body: { data: [{ id: "re_pp", status: "canceled", amount: 12000 }, { id: "re_dash", status: "succeeded", amount: 12000 }] } },
  ]);
  assertEquals(await processJob(job, m.ctx), { outcome: "refunded", refundId: "re_dash", feeRefunded: false });
});

Deno.test("awaiting customer detection", () => {
  assert(awaitingCustomer({ status: "requires_action" }));
  assert(awaitingCustomer({ status: "pending", next_action: { type: "display_details" } }));
  assert(awaitingCustomer({ status: "pending" }, "promptpay"));
  assert(!awaitingCustomer({ status: "pending" }, "card"));
  assert(!awaitingCustomer({ status: "succeeded" }, "promptpay"));
});

Deno.test("refund: polls a requested refund until final", async () => {
  let m = mockStripe([{ body: { id: "re_1", status: "pending" } }]);
  const job = refundJob({ status: "awaiting_refund", stripe_refund_id: "re_1", payment_method: "card" });
  assertEquals(await processJob(job, m.ctx), { outcome: "refund_requested", refundId: "re_1", awaitingCustomer: false });
  assert(m.calls[0].url.endsWith("/v1/refunds/re_1"));
  m = mockStripe([
    { body: { id: "re_1", status: "succeeded", amount: 12000 } },
    { body: { data: [{ id: "re_1", status: "succeeded", amount: 12000 }] } },
  ]);
  assertEquals((await processJob(job, m.ctx)).outcome, "refunded");
  assert(m.calls[1].url.endsWith("/v1/refunds?payment_intent=pi_test_1&limit=100"), "success is re-summed from the list");
  m = mockStripe([
    { body: { id: "re_1", status: "failed", failure_reason: "lost_or_stolen_card" } },
    { body: { data: [] } },
  ]);
  assertEquals(await processJob(job, m.ctx),
    { outcome: "failed", refundId: "re_1", errorCode: "refund_failed_lost_or_stolen_card" });
});

Deno.test("refund: GP is claimed on a polled success only for our own refund", async () => {
  const job = refundJob({ status: "awaiting_refund", stripe_refund_id: "re_1", application_fee_satang: 500 });
  const ownRefund = { id: "re_1", status: "succeeded", amount: 12000, metadata: { wynos_refund_job_id: job.job_id } };
  let m = mockStripe([{ body: ownRefund }, { body: { data: [ownRefund] } }]);
  assertEquals(await processJob(job, m.ctx), { outcome: "refunded", refundId: "re_1", feeRefunded: true });
  m = mockStripe([{ body: { id: "re_1", status: "succeeded" } }, { body: { data: [{ id: "re_1", status: "succeeded", amount: 12000 }] } }]);
  assertEquals(await processJob(job, m.ctx), { outcome: "refunded", refundId: "re_1", feeRefunded: false });
});

Deno.test("refund: payment intent recovered from the Checkout session", async () => {
  const { ctx, calls } = mockStripe([
    { body: { id: "cs_test_1", payment_intent: "pi_from_session" } },
    { body: { data: [] } },
    { body: { id: "re_s", status: "succeeded" } },
  ]);
  const out = await processJob(refundJob({ payment_intent_id: null }), ctx);
  assertEquals(out.outcome, "refunded");
  assertEquals(new URLSearchParams(calls[2].body).get("payment_intent"), "pi_from_session");
});

Deno.test("expire: open session is expired on the connected account", async () => {
  const { ctx, calls } = mockStripe([
    { body: { id: "cs_test_1", status: "open", payment_status: "unpaid" } },
    { body: { id: "cs_test_1", status: "expired", payment_status: "unpaid" } },
  ]);
  assertEquals(await processJob(expireJob(), ctx), { outcome: "done", errorCode: "session_expired" });
  assertEquals(calls[1].method, "POST");
  assert(calls[1].url.endsWith("/v1/checkout/sessions/cs_test_1/expire"));
  assertEquals(calls[1].headers["Stripe-Account"], "acct_test_1");
});

Deno.test("expire: a paid or complete session is left alone (never downgraded)", async () => {
  let m = mockStripe([{ body: { status: "complete", payment_status: "paid" } }]);
  assertEquals(await processJob(expireJob(), m.ctx), { outcome: "done", errorCode: "session_complete" });
  assertEquals(m.calls.length, 1);
  // Paid between our read and the expire call.
  m = mockStripe([
    { body: { status: "open", payment_status: "unpaid" } },
    { status: 400, body: { error: { code: "checkout_session_not_open" } } },
    { body: { status: "complete", payment_status: "paid" } },
  ]);
  assertEquals(await processJob(expireJob(), m.ctx), { outcome: "done", errorCode: "session_complete" });
});

Deno.test("expire: already expired, missing, or failing", async () => {
  let m = mockStripe([{ body: { status: "expired", payment_status: "unpaid" } }]);
  assertEquals((await processJob(expireJob(), m.ctx)).errorCode, "session_expired");
  m = mockStripe([{ status: 404, body: { error: { code: "resource_missing" } } }]);
  assertEquals(await processJob(expireJob(), m.ctx), { outcome: "done", errorCode: "session_missing" });
  m = mockStripe([{ status: 503, body: {} }]);
  assertEquals((await processJob(expireJob(), m.ctx)).outcome, "retry");
  m = mockStripe([]);
  assertEquals((await processJob(expireJob({ livemode: true }), m.ctx)).outcome, "needs_attention");
});

Deno.test("runWorker: claims, processes and records each job", async () => {
  const { ctx } = mockStripe([
    { body: { data: [] } },
    { body: { id: "re_w", status: "succeeded" } },
  ]);
  const rpcCalls: Array<[string, Record<string, unknown>]> = [];
  const rpc = (fn: string, args: Record<string, unknown>) => {
    rpcCalls.push([fn, args]);
    if (fn === "food_claim_stripe_jobs") return Promise.resolve({ data: [refundJob()], error: null });
    return Promise.resolve({ data: "done", error: null });
  };
  const result = await runWorker(rpc, ctx);
  assertEquals(result, { ok: true, claimed: 1, counts: { done: 1 } });
  assertEquals(rpcCalls[1], ["food_complete_stripe_job", {
    p_job_id: "00000000-0000-0000-0000-00000000j001",
    p_outcome: "refunded",
    p_refund_id: "re_w",
    p_error_code: null,
    p_fee_refunded: false,
    p_awaiting_customer: false,
  }]);
});

Deno.test("runWorker: passes the awaiting-customer state to the database", async () => {
  const { ctx } = mockStripe([{ body: { id: "re_pp", status: "requires_action" } }]);
  const rpcCalls: Array<[string, Record<string, unknown>]> = [];
  const rpc = (fn: string, args: Record<string, unknown>) => {
    rpcCalls.push([fn, args]);
    if (fn === "food_claim_stripe_jobs") {
      return Promise.resolve({ data: [refundJob({ status: "awaiting_refund", stripe_refund_id: "re_pp" })], error: null });
    }
    return Promise.resolve({ data: "awaiting_refund", error: null });
  };
  await runWorker(rpc, ctx);
  assertEquals(rpcCalls[1][1].p_outcome, "refund_requested");
  assertEquals(rpcCalls[1][1].p_awaiting_customer, true);
  assertEquals(rpcCalls[1][1].p_fee_refunded, false);
});

Deno.test("runWorker: claim failure stops before any Stripe call", async () => {
  const m = mockStripe([]);
  const result = await runWorker(() => Promise.resolve({ data: null, error: { message: "x" } }), m.ctx);
  assertEquals(result, { ok: false, error: "claim_failed" });
  assertEquals(m.calls.length, 0);
});

Deno.test("ZOKY-156: requeued partial-refund job closes only when live refunds of its own PaymentIntent cover the total", async () => {
  const job = refundJob({ requeue_count: 1, attempts: 1 });
  // Operator refunded the remainder as a separate Refund: both succeeded.
  let m = mockStripe([{ body: { data: [
    { id: "re_rest", status: "succeeded", amount: 7000 },
    { id: "re_part", status: "succeeded", amount: 5000 },
  ] } }]);
  assertEquals(await processJob(job, m.ctx), { outcome: "refunded", refundId: "re_rest", feeRefunded: false });
  assertEquals(m.calls.length, 1, "list only, no refund created");
  assert(m.calls[0].url.endsWith("/v1/refunds?payment_intent=pi_test_1&limit=100"));
  // The remainder is still pending: never counted as refunded, polled instead.
  m = mockStripe([{ body: { data: [
    { id: "re_rest", status: "pending", amount: 7000 },
    { id: "re_part", status: "succeeded", amount: 5000 },
  ] } }]);
  assertEquals((await processJob(job, m.ctx)).outcome, "refund_requested");
  // Still short of the total: parked again.
  m = mockStripe([{ body: { data: [
    { id: "re_a", status: "succeeded", amount: 5000 },
    { id: "re_b", status: "succeeded", amount: 2000 },
  ] } }]);
  assertEquals(await processJob(job, m.ctx), { outcome: "needs_attention", errorCode: "partial_refund_exists" });
});

Deno.test("ZOKY-156: a duplicate payment's review job closes from Stripe's list and never creates a refund", async () => {
  const dup = refundJob({ reason: "duplicate_payment", payment_intent_id: "pi_test_dup", order_status: "preparing",
    order_refund_status: "none" });
  let m = mockStripe([{ body: { data: [{ id: "re_dup", status: "succeeded", amount: 12000 }] } }]);
  assertEquals(await processJob(dup, m.ctx), { outcome: "done", refundId: "re_dup", errorCode: "duplicate_refunded" });
  assertEquals(m.calls.length, 1);
  assertEquals(m.calls[0].method, "GET");
  assert(m.calls[0].url.endsWith("/v1/refunds?payment_intent=pi_test_dup&limit=100"));
  // Two partial refunds of the duplicate that together cover it.
  m = mockStripe([{ body: { data: [
    { id: "re_d2", status: "succeeded", amount: 7000 }, { id: "re_d1", status: "succeeded", amount: 5000 },
  ] } }]);
  assertEquals((await processJob(dup, m.ctx)).outcome, "done");
  // Pending or partial: parked again; a pending refund never counts.
  for (const data of [
    [{ id: "re_p", status: "pending", amount: 12000 }],
    [{ id: "re_s", status: "succeeded", amount: 5000 }, { id: "re_p", status: "pending", amount: 7000 }],
    [{ id: "re_f", status: "failed", amount: 12000 }],
    [],
  ]) {
    m = mockStripe([{ body: { data } }]);
    assertEquals(await processJob(dup, m.ctx), { outcome: "needs_attention", errorCode: "duplicate_payment_review" });
    assertEquals(m.calls.length, 1, "never a POST /refunds for a duplicate");
  }
  // Transient list error retries; a permanent one parks (never `failed`).
  m = mockStripe(["network"]);
  assertEquals((await processJob(dup, m.ctx)).outcome, "retry");
  m = mockStripe([{ status: 404, body: { error: { code: "resource_missing" } } }]);
  assertEquals(await processJob(dup, m.ctx), { outcome: "needs_attention", errorCode: "duplicate_payment_review" });
  // No PaymentIntent on the review job: parked without a Stripe call.
  m = mockStripe([]);
  assertEquals((await processJob({ ...dup, payment_intent_id: null }, m.ctx)).outcome, "needs_attention");
  assertEquals(m.calls.length, 0);
});

Deno.test("Codex P1: a polled refund that succeeds closes only when every refund making up the total has succeeded", async () => {
  // Adopted while two partial refunds were pending; the tracked one succeeds first.
  const job = refundJob({ status: "awaiting_refund", stripe_refund_id: "re_a", payment_method: "card" });
  let m = mockStripe([
    { body: { id: "re_a", status: "succeeded", amount: 5000 } },
    { body: { data: [{ id: "re_b", status: "pending", amount: 7000 }, { id: "re_a", status: "succeeded", amount: 5000 }] } },
  ]);
  assertEquals(await processJob(job, m.ctx), { outcome: "refund_requested", refundId: "re_b", awaitingCustomer: false },
    "keeps polling the refund that is still pending");
  // The other one failed: the succeeded refunds no longer cover the total.
  m = mockStripe([
    { body: { id: "re_a", status: "succeeded", amount: 5000 } },
    { body: { data: [{ id: "re_b", status: "failed", amount: 7000 }, { id: "re_a", status: "succeeded", amount: 5000 }] } },
  ]);
  assertEquals(await processJob(job, m.ctx), { outcome: "needs_attention", errorCode: "partial_refund_exists" });
  // Both succeeded: refunded with the tracked refund.
  m = mockStripe([
    { body: { id: "re_a", status: "succeeded", amount: 5000 } },
    { body: { data: [{ id: "re_b", status: "succeeded", amount: 7000 }, { id: "re_a", status: "succeeded", amount: 5000 }] } },
  ]);
  assertEquals(await processJob(job, m.ctx), { outcome: "refunded", refundId: "re_a", feeRefunded: false });
  // The list cannot be read: retry, never refunded on the single refund alone.
  m = mockStripe([{ body: { id: "re_a", status: "succeeded", amount: 5000 } }, "network"]);
  assertEquals(await processJob(job, m.ctx), { outcome: "retry", errorCode: "network_error" });
});

Deno.test("Codex P2: a requeued failed refund job adopts the operator's refund and never posts a new one", async () => {
  // e.g. failed with balance_insufficient, then the operator refunded at Stripe.
  const job = refundJob({ requeue_count: 2, order_refund_status: "failed" });
  let m = mockStripe([{ body: { data: [{ id: "re_op", status: "succeeded", amount: 12000 }] } }]);
  assertEquals(await processJob(job, m.ctx), { outcome: "refunded", refundId: "re_op", feeRefunded: false });
  assertEquals(m.calls.length, 1);
  m = mockStripe([{ body: { data: [{ id: "re_op", status: "succeeded", amount: 5000 }] } }]);
  assertEquals(await processJob(job, m.ctx), { outcome: "needs_attention", errorCode: "partial_refund_exists" });
  assertEquals(m.calls.filter((c) => c.method === "POST").length, 0);
});
