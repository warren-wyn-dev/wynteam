import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { processRefund } from "./_lib.ts";

function json(value: unknown, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: { "Content-Type": "application/json" } });
}
function serviceKey() {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}") as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? "";
  } catch { return ""; }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const token = req.headers.get("x-wynos-cron-key");
  if (!url || !key || !token) return json({ error: "unauthorized" }, 401);
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const auth = await admin.rpc("food_auto_refund_authorized", { p_token: token });
  if (auth.error || auth.data !== true) return json({ error: "unauthorized" }, 401);
  const secret = Deno.env.get("STRIPE_SECRET_KEY")?.trim() ?? "";
  if (!/^(?:sk|rk)_(?:test|live)_/.test(secret)) return json({ error: "not_configured" }, 503);
  const claimed = await admin.rpc("food_claim_auto_refunds");
  if (claimed.error) return json({ error: "queue_unavailable" }, 503);
  let completed = 0, deferred = 0;
  for (const job of claimed.data ?? []) {
    let refundId: string | null = null;
    let outcome = "retry";
    try {
      const { data: order, error: orderError } = await admin.from("food_orders")
        .select("id,status,payment_status,payment_provider,stripe_payment_intent_id,stripe_refund_id,total")
        .eq("id", job.order_id).maybeSingle();
      const { data: payment, error: paymentError } = await admin.from("food_stripe_payments")
        .select("stripe_account_id,livemode,amount_satang,application_fee_satang")
        .eq("order_id", job.order_id).maybeSingle();
      if (orderError || paymentError) throw new Error("db_read_failed");
      if (!order || order.status !== "cancelled" || order.payment_provider !== "stripe") throw new Error("invalid_order");
      if (!payment || !order.stripe_payment_intent_id || Math.round(Number(order.total) * 100) !== Number(payment.amount_satang)) throw new Error("invalid_payment");
      // If a webhook completed the refund first, still GET the refund to reconcile GP.
      if (!["paid", "refunded"].includes(order.payment_status)) throw new Error("invalid_payment_status");
      refundId = job.refund_id ?? order.stripe_refund_id ?? null;
      if (order.payment_status === "refunded" && !refundId) throw new Error("refund_requires_review");
      const result = await processRefund({ orderId: order.id, paymentIntent: order.stripe_payment_intent_id,
        account: payment.stripe_account_id, amount: Number(payment.amount_satang),
        fee: Number(payment.application_fee_satang), livemode: payment.livemode, refundId }, secret);
      refundId = result.id;
      outcome = result.status === "succeeded" ? "succeeded" : ["failed", "canceled", "requires_action"].includes(result.status) ? "needs_review" : "pending";
    } catch (error) {
      const code = error instanceof Error ? error.message : "unknown";
      // No response bodies, credentials or customer details in logs.
      console.warn("automatic refund deferred", { code: ["stripe_transient", "stripe_rejected", "stripe_environment_mismatch"].includes(code) ? code : "refund_check_failed" });
    }
    const finished = await admin.rpc("food_finish_auto_refund", {
      p_order_id: job.order_id, p_lease: job.lease_token, p_outcome: outcome, p_refund_id: refundId,
    });
    if (finished.error || finished.data !== true || outcome !== "succeeded") deferred++;
    else completed++;
  }
  return json({ completed, deferred });
});
