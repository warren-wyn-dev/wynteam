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
  // This branch must never run against any other Supabase project.
  if (Deno.env.get("SUPABASE_URL") !== "https://pcatuxtenluqzjzzwsvl.supabase.co")
    return json({ error: "sandbox_project_mismatch" }, 503);

  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  // Hard fail closed: never allow sk_live_ in this Sandbox deployment.
  if (stripeSecret && !stripeSecret.startsWith("sk_test_")) return json({ error: "sandbox_requires_sk_test_key" }, 503);
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
  let action = "checkout";
  try {
    const body = await req.json() as { orderId?: unknown; action?: unknown };
    orderId = typeof body.orderId === "string" ? body.orderId : "";
    action = typeof body.action === "string" ? body.action : "checkout";
  } catch { return json({ error: "invalid_body" }, 400); }
  if (!orderId) return json({ error: "order_id_required" }, 400);
  if (!["checkout", "reconcile"].includes(action)) return json({ error: "invalid_action" }, 400);

  const { data: order } = await admin.from("food_orders")
    .select("id,order_number,buyer_id,store_id,total,status,payment_status,stripe_checkout_session_id")
    .eq("id", orderId).maybeSingle();
  if (!order || order.buyer_id !== user.id) return json({ error: "order_not_found" }, 404);
  if (action === "checkout" &&
      (["cancelled","delivered"].includes(order.status) || !["pending","issue"].includes(order.payment_status))) {
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
    .select("checkout_session_id,attempt,status,stripe_account_id,livemode,amount_satang,currency").eq("order_id", order.id).maybeSingle();

  if (action === "reconcile") {
    // Isolated QA-merchant recovery; never creates a new charge.
    // Authorization, session, merchant, amount and metadata are re-verified.
    if (stripeLiveMode !== false ||
        user.id !== "50956870-1d09-4e0a-98bf-2c1e0e0c722b" ||
        order.store_id !== "6638327e-353f-4151-8d69-d84b5badb831") {
      return json({ error: "qa_reconcile_only" }, 403);
    }
    if (order.payment_status === "refunded" || order.status === "cancelled") {
      return json({ error: "order_not_payable" }, 409);
    }
    if (!existing ||
        existing.livemode !== false ||
        existing.stripe_account_id !== account.stripe_account_id ||
        Number(existing.amount_satang) !== amountSatang ||
        existing.currency !== "thb") {
      return json({ error: "qa_payment_ledger_mismatch" }, 409);
    }
    const existingSessionId = existing.checkout_session_id;
    if (typeof existingSessionId !== "string" || !existingSessionId.startsWith("cs_test_") ||
        order.stripe_checkout_session_id !== existingSessionId) {
      return json({ error: "qa_checkout_session_not_found" }, 404);
    }
    let session: Record<string,unknown>;
    try {
      session = await stripeJson(
        `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(existingSessionId)}`,
        { headers: stripeHeaders(stripeSecret, account.stripe_account_id) },
      );
    } catch (error) {
      console.warn("sandbox QA checkout verification failed", {
        code: error instanceof StripeCheckoutError ? error.code : "unknown",
        status: error instanceof StripeCheckoutError ? error.status : 500,
      });
      return json({ error: "stripe_verification_failed" }, 502);
    }
    const metadata = (session.metadata ?? {}) as Record<string,unknown>;
    const expected = {
      sessionId: existingSessionId,
      totalSatang: amountSatang,
      orderId: order.id,
      storeId: order.store_id,
    };
    if (session.id !== expected.sessionId ||
        session.livemode !== false ||
        session.currency !== "thb" ||
        session.amount_total !== expected.totalSatang ||
        session.client_reference_id !== expected.orderId ||
        metadata.order_id !== expected.orderId ||
        metadata.store_id !== expected.storeId) {
      return json({ error: "stripe_checkout_verification_mismatch" }, 409);
    }
    if (session.status !== "complete" || session.payment_status !== "paid") {
      return json({ error: "checkout_not_paid" }, 409);
    }
    const paymentIntentId = typeof session.payment_intent === "string" ? session.payment_intent : null;
    if (!paymentIntentId || !paymentIntentId.startsWith("pi_")) {
      return json({ error: "payment_intent_not_available" }, 409);
    }
    const { error: reconcileError } = await admin.rpc("food_apply_stripe_event", {
      p_event_id: `qa_reconcile_${existingSessionId}`,
      p_event_type: "checkout.session.reconciled",
      p_order_id: order.id,
      p_stripe_account_id: account.stripe_account_id,
      p_object_id: existingSessionId,
      p_checkout_session_id: existingSessionId,
      p_payment_intent_id: paymentIntentId,
      p_amount_satang: amountSatang,
      p_currency: "thb",
      p_state: "paid",
      p_payment_method: null,
      p_note: "Verified via Stripe API after missing webhook",
      p_refund_id: null,
    });
    if (reconcileError) {
      console.error("sandbox QA reconciliation failed", { code: reconcileError.code });
      return json({ error: "reconcile_record_failed" }, 500);
    }
    // Make the non-webhook recovery origin explicit in the audit record.
    await admin.from("food_orders").update({
      payment_verification_note: "Verified via Stripe Test API; recovery due to missing webhook",
    }).eq("id", order.id).eq("payment_provider_code", "checkout.session.reconciled");
    return json({ reconciled: true, payment_status: "paid", source: "stripe_test_api" });
  }

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

  // Do not send test customers back to food.wynos.online (production).
  const isIsolatedQaCheckout =
    user.id === "50956870-1d09-4e0a-98bf-2c1e0e0c722b" &&
    order.buyer_id === user.id &&
    order.store_id === "6638327e-353f-4151-8d69-d84b5badb831" &&
    stripeLiveMode === false;
  // The fixed synthetic QA order always returns to its own sandbox preview.
  // Do not expose this fallback to real stores, other customers, or Production.
  const qaReturnUrl =
    "https://wynteam-gesb-git-sandbox-stripe-testmode-20261008-warren14.vercel.app/stripe-sandbox";
  const sandboxFoodReturn = isIsolatedQaCheckout
    ? qaReturnUrl
    : Deno.env.get("WYNOS_STRIPE_SANDBOX_FOOD_URL")?.trim();
  let sandboxFoodBase: string;
  try {
    const parsed = new URL(sandboxFoodReturn ?? "");
    if (parsed.protocol !== "https:" ||
        ["wynos.online","food.wynos.online","merchant.wynos.online","maps.wynos.online"].includes(parsed.hostname) ||
        parsed.username || parsed.password || parsed.search || parsed.hash) {
      throw new Error("bad sandbox return URL");
    }
    sandboxFoodBase = parsed.origin + parsed.pathname.replace(/\/+$/, "");
  } catch { return json({ error: "sandbox_food_redirect_not_configured" }, 503); }
  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("client_reference_id", order.id);
  // For the dedicated Next.js QA page, append search params to the page itself.
  const returnSeparator = isIsolatedQaCheckout ? "?" : "/?";
  params.set("success_url", `${sandboxFoodBase}${returnSeparator}order=${encodeURIComponent(order.order_number)}&stripe=success`);
  params.set("cancel_url", `${sandboxFoodBase}${returnSeparator}order=${encodeURIComponent(order.order_number)}&stripe=cancelled`);
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
