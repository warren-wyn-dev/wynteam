import { createClient } from "npm:@supabase/supabase-js@2.112.3";
const cors = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type" };
const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { ...cors, "Content-Type": "application/json" } });
function serviceKey() { const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"); if (legacy) return legacy;
  try { const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}"); return keys.default ?? Object.values(keys)[0] as string; } catch { return ""; } }
function thb(rows: unknown) { if (!Array.isArray(rows)) throw Error("invalid_balance");
  const row = rows.find((r) => r.currency === "thb"); const value = row?.amount ?? 0;
  if (!Number.isSafeInteger(value)) throw Error("invalid_balance"); return Number(value); }
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL"), key = serviceKey();
  if (!url || !key) return json({ error: "not_configured" }, 503);
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const token = req.headers.get("x-wynos-cron-key"); const authorization = req.headers.get("Authorization");
  let cron = false;
  if (token) { const check = await admin.rpc("food_auto_refund_authorized", { p_token: token }); cron = !check.error && check.data === true; }
  let actor: string | null = null;
  let body: { action?: string; storeId?: string } = {};
  try { body = await req.json(); } catch { return json({ error: "invalid_body" }, 400); }
  if (!cron) {
    if (!authorization || body.action !== "configure" || !body.storeId) return json({ error: "unauthorized" }, 401);
    const user = await admin.auth.getUser(authorization.replace(/^Bearer\s+/i, ""));
    if (user.error || !user.data.user) return json({ error: "unauthorized" }, 401);
    const scoped = createClient(url, key, { global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false } });
    const access = await scoped.rpc("admin_food_finance_configuration_access", { p_store_id: body.storeId });
    if (access.error || access.data !== true) return json({ error: "finance_admin_required" }, 403);
    actor = user.data.user.id;
  }
  const secret = Deno.env.get("STRIPE_SECRET_KEY")?.trim() ?? "";
  const mode = /^(?:sk|rk)_test_/.test(secret) ? false : /^(?:sk|rk)_live_/.test(secret) ? true : null;
  if (mode === null) return json({ error: "not_configured" }, 503);
  const call = async (path: string, account: string, params?: URLSearchParams, idempotencyKey?: string) => {
    if (!/^acct_[A-Za-z0-9]+$/.test(account)) throw Error("invalid_account");
    const response = await fetch(`https://api.stripe.com/v1/${path}`, { method: params ? "POST" : "GET",
      headers: { Authorization: `Basic ${btoa(secret + ":")}`, "Stripe-Account": account,
        ...(idempotencyKey ? { "Idempotency-Key": idempotencyKey } : {}), "Content-Type": "application/x-www-form-urlencoded" },
      ...(params ? { body: params } : {}), redirect: "error", signal: AbortSignal.timeout(7500) });
    if (!response.ok) throw Error("provider_request_failed");
    return await response.json() as Record<string, unknown>;
  };
  if (body.action === "configure") {
    const { data: account, error } = await admin.from("food_stripe_accounts").select("stripe_account_id,livemode").eq("store_id", body.storeId).maybeSingle();
    if (error || !account || account.livemode !== mode) return json({ error: "account_mismatch" }, 409);
    // Stop the old schedule before taking the opening balance snapshot.
    try {
      const existing = await admin.rpc("food_store_managed_payouts", { p_store_id: body.storeId });
      if (existing.error) throw Error("configuration_unavailable");
      if (existing.data === true) return json({ status: "already_configured" });
      const settings = await call("balance_settings", account.stripe_account_id,
        new URLSearchParams({ "payments[payouts][schedule][interval]": "manual" }), `zoky-payout-schedule-${body.storeId}`);
      const interval = (settings.payments as { payouts?: { schedule?: { interval?: string } } })?.payouts?.schedule?.interval;
      if (interval !== "manual") throw Error("manual_schedule_not_confirmed");
      const balance = await call("balance", account.stripe_account_id);
      const opening = thb(balance.available) + thb(balance.pending);
      const saved = await admin.rpc("food_enable_managed_payouts", { p_store_id: body.storeId, p_opening: opening, p_actor: actor });
      if (saved.error) throw Error("configuration_write_failed");
      return json({ status: "configured" });
    } catch { return json({ error: "configuration_failed", message: "ตั้งรอบโอนไม่สำเร็จ ต้องตรวจสถานะ Stripe ก่อนลองใหม่" }, 502); }
  }
  if (!cron) return json({ error: "unauthorized" }, 401);
  const funding = await admin.rpc("food_finance_funding_jobs");
  if (funding.error) return json({ error: "funding_queue_unavailable" }, 503);
  for (const adjustment of funding.data ?? []) {
    try {
      if (adjustment.livemode !== mode || Date.now() - new Date(adjustment.started_at).getTime() > 20 * 3600000
          || !/^acct_[A-Za-z0-9]+$/.test(adjustment.account_id)) throw Error("funding_requires_review");
      const amount = Number(adjustment.amount_satang);
      if (!Number.isSafeInteger(amount) || amount <= 0) throw Error("invalid_funding_amount");
      const response = await fetch("https://api.stripe.com/v1/transfers", { method: "POST",
        headers: { Authorization: `Basic ${btoa(secret + ":")}`, "Content-Type": "application/x-www-form-urlencoded", "Idempotency-Key": `zoky-adjustment-${adjustment.id}` },
        body: new URLSearchParams({ amount: String(amount), currency: "thb", destination: adjustment.account_id, "metadata[zoky_adjustment]": adjustment.id }),
        redirect: "error", signal: AbortSignal.timeout(7500) });
      if (!response.ok) throw Error("funding_provider_failed");
      const transfer = await response.json() as Record<string, unknown>;
      if (transfer.amount !== amount || transfer.currency !== "thb" || transfer.destination !== adjustment.account_id || typeof transfer.id !== "string") throw Error("funding_response_mismatch");
      const saved = await admin.rpc("food_finance_record_funding", { p_id: adjustment.id, p_transfer_id: transfer.id });
      if (saved.error) throw Error("funding_record_failed");
    } catch { /* Keep approved but unfunded; no payout assumes the transfer happened. */ }
  }
  const jobs = await admin.rpc("food_finance_payout_candidates");
  if (jobs.error) return json({ error: "payout_queue_unavailable" }, 503);
  let submitted = 0, deferred = 0;
  for (const job of jobs.data ?? []) {
    try {
      if (job.livemode !== mode) throw Error("environment_mismatch");
      const settings = await call("balance_settings", job.stripe_account_id);
      if ((settings.payments as { payouts?: { schedule?: { interval?: string } } })?.payouts?.schedule?.interval !== "manual") {
        await admin.rpc("food_finance_finish_payout", { p_id: job.run_id, p_lease: job.lease, p_state: "requires_configuration", p_provider_id: null, p_arrival: null });
        deferred++; continue;
      }
      const balance = await call("balance", job.stripe_account_id);
      const quote = await admin.rpc("food_finance_prepare_payout", { p_id: job.run_id, p_lease: job.lease, p_available: thb(balance.available) });
      if (quote.error) throw Error("payout_quote_failed");
      const amount = Number(quote.data);
      if (!Number.isSafeInteger(amount) || amount <= 0) {
        await admin.rpc("food_finance_finish_payout", { p_id: job.run_id, p_lease: job.lease, p_state: "awaiting_funds", p_provider_id: null, p_arrival: null });
        deferred++; continue;
      }
      // Recover an accepted payout after a lost response before any POST retry.
      const list = await call(`payouts?limit=100&created[gte]=${Math.floor(new Date(job.created_at).getTime() / 1000)}`, job.stripe_account_id);
      let payout = (Array.isArray(list.data) ? list.data : []).find((p) => (p as { metadata?: Record<string, string> }).metadata?.zoky_payout_run === job.run_id) as Record<string, unknown> | undefined;
      if (!payout) {
        if (Date.now() - new Date(job.created_at).getTime() > 20 * 3600000) throw Error("payout_reconciliation_required");
        payout = await call("payouts", job.stripe_account_id, new URLSearchParams({ amount: String(amount), currency: "thb", "metadata[zoky_payout_run]": job.run_id }), `zoky-payout-${job.run_id}`);
      }
      if (typeof payout.id !== "string" || !/^po_[A-Za-z0-9]+$/.test(payout.id) || payout.amount !== amount || payout.currency !== "thb") throw Error("payout_mismatch");
      const saved = await admin.rpc("food_finance_finish_payout", { p_id: job.run_id, p_lease: job.lease,
        p_state: payout.status === "paid" ? "paid" : ["failed", "canceled"].includes(String(payout.status)) ? "failed" : "submitted",
        p_provider_id: payout.id, p_arrival: typeof payout.arrival_date === "number" ? new Date(payout.arrival_date * 1000).toISOString().slice(0, 10) : null });
      if (saved.error || saved.data !== true) throw Error("payout_record_failed");
      submitted++;
    } catch { deferred++; }
  }
  return json({ submitted, deferred });
});
