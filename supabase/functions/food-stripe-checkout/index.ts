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
  try {
    const keys = JSON.parse(raw) as Record<string,string>;
    return keys.default ?? Object.values(keys)[0] ?? null;
  } catch { return null; }
}
function stripeLivemode(secret: string) {
  if (/^(?:sk|rk)_live_/.test(secret)) return true;
  if (/^(?:sk|rk)_test_/.test(secret)) return false;
  return null;
}
function stripeHeaders(secret: string, account: string, idempotencyKey?: string) {
  const headers: Record<string,string> = {
    Authorization: `Basic ${btoa(secret + ":")}`,
    "Stripe-Account": account,
    "Content-Type": "application/x-www-form-urlencoded",
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  return headers;
}
class StripeCheckoutError extends Error {
  code: string | null;
  status: number;
  constructor(code: string | null, status: number) {
    super("stripe_checkout_failed");
    this.name = "StripeCheckoutError";
    this.code = code;
    this.status = status;
  }
}
async function stripeJson(url: string, init: RequestInit) {
  const response = await fetch(url, init);
  const payload = await response.json().catch(() => ({})) as Record<string,unknown>;
  if (!response.ok) {
    const err = payload.error as Record<string,unknown> | undefined;
    throw new StripeCheckoutError(typeof err?.code === "string" ? err.code : null, response.status);
  }
  return payload;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  const authHeader = req.headers.get("Authorization");
  if (!url || !key || !authHeader) return json({ error: "unauthorized" }, 401);
  if (!stripeSecret) return json({ error: "stripe_not_configured" }, 503);
  const stripeLiveMode = stripeLivemode(stripeSecret);
  if (stripeLiveMode == null) return json({ error: "stripe_key_mode_unknown" }, 503);
  if (stripeLiveMode && req.headers.get("origin") !== "https://food.wynos.online") {
    return json({ error: "live_stripe_origin_required" }, 403);
  }

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
    .select("id,order_number,buyer_id,store_id,total,status,payment_status")
    .eq("id", orderId).maybeSingle();
  if (!order || order.buyer_id !== user.id) return json({ error: "order_not_found" }, 404);
  if (["cancelled","delivered"].includes(order.status) || !["pending","issue"].includes(order.payment_status)) {
    return json({ error: "order_not_payable" }, 409);
  }

  const { data: account } = await admin.from("food_stripe_accounts")
    .select("stripe_account_id,livemode,status,details_submitted,charges_enabled,promptpay_enabled")
    .eq("store_id", order.store_id).maybeSingle();
  if (account && account.livemode !== stripeLiveMode) {
    return json({ error: "stripe_environment_mismatch" }, 409);
  }
  if (!account || account.status !== "ready" || !account.details_submitted || !account.charges_enabled) {
    return json({ error: "stripe_not_ready" }, 422);
  }

  const amountSatang = Math.round(Number(order.total) * 100);
  if (!Number.isSafeInteger(amountSatang) || amountSatang <= 0) return json({ error: "invalid_amount" }, 422);

  const { data: existing } = await admin.from("food_stripe_payments")
    .select("checkout_session_id,attempt,status").eq("order_id", order.id).maybeSingle();

  let attempt = Number(existing?.attempt ?? 1);
  if (existing?.checkout_session_id && existing.status === "pending") {
    try {
      const session = await stripeJson(
        `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(existing.checkout_session_id)}`,
        { headers: stripeHeaders(stripeSecret, account.stripe_account_id) },
      );
      if (session.status === "open" && typeof session.url === "string") {
        return json({ url: session.url, sessionId: session.id, reused: true });
      }
      if (session.payment_status === "paid") return json({ error: "payment_already_completed" }, 409);
      attempt += 1;
    } catch {
      attempt += 1;
    }
  }

  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("client_reference_id", order.id);
  params.set("success_url", `https://food.wynos.online/?order=${encodeURIComponent(order.order_number)}&stripe=success`);
  params.set("cancel_url", `https://food.wynos.online/?order=${encodeURIComponent(order.order_number)}&stripe=cancelled`);
  params.set("line_items[0][price_data][currency]", "thb");
  params.set("line_items[0][price_data][product_data][name]", `WYNOS Food #${order.order_number}`);
  params.set("line_items[0][price_data][unit_amount]", String(amountSatang));
  params.set("line_items[0][quantity]", "1");
  // Stripe Checkout uses the connected account's active payment-method
  // configuration. Card remains capability-gated and PromptPay only appears
  // when Stripe marks it available for this connected account.
  params.set("metadata[order_id]", order.id);
  params.set("metadata[store_id]", order.store_id);
  params.set("payment_intent_data[metadata][order_id]", order.id);
  params.set("payment_intent_data[metadata][store_id]", order.store_id);
  if (user.email) params.set("customer_email", user.email);
  params.set("locale", "th");

  let session: Record<string,unknown>;
  try {
    session = await stripeJson("https://api.stripe.com/v1/checkout/sessions", {
      method: "POST",
      headers: stripeHeaders(stripeSecret, account.stripe_account_id, `wynos-food-${order.id}-${attempt}`),
      body: params,
    });
  } catch (error) {
    console.error("food-stripe-checkout gateway failure", {
      code: error instanceof StripeCheckoutError ? error.code : "unknown",
      status: error instanceof StripeCheckoutError ? error.status : 500,
    });
    return json({ error: "stripe_checkout_failed", message: "เปิดหน้าชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" }, 502);
  }

  if (typeof session.id !== "string" || typeof session.url !== "string") {
    return json({ error: "stripe_checkout_invalid_response" }, 502);
  }

  const { error: paymentError } = await admin.from("food_stripe_payments").upsert({
    order_id: order.id,
    store_id: order.store_id,
    buyer_id: order.buyer_id,
    stripe_account_id: account.stripe_account_id,
    livemode: stripeLiveMode,
    checkout_session_id: session.id,
    amount_satang: amountSatang,
    currency: "thb",
    status: "pending",
    attempt,
    last_error: null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "order_id" });
  if (paymentError) return json({ error: "payment_record_failed" }, 500);

  await admin.from("food_orders").update({ stripe_checkout_session_id: session.id }).eq("id", order.id);
  return json({ url: session.url, sessionId: session.id, reused: false });
});
