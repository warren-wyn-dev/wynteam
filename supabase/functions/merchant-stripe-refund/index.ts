import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}
function serviceKey() {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) return null;
  try { const keys = JSON.parse(raw) as Record<string,string>; return keys.default ?? Object.values(keys)[0] ?? null; }
  catch { return null; }
}
function stripeLivemode(secret: string) {
  if (/^(?:sk|rk)_live_/.test(secret)) return true;
  if (/^(?:sk|rk)_test_/.test(secret)) return false;
  return null;
}
function stripeHeaders(secret: string, account: string, idempotencyKey: string) {
  return {
    Authorization: `Basic ${btoa(secret + ":")}`,
    "Stripe-Account": account,
    "Content-Type": "application/x-www-form-urlencoded",
    "Idempotency-Key": idempotencyKey,
  };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  // Hard fail closed: never allow sk_live_ in this Sandbox deployment.
  if (stripeSecret && !stripeSecret.startsWith("sk_test_")) return json({ error: "sandbox_requires_sk_test_key" }, 503);
  const authHeader = req.headers.get("Authorization");
  if (!url || !key || !authHeader) return json({ error: "unauthorized" }, 401);
  if (!stripeSecret) return json({ error: "payments_not_configured", message: "ระบบคืนเงินยังไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง" }, 503);
  const stripeLiveMode = stripeLivemode(stripeSecret);
  if (stripeLiveMode == null) return json({ error: "stripe_key_mode_unknown", message: "ระบบคืนเงินยังไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง" }, 503);
  if (stripeLiveMode && req.headers.get("origin") !== "https://merchant.wynos.online") {
    return json({ error: "live_stripe_origin_required" }, 403);
  }

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let orderId = "", note = "";
  try {
    const body = await req.json() as { orderId?: unknown; note?: unknown };
    orderId = typeof body.orderId === "string" ? body.orderId : "";
    note = typeof body.note === "string" ? body.note.trim().slice(0,500) : "";
  } catch { return json({ error: "invalid_body" }, 400); }
  if (!orderId) return json({ error: "order_id_required" }, 400);

  const { data: order } = await admin.from("food_orders")
    .select("id,store_id,status,payment_status,payment_provider,stripe_payment_intent_id,refund_status")
    .eq("id", orderId).maybeSingle();
  if (!order) return json({ error: "order_not_found" }, 404);

  const { data: store } = await admin.from("food_stores").select("merchant_account_id").eq("id", order.store_id).maybeSingle();
  if (!store?.merchant_account_id) return json({ error: "store_not_found" }, 404);
  const { data: member } = await admin.from("merchant_memberships")
    .select("role").eq("merchant_account_id", store.merchant_account_id).eq("user_id", user.id).eq("active", true).maybeSingle();
  if (!member || !["owner","admin","manager","orders"].includes(member.role)) return json({ error: "order_management_role_required" }, 403);

  if (order.status !== "cancelled" || order.payment_status !== "paid" || order.payment_provider !== "stripe" || !order.stripe_payment_intent_id) {
    return json({ error: "stripe_refund_not_eligible" }, 409);
  }
  if (order.refund_status === "refunded") return json({ error: "already_refunded" }, 409);

  const { data: payment } = await admin.from("food_stripe_payments")
    .select("stripe_account_id,livemode").eq("order_id", order.id).maybeSingle();

  let stripeAccountId = typeof payment?.stripe_account_id === "string" ? payment.stripe_account_id : null;
  let paymentLivemode = typeof payment?.livemode === "boolean" ? payment.livemode : null;

  // Compatibility fallback for older Stripe orders that predate the payment
  // ledger row. New refunds always stay pinned to the account that took the payment.
  if (!stripeAccountId) {
    const { data: activeAccount } = await admin.from("food_stripe_accounts")
      .select("stripe_account_id,livemode").eq("store_id", order.store_id).maybeSingle();
    stripeAccountId = typeof activeAccount?.stripe_account_id === "string" ? activeAccount.stripe_account_id : null;
    paymentLivemode = typeof activeAccount?.livemode === "boolean" ? activeAccount.livemode : null;
  }
  if (!stripeAccountId) return json({ error: "stripe_account_missing" }, 409);
  if (paymentLivemode !== stripeLiveMode) return json({ error: "stripe_environment_mismatch" }, 409);

  const params = new URLSearchParams();
  params.set("payment_intent", order.stripe_payment_intent_id);
  params.set("reason", "requested_by_customer");
  params.set("metadata[wynos_order_id]", order.id);
  if (note) params.set("metadata[wynos_note]", note);

  try {
    const response = await fetch("https://api.stripe.com/v1/refunds", {
      method: "POST",
      headers: stripeHeaders(stripeSecret, stripeAccountId, `wynos-refund-${order.id}`),
      body: params,
    });
    const payload = await response.json().catch(() => ({})) as Record<string,unknown>;
    if (!response.ok || typeof payload.id !== "string") {
      const err = payload.error as Record<string,unknown> | undefined;
      console.error("merchant-stripe-refund gateway failure", {
        code: typeof err?.code === "string" ? err.code : null,
        decline_code: typeof err?.decline_code === "string" ? err.decline_code : null,
        status: response.status,
        request_id: response.headers.get("request-id"),
      });
      throw new Error("gateway_refund_failed");
    }
    await admin.from("food_orders").update({
      refund_status: "pending",
      refund_note: note || "Stripe refund requested",
      refund_requested_at: new Date().toISOString(),
      refund_updated_by: user.id,
      stripe_refund_id: payload.id,
    }).eq("id", order.id);
    return json({ status: payload.status ?? "pending", refundId: payload.id });
  } catch (error) {
    console.error("merchant-stripe-refund failed", {
      code: error instanceof Error ? error.message.slice(0, 80) : "unknown",
    });
    await admin.from("food_orders").update({
      refund_status: "failed",
      refund_note: note || "การคืนเงินไม่สำเร็จ",
      refund_updated_by: user.id,
    }).eq("id", order.id);
    return json({
      error: "refund_failed",
      message: "คืนเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง",
    }, 502);
  }
});
