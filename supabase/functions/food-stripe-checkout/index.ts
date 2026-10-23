import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import {
  applicationFeeSatang,
  checkoutExpiresAt,
  checkoutIdempotencyKey,
  foodReturnOrigin,
  isFoodWebOrigin,
  parseCheckoutMethod,
  resolveCheckoutMethod,
  sessionMatchesMethod,
  stripeOnlyFromPolicyResult,
} from "./_lib.ts";

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

/**
 * Expires an open session. Returns null when it is closed, or the response
 * to send: 409 if Stripe says it was paid meanwhile (never open a second
 * payable link for a paid order), 502 if it could not be closed.
 */
async function expireOpenSession(stripeSecret: string, stripeAccountId: string, sessionId: string): Promise<Response | null> {
  const sessionUrl = `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`;
  try {
    await stripeJson(`${sessionUrl}/expire`, { method: "POST", headers: stripeHeaders(stripeSecret, stripeAccountId) });
    return null;
  } catch { /* Re-check below: it may have been paid or closed meanwhile. */ }
  try {
    const current = await stripeJson(sessionUrl, { headers: stripeHeaders(stripeSecret, stripeAccountId) });
    if (current.payment_status === "paid" || current.status === "complete") {
      return json({ error: "payment_already_completed" }, 409);
    }
    if (current.status === "expired") return null;
  } catch { /* fall through */ }
  return json({ error: "stripe_session_expire_failed", message: "เปลี่ยนวิธีชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" }, 502);
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
  const requestOrigin = req.headers.get("origin");
  if (stripeLiveMode && !isFoodWebOrigin(requestOrigin)) {
    return json({ error: "live_stripe_origin_required" }, 403);
  }

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let orderId = "";
  let rawMethod: unknown = undefined;
  try {
    const body = await req.json() as { orderId?: unknown; method?: unknown };
    orderId = typeof body.orderId === "string" ? body.orderId : "";
    rawMethod = body.method;
  } catch { return json({ error: "invalid_body" }, 400); }
  if (!orderId) return json({ error: "order_id_required" }, 400);
  // Optional: older clients send no method and keep the account's configuration.
  const requestedMethod = parseCheckoutMethod(rawMethod);
  if (requestedMethod === null) return json({ error: "invalid_payment_method" }, 400);
  // Stripe-only policy (read from the DB): PromptPay QR only (Founder 2026-10-23).
  // PromptPay is allowed in both states, so only other requests need the check.
  let method = requestedMethod;
  if (requestedMethod !== "promptpay") {
    const stripeOnly = stripeOnlyFromPolicyResult(await admin.rpc("food_payment_policy_public"));
    if (stripeOnly === null) {
      return json({ error: "payment_policy_unavailable", message: "เปิดหน้าชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" }, 503);
    }
    const resolved = resolveCheckoutMethod(requestedMethod, stripeOnly);
    if (resolved.error) return json({ error: resolved.error, message: "ZOKY รับชำระด้วยพร้อมเพย์เท่านั้น" }, 422);
    method = resolved.method;
  }

  const { data: order } = await admin.from("food_orders")
    .select("id,order_number,buyer_id,store_id,total,status,payment_status,payment_due_at")
    .eq("id", orderId).maybeSingle();
  if (!order || order.buyer_id !== user.id) return json({ error: "order_not_found" }, 404);
  if (["cancelled","delivered"].includes(order.status) || !["pending","issue"].includes(order.payment_status)) {
    return json({ error: "order_not_payable" }, 409);
  }
  if (order.payment_due_at && new Date(order.payment_due_at).getTime() <= Date.now()) {
    return json({ error: "payment_deadline_expired", message: "หมดเวลาชำระเงิน 10 นาทีแล้ว ออเดอร์จะถูกยกเลิกอัตโนมัติ" }, 409);
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
  // PromptPay is only offered when Stripe has enabled it on the store's account.
  if (method === "promptpay" && account.promptpay_enabled !== true) {
    return json({ error: "promptpay_unavailable", message: "ร้านนี้ยังไม่เปิดรับชำระเงินด้วยพร้อมเพย์ กรุณาติดต่อร้าน" }, 422);
  }

  const amountSatang = Math.round(Number(order.total) * 100);
  if (!Number.isSafeInteger(amountSatang) || amountSatang <= 0) return json({ error: "invalid_amount" }, 422);

  // GP v1: WYNOS GP from the order's snapshotted rate, as an application fee.
  let feeSatang = 0;
  // false only before the GP v1 migration exists: then the ledger has no
  // application_fee_satang column either, so it must not be written.
  let gpInstalled = true;
  try {
    const { data: quote, error: quoteError } = await admin.rpc("food_order_gp_quote", { p_order_id: order.id });
    // Function not installed yet means GP v1 (and so any GP rate) does not
    // exist in this database: there is nothing to collect.
    if (quoteError?.code === "PGRST202") gpInstalled = false;
    else if (quoteError) throw quoteError;
    else feeSatang = applicationFeeSatang(quote, amountSatang);
  } catch (error) {
    console.error("food-stripe-checkout gp quote failure", {
      code: error instanceof Error ? error.message.slice(0, 80) : "unknown",
    });
    return json({ error: "gp_quote_failed", message: "เปิดหน้าชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" }, 503);
  }

  const { data: existing } = await admin.from("food_stripe_payments")
    .select("checkout_session_id,attempt,status").eq("order_id", order.id).maybeSingle();

  let attempt = Number(existing?.attempt ?? 1);
  if (existing?.checkout_session_id && existing.status === "pending") {
    try {
      const session = await stripeJson(
        `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(existing.checkout_session_id)}`,
        { headers: stripeHeaders(stripeSecret, account.stripe_account_id) },
      );
      if (session.payment_status === "paid" || session.status === "complete") {
        return json({ error: "payment_already_completed" }, 409);
      }
      if (session.status === "open" && typeof session.url === "string" && sessionMatchesMethod(session, method)) {
        return json({ url: session.url, sessionId: session.id, reused: true });
      }
      if (session.status === "open") {
        // The customer switched method: close the old session before opening a
        // new one, so only one payable link exists (same as food-stripe-cancel).
        const expireError = await expireOpenSession(stripeSecret, account.stripe_account_id, existing.checkout_session_id);
        if (expireError) return expireError;
      }
      attempt += 1;
    } catch {
      attempt += 1;
    }
  }

  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("client_reference_id", order.id);
  // Return to the allowlisted origin the customer paid from (ZOKY by default).
  const returnOrigin = foodReturnOrigin(requestOrigin);
  params.set("success_url", `${returnOrigin}/?order=${encodeURIComponent(order.order_number)}&stripe=success`);
  params.set("cancel_url", `${returnOrigin}/?order=${encodeURIComponent(order.order_number)}&stripe=cancelled`);
  params.set("line_items[0][price_data][currency]", "thb");
  params.set("line_items[0][price_data][product_data][name]", `ZOKY #${order.order_number}`);
  params.set("line_items[0][price_data][unit_amount]", String(amountSatang));
  params.set("line_items[0][quantity]", "1");
  // With a method the session offers only that method (so the recorded
  // payment_method_types[0] is what the customer chose). Without one, Stripe
  // Checkout uses the connected account's active payment-method configuration.
  if (method) params.set("payment_method_types[0]", method);
  // Backstop: an abandoned link stops being payable (Stripe minimum 30 min).
  const expiresAt = checkoutExpiresAt(Date.now());
  params.set("expires_at", String(expiresAt));
  params.set("metadata[order_id]", order.id);
  params.set("metadata[store_id]", order.store_id);
  params.set("payment_intent_data[metadata][order_id]", order.id);
  params.set("payment_intent_data[metadata][store_id]", order.store_id);
  if (feeSatang > 0) {
    params.set("payment_intent_data[application_fee_amount]", String(feeSatang));
    params.set("payment_intent_data[metadata][wynos_gp_satang]", String(feeSatang));
  }
  if (user.email) params.set("customer_email", user.email);
  params.set("locale", "th");

  let session: Record<string,unknown>;
  try {
    session = await stripeJson("https://api.stripe.com/v1/checkout/sessions", {
      method: "POST",
      headers: stripeHeaders(stripeSecret, account.stripe_account_id, checkoutIdempotencyKey(order.id, attempt, method, expiresAt)),
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
    ...(gpInstalled ? { application_fee_satang: feeSatang } : {}),
    currency: "thb",
    status: "pending",
    attempt,
    last_error: null,
    updated_at: new Date().toISOString(),
  }, { onConflict: "order_id" });
  if (paymentError) return json({ error: "payment_record_failed" }, 500);

  // Checkout creation can outlive the 10-minute deadline or race a cron
  // cancellation. Only publish the URL if the DB still allows payment.
  const { data: persisted, error: persistError } = await admin.from("food_orders")
    .update({ stripe_checkout_session_id: session.id })
    .eq("id", order.id)
    .eq("status", "pending_acceptance")
    .in("payment_status", ["pending", "issue"])
    .or(`payment_due_at.is.null,payment_due_at.gt.${new Date().toISOString()}`)
    .select("id").maybeSingle();
  if (persistError || !persisted) {
    try {
      await stripeJson(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(session.id)}/expire`, {
        method: "POST",
        headers: stripeHeaders(stripeSecret, account.stripe_account_id),
      });
    } catch { /* Link was never returned; retry/Stripe logs reconcile if needed. */ }
    return json({ error: "payment_deadline_expired", message: "หมดเวลาชำระเงินแล้ว กรุณาสั่งอาหารใหม่" }, 409);
  }
  return json({ url: session.url, sessionId: session.id, reused: false });
});
