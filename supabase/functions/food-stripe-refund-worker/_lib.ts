/**
 * ZOKY Stripe jobs worker (design: zoky-stripe-only-auto-refund-design.md, 1-2).
 *
 * Jobs are queued by database triggers on public.food_orders
 * (supabase/migrations/20261023100000_food_stripe_jobs_auto_refund.sql) and
 * claimed with food_claim_stripe_jobs. This file holds all the decisions so
 * they can be tested with a mocked fetch; index.ts only wires env + Supabase.
 *
 * Money safety, in order: the unique job per order/payment, list-before-create,
 * an Idempotency-Key per job, and Stripe's own full-refund cap. No `amount` is
 * ever sent, so a refund is always the full PaymentIntent (D4, D6). Calls are
 * made on the connected account that took the payment (Stripe-Account), and
 * only when the payment's livemode matches the secret key's mode.
 *
 * Refund truth (ZOKY-147): a refund is final only when Stripe says
 * `succeeded`. A requested refund is always polled to a final state, even if
 * the order row already says refunded (stripe-webhook now marks refunded only
 * for a succeeded full Refund, ZOKY-153; older rows may still have come from
 * charge.refunded). PromptPay refunds wait for the customer to give Stripe a bank
 * account (Stripe emails them): that is reported as `awaitingCustomer` so the
 * database can tell the customer to check the email.
 */

export type Job = {
  job_id: string;
  kind: "expire_checkout" | "refund";
  status: "queued" | "awaiting_refund";
  reason: string;
  order_id: string;
  attempts: number;
  requeue_count: number;
  checkout_session_id: string | null;
  payment_intent_id: string | null;
  stripe_refund_id: string | null;
  stripe_account_id: string | null;
  livemode: boolean | null;
  amount_satang: number | null;
  application_fee_satang: number | null;
  order_status: string | null;
  order_payment_status: string | null;
  order_payment_provider: string | null;
  order_refund_status: string | null;
  payment_method?: string | null;
};

export type Outcome = {
  outcome: "done" | "refund_requested" | "refunded" | "retry" | "failed" | "needs_attention";
  refundId?: string | null;
  errorCode?: string | null;
  feeRefunded?: boolean;
  awaitingCustomer?: boolean;
};

export type FetchFn = (input: string, init?: RequestInit) => Promise<Response>;

export type Context = {
  secret: string;
  livemode: boolean;
  fetch: FetchFn;
};

type StripeResult = {
  ok: boolean;
  status: number;
  code: string | null;
  body: Record<string, unknown>;
};

const STRIPE_API = "https://api.stripe.com/v1";
const STRIPE_TIMEOUT_MS = 7500;

export function stripeLivemode(secret: string): boolean | null {
  if (/^(?:sk|rk)_live_/.test(secret)) return true;
  if (/^(?:sk|rk)_test_/.test(secret)) return false;
  return null;
}

/** Same key for every retry of one job run; a merchant requeue gets a new
 * key so Stripe does not replay a cached error (e.g. balance_insufficient). */
export function refundIdempotencyKey(jobId: string, requeueCount: number): string {
  return requeueCount > 0 ? `wynos-refund-job-${jobId}-r${requeueCount}` : `wynos-refund-job-${jobId}`;
}

/** Transient errors are retried with backoff; anything else is permanent. */
export function isTransient(status: number): boolean {
  return status === 0 || status === 401 || status === 409 || status === 429 || status >= 500;
}

function str(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

function num(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

async function stripe(
  ctx: Context,
  account: string,
  method: "GET" | "POST",
  path: string,
  params?: URLSearchParams,
  idempotencyKey?: string,
): Promise<StripeResult> {
  const headers: Record<string, string> = {
    Authorization: `Basic ${btoa(ctx.secret + ":")}`,
    "Stripe-Account": account,
    "Content-Type": "application/x-www-form-urlencoded",
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  let response: Response;
  try {
    response = await ctx.fetch(`${STRIPE_API}${path}`, {
      method,
      headers,
      body: method === "POST" ? (params ?? new URLSearchParams()).toString() : undefined,
      signal: AbortSignal.timeout(STRIPE_TIMEOUT_MS),
    });
  } catch {
    return { ok: false, status: 0, code: "network_error", body: {} };
  }
  const body = await response.json().catch(() => ({})) as Record<string, unknown>;
  const error = body.error as Record<string, unknown> | undefined;
  return { ok: response.ok, status: response.status, code: str(error?.code), body };
}

function fromError(result: StripeResult, fallback: string): Outcome {
  const code = result.code ?? `${fallback}_${result.status}`;
  return { outcome: isTransient(result.status) ? "retry" : "failed", errorCode: code };
}

/**
 * True while Stripe waits for the customer to give a bank account for the
 * refund: `requires_action`, a `display_details` next action (Stripe emailed
 * the customer), or any pending refund of a PromptPay payment (every PromptPay
 * refund needs the customer's bank account).
 */
export function awaitingCustomer(refund: Record<string, unknown>, paymentMethod?: string | null): boolean {
  const status = str(refund.status);
  if (status === "requires_action") return true;
  const next = refund.next_action as Record<string, unknown> | null | undefined;
  if (next && (next.type === "display_details" || next.display_details)) return true;
  return status === "pending" && paymentMethod === "promptpay";
}

/** Map a Stripe Refund object to a job outcome. The fee flag only matters
 * for `refunded` (GP is booked as returned only on success). */
export function refundOutcome(
  refund: Record<string, unknown>,
  feeRefunded: boolean,
  paymentMethod?: string | null,
): Outcome {
  const id = str(refund.id);
  const status = str(refund.status);
  if (!id) return { outcome: "retry", errorCode: "refund_id_missing" };
  if (status === "succeeded") return { outcome: "refunded", refundId: id, feeRefunded };
  if (status === "failed" || status === "canceled") {
    const reason = str(refund.failure_reason);
    return { outcome: "failed", refundId: id, errorCode: `refund_${status}${reason ? `_${reason}` : ""}` };
  }
  // pending / requires_action / unknown: poll again later.
  return { outcome: "refund_requested", refundId: id, awaitingCustomer: awaitingCustomer(refund, paymentMethod) };
}

function refundIsOurs(refund: Record<string, unknown>, jobId: string): boolean {
  const metadata = refund.metadata as Record<string, unknown> | undefined;
  return metadata?.wynos_refund_job_id === jobId;
}

/**
 * Adopt refunds that already exist for the PaymentIntent (a previous run that
 * crashed after Stripe answered, the legacy merchant button, or the Stripe
 * Dashboard). Failed/canceled refunds are ignored. Returns null when there is
 * nothing to adopt and a refund should be created.
 */
export function adoptExisting(
  refunds: unknown,
  amountSatang: number | null,
  jobId: string,
  feeSatang: number,
  paymentMethod?: string | null,
): Outcome | null {
  const list = Array.isArray(refunds) ? refunds as Record<string, unknown>[] : [];
  const live = list.filter((r) => r && typeof r === "object" && !["failed", "canceled"].includes(String(r.status)));
  if (live.length === 0) return null;
  const total = live.reduce((sum, r) => sum + (num(r.amount) ?? 0), 0);
  if (amountSatang != null && amountSatang > 0 && total < amountSatang) {
    // Someone refunded part of it (D4: no partial refunds). Do not guess.
    return { outcome: "needs_attention", errorCode: "partial_refund_exists" };
  }
  const ours = live.some((r) => refundIsOurs(r, jobId));
  const feeRefunded = ours && feeSatang > 0;
  const pending = live.find((r) => r.status !== "succeeded");
  if (pending) return refundOutcome(pending, feeRefunded, paymentMethod);
  return refundOutcome(live[0], feeRefunded, paymentMethod);
}

async function expireCheckout(job: Job, ctx: Context): Promise<Outcome> {
  const sessionId = job.checkout_session_id;
  if (!sessionId) return { outcome: "done", errorCode: "no_session" };
  if (!job.stripe_account_id) return { outcome: "failed", errorCode: "stripe_account_missing" };
  if (job.livemode !== ctx.livemode) return { outcome: "needs_attention", errorCode: "stripe_environment_mismatch" };

  const path = `/checkout/sessions/${encodeURIComponent(sessionId)}`;
  const classify = (session: Record<string, unknown>): Outcome | null => {
    // Paid/complete: never downgrade. The webhook marks it paid and the
    // paid-after-cancel trigger queues the refund.
    if (session.payment_status === "paid" || session.status === "complete") {
      return { outcome: "done", errorCode: "session_complete" };
    }
    if (session.status === "expired") return { outcome: "done", errorCode: "session_expired" };
    return null;
  };

  const current = await stripe(ctx, job.stripe_account_id, "GET", path);
  if (!current.ok) {
    if (current.status === 404) return { outcome: "done", errorCode: "session_missing" };
    return fromError(current, "session_lookup");
  }
  const known = classify(current.body);
  if (known) return known;
  if (current.body.status !== "open") return { outcome: "retry", errorCode: "session_status_unknown" };

  const expired = await stripe(ctx, job.stripe_account_id, "POST", `${path}/expire`);
  if (expired.ok) {
    const after = classify(expired.body);
    if (after) return after;
  }
  // It may have completed while we were expiring it: look again.
  const recheck = await stripe(ctx, job.stripe_account_id, "GET", path);
  if (recheck.ok) {
    const after = classify(recheck.body);
    if (after) return after;
  }
  return { outcome: "retry", errorCode: expired.code ?? "session_expire_failed" };
}

async function checkDuplicateRefunded(job: Job, ctx: Context, account: string): Promise<Outcome> {
  const review: Outcome = { outcome: "needs_attention", errorCode: "duplicate_payment_review" };
  const amount = job.amount_satang;
  if (!job.payment_intent_id || amount == null || amount <= 0) return review;
  const listed = await stripe(ctx, account, "GET",
    `/refunds?payment_intent=${encodeURIComponent(job.payment_intent_id)}&limit=100`);
  // Transient errors are retried; anything else is parked for the operator.
  if (!listed.ok) return isTransient(listed.status) ? fromError(listed, "refund_list") : review;
  const list = Array.isArray(listed.body.data) ? listed.body.data as Record<string, unknown>[] : [];
  const succeeded = list.filter((r) => r && typeof r === "object" && r.status === "succeeded");
  const total = succeeded.reduce((sum, r) => sum + (num(r.amount) ?? 0), 0);
  if (total < amount) return review;
  return { outcome: "done", refundId: str(succeeded[0].id), errorCode: "duplicate_refunded" };
}

async function refund(job: Job, ctx: Context): Promise<Outcome> {
  // The order row may already say refunded (webhook charge.refunded), but
  // only Stripe can confirm it: never close a job on the order flag alone.
  const orderRefunded = job.order_payment_status === "refunded" || job.order_refund_status === "refunded";
  const account = job.stripe_account_id;
  if (!account) {
    return { outcome: orderRefunded ? "needs_attention" : "failed", errorCode: "stripe_account_missing" };
  }
  if (job.livemode !== ctx.livemode) return { outcome: "needs_attention", errorCode: "stripe_environment_mismatch" };
  // ZOKY-154/156: a duplicate payment is refunded by an operator at Stripe,
  // never here. A review job is claimed once when created (its refund may
  // predate it) and again after food_requeue_stripe_refund_jobs (a succeeded
  // refund of the duplicate): close it when succeeded refunds
  // of the duplicate PaymentIntent cover it, else park it again. Pending
  // refunds never count, and the order (first payment) is never touched.
  if (job.reason === "duplicate_payment") return await checkDuplicateRefunded(job, ctx, account);
  const fee = Number(job.application_fee_satang ?? 0);
  const method = job.payment_method ?? null;

  const listExistingFor = async (paymentIntent: string): Promise<Outcome | StripeResult | null> => {
    const listPath = `/refunds?payment_intent=${encodeURIComponent(paymentIntent)}&limit=100`;
    const listed = await stripe(ctx, account, "GET", listPath);
    if (!listed.ok) return listed;
    return adoptExisting(listed.body.data, job.amount_satang, job.job_id, fee, method);
  };

  // Poll a refund we already asked for, until Stripe reports a final state.
  if (job.status === "awaiting_refund" && job.stripe_refund_id) {
    const current = await stripe(ctx, account, "GET", `/refunds/${encodeURIComponent(job.stripe_refund_id)}`);
    if (!current.ok) return fromError(current, "refund_lookup");
    const ours = fee > 0 && refundIsOurs(current.body, job.job_id);
    const outcome = refundOutcome(current.body, ours, method);
    if (outcome.outcome === "refunded" && job.payment_intent_id) {
      // The full amount may be several refunds (adopted while another was
      // pending): close only when the live refunds cover it and none is
      // still pending, the same rule as adoptExisting.
      const all = await listExistingFor(job.payment_intent_id);
      if (all && "ok" in all) return fromError(all, "refund_list");
      if (!all) return { outcome: "retry", errorCode: "refund_list_inconsistent" };
      return all.outcome === "refunded" ? outcome : all;
    }
    if (outcome.outcome !== "failed" || !job.payment_intent_id) return outcome;
    // Ours failed or was canceled: another live refund (Dashboard, legacy
    // button) may cover the payment; adopt it instead of reporting failure.
    const other = await listExistingFor(job.payment_intent_id);
    if (other && !("ok" in other)) return other;
    return outcome;
  }

  if (!orderRefunded &&
    (job.order_status !== "cancelled" || job.order_payment_status !== "paid" || job.order_payment_provider !== "stripe")) {
    return { outcome: "needs_attention", errorCode: "order_not_refundable" };
  }

  let paymentIntent = job.payment_intent_id;
  if (!paymentIntent && job.checkout_session_id) {
    const session = await stripe(ctx, account, "GET", `/checkout/sessions/${encodeURIComponent(job.checkout_session_id)}`);
    if (!session.ok) return fromError(session, "session_lookup");
    const value = session.body.payment_intent;
    paymentIntent = str(value) ?? str((value as Record<string, unknown> | null)?.id);
  }
  if (!paymentIntent) {
    return { outcome: orderRefunded ? "needs_attention" : "failed", errorCode: "payment_intent_missing" };
  }

  const existing = await listExistingFor(paymentIntent);
  if (existing && "ok" in existing) return fromError(existing, "refund_list");
  if (existing) return existing;
  // The order says refunded but Stripe has no live refund: do not guess.
  if (orderRefunded) return { outcome: "needs_attention", errorCode: "order_refunded_without_stripe_refund" };

  const params = new URLSearchParams();
  params.set("payment_intent", paymentIntent);
  params.set("reason", "requested_by_customer");
  // GP v1: a full refund also returns the WYNOS GP (application fee).
  if (fee > 0) params.set("refund_application_fee", "true");
  params.set("metadata[wynos_order_id]", job.order_id);
  params.set("metadata[wynos_refund_job_id]", job.job_id);
  params.set("metadata[wynos_refund_reason]", job.reason);

  const created = await stripe(ctx, account, "POST", "/refunds", params, refundIdempotencyKey(job.job_id, job.requeue_count));
  if (created.ok) return refundOutcome(created.body, fee > 0, method);

  if (created.code === "charge_already_refunded") {
    // Stripe caps a payment at its full amount: someone refunded it already.
    const again = await listExistingFor(paymentIntent);
    if (again && !("ok" in again)) return again;
    return { outcome: "needs_attention", errorCode: "charge_already_refunded" };
  }
  return fromError(created, "refund_create");
}

export async function processJob(job: Job, ctx: Context): Promise<Outcome> {
  if (job.kind === "expire_checkout") return await expireCheckout(job, ctx);
  if (job.kind === "refund") return await refund(job, ctx);
  return { outcome: "needs_attention", errorCode: "unknown_job_kind" };
}

export type Rpc = (fn: string, args: Record<string, unknown>) => Promise<{ data: unknown; error: unknown }>;

export async function runWorker(rpc: Rpc, ctx: Context, limit = 10) {
  const claimed = await rpc("food_claim_stripe_jobs", { p_limit: limit });
  if (claimed.error || !Array.isArray(claimed.data)) {
    return { ok: false as const, error: "claim_failed" };
  }
  const counts: Record<string, number> = {};
  for (const job of claimed.data as Job[]) {
    let result: Outcome;
    try {
      result = await processJob(job, ctx);
    } catch {
      result = { outcome: "retry", errorCode: "worker_exception" };
    }
    const saved = await rpc("food_complete_stripe_job", {
      p_job_id: job.job_id,
      p_outcome: result.outcome,
      p_refund_id: result.refundId ?? null,
      p_error_code: result.errorCode ?? null,
      p_fee_refunded: result.feeRefunded === true,
      p_awaiting_customer: result.awaitingCustomer === true,
    });
    const final = saved.error ? "complete_failed" : String(saved.data);
    counts[final] = (counts[final] ?? 0) + 1;
    if (saved.error || ["retry", "failed", "needs_attention"].includes(result.outcome)) {
      // Ids and codes only: never order contents, names, or secrets.
      console.warn("food-stripe-refund-worker job", {
        job_id: job.job_id,
        kind: job.kind,
        outcome: result.outcome,
        code: result.errorCode ?? null,
        saved: !saved.error,
      });
    }
  }
  return { ok: true as const, claimed: (claimed.data as Job[]).length, counts };
}
