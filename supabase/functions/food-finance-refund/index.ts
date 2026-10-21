import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { executeRefund } from "./_lib.ts";
const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json" } });
function serviceKey() { const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"); if (legacy) return legacy;
  try { const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}"); return keys.default ?? Object.values(keys)[0] as string; } catch { return ""; } }
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL"), key = serviceKey(), token = req.headers.get("x-wynos-cron-key");
  if (!url || !key || !token) return json({ error: "unauthorized" }, 401);
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const auth = await admin.rpc("food_auto_refund_authorized", { p_token: token });
  if (auth.error || auth.data !== true) return json({ error: "unauthorized" }, 401);
  const secret = Deno.env.get("STRIPE_SECRET_KEY")?.trim() ?? "";
  if (!/^(?:sk|rk)_(?:test|live)_/.test(secret)) return json({ error: "not_configured" }, 503);
  const jobs = await admin.rpc("food_finance_claim_refunds");
  if (jobs.error) return json({ error: "queue_unavailable" }, 503);
  let completed = 0, deferred = 0;
  for (const job of jobs.data ?? []) {
    let state = "retry", refundId = job.refund_id, feeId = null;
    try { const result = await executeRefund(job, secret); state = result.state; refundId = result.id; feeId = result.feeId; }
    catch { /* Durable retry; never log credentials or provider payloads. */ }
    const saved = await admin.rpc("food_finance_finish_refund", { p_id: job.request_id, p_lease: job.lease,
      p_state: state, p_refund_id: refundId, p_fee_refund_id: feeId });
    if (!saved.error && saved.data === true && state === "succeeded") completed++; else deferred++;
  }
  return json({ completed, deferred });
});
