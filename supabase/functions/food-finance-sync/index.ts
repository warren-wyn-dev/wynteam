import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { processorFee, stripeGet } from "./_lib.ts";

const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json" } });
function serviceKey() {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  try { const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}"); return keys.default ?? Object.values(keys)[0] as string; } catch { return ""; }
}
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL"), key = serviceKey();
  const secret = Deno.env.get("STRIPE_SECRET_KEY")?.trim() ?? "";
  const token = req.headers.get("x-wynos-cron-key");
  if (!url || !key || !token) return json({ error: "unauthorized" }, 401);
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const authorized = await admin.rpc("food_auto_refund_authorized", { p_token: token });
  if (authorized.error || authorized.data !== true) return json({ error: "unauthorized" }, 401);
  const mode = /^(?:sk|rk)_test_/.test(secret) ? false : /^(?:sk|rk)_live_/.test(secret) ? true : null;
  if (mode === null) return json({ error: "not_configured" }, 503);
  const candidates = await admin.rpc("food_finance_sync_candidates");
  if (candidates.error) return json({ error: "queue_unavailable" }, 503);
  let checked = 0, deferred = 0;
  for (const row of candidates.data ?? []) {
    try {
      if (row.livemode !== mode || !/^pi_[A-Za-z0-9]+$/.test(row.payment_intent_id)
          || !/^acct_[A-Za-z0-9]+$/.test(row.stripe_account_id)) throw Error("environment_mismatch");
      const intent = await stripeGet(`/v1/payment_intents/${row.payment_intent_id}?expand[]=latest_charge.balance_transaction`, secret, row.stripe_account_id);
      if (intent.id !== row.payment_intent_id || intent.currency !== "thb" || intent.livemode !== mode) throw Error("payment_mismatch");
      const charge = intent.latest_charge as Record<string, unknown>;
      if (!charge || typeof charge.id !== "string" || charge.payment_intent !== intent.id
          || !Number.isSafeInteger(charge.amount) || !Number.isSafeInteger(charge.amount_refunded)) throw Error("charge_missing");
      const balance = charge.balance_transaction as Record<string, unknown> | null;
      let gpReturned = 0, gpCharged = 0;
      if (typeof charge.application_fee === "string") {
        const fee = await stripeGet(`/v1/application_fees/${encodeURIComponent(charge.application_fee)}`, secret);
        if (fee.account !== row.stripe_account_id || fee.charge !== charge.id || fee.currency !== "thb"
            || !Number.isSafeInteger(fee.amount_refunded) || !Number.isSafeInteger(fee.amount)) throw Error("fee_mismatch");
        gpReturned = Number(fee.amount_refunded);
        gpCharged = Number(fee.amount);
      }
      const saved = await admin.rpc("food_record_payment_facts", { p_order_id: row.order_id,
        p_charge_id: charge.id, p_balance_id: typeof balance?.id === "string" ? balance.id : null,
        p_fee: balance ? processorFee(balance) : null, p_amount: charge.amount,
        p_refunded: charge.amount_refunded, p_gp_refunded: gpReturned, p_gp_charged: gpCharged,
        p_available_on: typeof balance?.available_on === "number" ? new Date(balance.available_on * 1000).toISOString().slice(0, 10) : null,
        p_status: typeof balance?.status === "string" ? balance.status : "pending" });
      if (saved.error) throw Error("fact_write_failed");
      checked++;
    } catch { deferred++; }
  }
  const accounts = await admin.rpc("food_finance_sync_accounts");
  if (accounts.error) return json({ error: "account_sync_unavailable", checked, deferred }, 503);
  let accountsChecked = 0;
  for (const account of accounts.data ?? []) {
    try {
      if (account.livemode !== mode || !/^acct_[A-Za-z0-9]+$/.test(account.account_id)) throw Error("account_mode_mismatch");
      const cursor = account.next_cursor;
      if (cursor && !/^txn_[A-Za-z0-9]+$/.test(cursor)) throw Error("invalid_cursor");
      const page = await stripeGet(`\/v1/balance_transactions?limit=100${cursor ? `&starting_after=${cursor}` : ""}`, secret, account.account_id);
      if (!Array.isArray(page.data) || typeof page.has_more !== "boolean") throw Error("invalid_transactions");
      const rows = [];
      for (const raw of page.data) {
        const t = raw as Record<string, unknown>;
        if (t.currency !== "thb") continue;
        if (typeof t.id !== "string" || !/^txn_[A-Za-z0-9]+$/.test(t.id) || !Number.isSafeInteger(t.amount)
            || !Number.isSafeInteger(t.fee) || !Number.isSafeInteger(t.net) || typeof t.created !== "number") throw Error("invalid_transaction");
        rows.push({ id: t.id, amount: t.amount, fee: t.fee, net: t.net, source: typeof t.source === "string" ? t.source : null,
          kind: t.type, created_at: new Date(t.created * 1000).toISOString(),
          available_on: typeof t.available_on === "number" ? new Date(t.available_on * 1000).toISOString().slice(0, 10) : null, status: t.status });
      }
      const balance = await stripeGet("/v1/balance", secret, account.account_id);
      const readThb = (value: unknown) => {
        if (!Array.isArray(value)) throw Error("invalid_balance");
        const found = value.find((v) => v.currency === "thb");
        if (found && !Number.isSafeInteger(found.amount)) throw Error("invalid_balance");
        return Number(found?.amount ?? 0);
      };
      const nextCursor = page.has_more ? (page.data.at(-1) as { id?: string })?.id : null;
      if (page.has_more && !nextCursor) throw Error("invalid_next_cursor");
      const saved = await admin.rpc("food_finance_record_transactions", { p_store_id: account.store_id, p_rows: rows,
        p_balance: readThb(balance.available) + readThb(balance.pending), p_cursor: nextCursor, p_complete: !page.has_more });
      if (saved.error) throw Error("transaction_write_failed");
      accountsChecked++;
    } catch { deferred++; }
  }
  return json({ checked, accountsChecked, deferred });
});
