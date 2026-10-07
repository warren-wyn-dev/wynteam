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
function stripeHeaders(secret: string, account: string) {
  return {
    Authorization: `Basic ${btoa(secret + ":")}`,
    "Stripe-Account": account,
    "Content-Type": "application/x-www-form-urlencoded",
  };
}
async function stripeJson(url: string, init: RequestInit) {
  const response = await fetch(url, init);
  const payload = await response.json().catch(() => ({})) as Record<string,unknown>;
  return { response, payload };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const authHeader = req.headers.get("Authorization");
  if (!url || !key || !authHeader) return json({ error: "unauthorized" }, 401);

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let orderId = "";
  try {
    const body = await req.json() as { orderId?: unknown };
    orderId = typeof body.orderId === "string" ? body.orderId : "";
  } catch { return json({ error: "invalid_body" }, 400); }
  if (!orderId) return json({ error: "order_id_required" }, 400);

  const { data: order } = await admin.from("food_orders")
    .select("id,buyer_id,store_id,payment_status,stripe_checkout_session_id")
    .eq("id", orderId).maybeSingle();
  if (!order || order.buyer_id !== user.id) return json({ error: "order_not_found" }, 404);
  if (!["pending","issue"].includes(order.payment_status)) return json({ error: "order_not_payable" }, 409);

  const sessionId = order.stripe_checkout_session_id as string | null;
  if (!sessionId) return json({ cancelled: false, reason: "no_stripe_session" });

  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  if (!stripeSecret) return json({ error: "stripe_not_configured" }, 503);
  const stripeLiveMode = stripeLivemode(stripeSecret);
  if (stripeLiveMode == null) return json({ error: "stripe_key_mode_unknown" }, 503);
  if (stripeLiveMode && req.headers.get("origin") !== "https://food.wynos.online") {
    return json({ error: "live_stripe_origin_required" }, 403);
  }

  const { data: payment } = await admin.from("food_stripe_payments")
    .select("stripe_account_id,livemode").eq("order_id", order.id).eq("checkout_session_id", sessionId).maybeSingle();

  let stripeAccountId = typeof payment?.stripe_account_id === "string" ? payment.stripe_account_id : null;
  let paymentLivemode = typeof payment?.livemode === "boolean" ? payment.livemode : null;
  if (!stripeAccountId) {
    const { data: activeAccount } = await admin.from("food_stripe_accounts")
      .select("stripe_account_id,livemode").eq("store_id", order.store_id).maybeSingle();
    stripeAccountId = typeof activeAccount?.stripe_account_id === "string" ? activeAccount.stripe_account_id : null;
    paymentLivemode = typeof activeAccount?.livemode === "boolean" ? activeAccount.livemode : null;
  }
  if (!stripeAccountId) return json({ error: "stripe_account_missing" }, 409);
  if (paymentLivemode !== stripeLiveMode) return json({ error: "stripe_environment_mismatch" }, 409);

  const current = await stripeJson(
    `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`,
    { headers: stripeHeaders(stripeSecret, stripeAccountId) },
  );
  if (!current.response.ok) return json({ error: "stripe_session_lookup_failed" }, 502);
  if (current.payload.payment_status === "paid" || current.payload.status === "complete") {
    return json({ error: "stripe_payment_already_completed" }, 409);
  }

  if (current.payload.status === "open") {
    const expired = await stripeJson(
      `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}/expire`,
      { method: "POST", headers: stripeHeaders(stripeSecret, stripeAccountId) },
    );
    if (!expired.response.ok) {
      const retry = await stripeJson(
        `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`,
        { headers: stripeHeaders(stripeSecret, stripeAccountId) },
      );
      if (retry.response.ok && (retry.payload.payment_status === "paid" || retry.payload.status === "complete")) {
        return json({ error: "stripe_payment_already_completed" }, 409);
      }
      return json({ error: "stripe_session_expire_failed" }, 502);
    }
  }

  const { data: cleared, error: clearError } = await admin.from("food_orders")
    .update({ stripe_checkout_session_id: null })
    .eq("id", order.id)
    .eq("stripe_checkout_session_id", sessionId)
    .in("payment_status", ["pending","issue"])
    .select("id")
    .maybeSingle();
  if (clearError || !cleared) return json({ error: "payment_state_changed" }, 409);

  await admin.from("food_stripe_payments").update({
    status: "failed",
    last_error: "Customer switched to manual transfer",
    updated_at: new Date().toISOString(),
  }).eq("order_id", order.id).eq("checkout_session_id", sessionId);

  return json({ cancelled: true });
});
