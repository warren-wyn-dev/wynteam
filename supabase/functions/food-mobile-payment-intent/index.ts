// STAGING-ONLY Stripe PaymentSheet endpoint for a Native Android customer.
//
// This endpoint is intentionally permanently fail-closed when connected to
// WYNOS Production OR when either Stripe key is live. Do not silently
// repurpose it for production checkout without a payment architecture review.
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { applicationFeeSatang } from "../food-stripe-checkout/_lib.ts";
import { payableStagingOrder, satangFromServerTotal, stagingStripeEnvironment } from "./_lib.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function serviceKey(): string | null {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  try {
    const stored = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}") as Record<string, string>;
    return stored.default ?? Object.values(stored)[0] ?? null;
  } catch { return null; }
}

function stripeHeaders(secret: string, accountId: string): Record<string, string> {
  return {
    Authorization: "Basic " + btoa(secret + ":"),
    "Stripe-Account": accountId,
    "Content-Type": "application/x-www-form-urlencoded",
  };
}

async function stripeRequest(
  secret: string, accountId: string, endpoint: string, init: RequestInit = {},
): Promise<Record<string, unknown>> {
  const response = await fetch("https://api.stripe.com/v1/" + endpoint, {
    ...init,
    headers: { ...stripeHeaders(secret, accountId), ...(init.headers ?? {}) },
  });
  const result = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok) throw new Error("stripe_request_failed_" + response.status);
  return result;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const projectUrl = Deno.env.get("SUPABASE_URL");
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
  const stripePublic = Deno.env.get("STRIPE_PUBLISHABLE_KEY");
  const guard = stagingStripeEnvironment(
    projectUrl, stripeSecret, stripePublic,
    Deno.env.get("WYNOS_FOOD_MOBILE_PAYMENT_STAGING"),
  );
  if (!guard.ok) return json({ error: guard.error }, 503);
  const service = serviceKey();
  if (!service || !projectUrl || !stripeSecret || !stripePublic) {
    return json({ error: "server_not_configured" }, 503);
  }
  const authorization = req.headers.get("Authorization");
  if (!authorization || !/^Bearer\s+\S+$/i.test(authorization)) {
    return json({ error: "unauthorized" }, 401);
  }
  const token = authorization.replace(/^Bearer\s+/i, "");
  const admin = createClient(projectUrl, service, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: auth, error: authError } = await admin.auth.getUser(token);
  if (authError || !auth.user) return json({ error: "unauthorized" }, 401);

  let orderId: string;
  try {
    const body = await req.json() as Record<string, unknown>;
    const candidate = body.orderId;
    if (typeof candidate !== "string" ||
        !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(candidate)) {
      return json({ error: "invalid_order_id" }, 400);
    }
    orderId = candidate;
  } catch { return json({ error: "invalid_body" }, 400); }

  const { data: order, error: orderError } = await admin.from("food_orders")
    .select("id,buyer_id,store_id,total,status,payment_status,payment_due_at,payment_slip_path,stripe_checkout_session_id")
    .eq("id", orderId).maybeSingle();
  if (orderError) return json({ error: "order_lookup_failed" }, 503);
  if (!order || order.buyer_id !== auth.user.id) return json({ error: "order_not_found" }, 404);
  const paymentError = payableStagingOrder(order);
  if (paymentError) return json({ error: paymentError }, 409);
  if (order.stripe_checkout_session_id) return json({ error: "payment_method_conflict" }, 409);
  const amountSatang = satangFromServerTotal(order.total);
  if (amountSatang === null) return json({ error: "invalid_order_total" }, 422);

  const { data: account, error: accountError } = await admin.from("food_stripe_accounts")
    .select("stripe_account_id,livemode,status,details_submitted,charges_enabled")
    .eq("store_id", order.store_id).maybeSingle();
  if (accountError) return json({ error: "merchant_lookup_failed" }, 503);
  if (!account || account.livemode !== false || account.status !== "ready" ||
      !account.details_submitted || !account.charges_enabled ||
      typeof account.stripe_account_id !== "string" ||
      !/^acct_[a-zA-Z0-9]+$/.test(account.stripe_account_id)) {
    return json({ error: "merchant_test_stripe_not_ready" }, 422);
  }
  const connected = account.stripe_account_id;

  const { data: existing, error: ledgerError } = await admin.from("food_stripe_payments")
    .select("checkout_session_id,payment_intent_id,status,livemode,stripe_account_id,amount_satang")
    .eq("order_id", orderId).maybeSingle();
  if (ledgerError) return json({ error: "payment_lookup_failed" }, 503);
  if (existing && (existing.checkout_session_id ||
      existing.stripe_account_id !== connected ||
      existing.livemode !== false ||
      Number(existing.amount_satang) !== amountSatang)) {
    return json({ error: "payment_method_conflict" }, 409);
  }
  if (existing?.payment_intent_id) {
    try {
      const intent = await stripeRequest(
        stripeSecret, connected,
        "payment_intents/" + encodeURIComponent(existing.payment_intent_id),
      );
      if (!["requires_payment_method", "requires_confirmation", "requires_action"].includes(String(intent.status))) {
        return json({ error: "payment_requires_reconciliation" }, 409);
      }
      if (typeof intent.client_secret !== "string" || intent.livemode !== false ||
          intent.currency !== "thb" || Number(intent.amount) !== amountSatang ||
          (intent.metadata as Record<string, unknown> | undefined)?.order_id !== orderId) {
        return json({ error: "stripe_intent_mismatch" }, 409);
      }
      return json({
        orderId, paymentIntentId: intent.id, clientSecret: intent.client_secret,
        publishableKey: stripePublic, connectedAccountId: connected, reused: true,
      });
    } catch {
      // Never create a new intent while the first intent might exist.
      return json({ error: "payment_requires_reconciliation" }, 409);
    }
  }
  if (existing) return json({ error: "payment_requires_reconciliation" }, 409);

  // Same order and account always map to ONE Stripe idempotency key. Never
  // trust a client amount/account/idempotency key. Card only for this preview;
  // async methods such as PromptPay require a separate verified state machine.
  const params = new URLSearchParams();
  params.set("amount", String(amountSatang));
  params.set("currency", "thb");
  params.set("payment_method_types[]", "card");
  params.set("metadata[order_id]", orderId);
  params.set("metadata[store_id]", order.store_id);
  params.set("description", "WYNOS Food Android staging test order " + orderId);

  let gpInstalled = true;
  let feeSatang = 0;
  const { data: gpQuote, error: gpError } = await admin.rpc(
    "food_order_gp_quote", { p_order_id: orderId },
  );
  if (gpError?.code === "PGRST202") gpInstalled = false;
  else if (gpError) return json({ error: "gp_quote_failed" }, 503);
  else {
    try { feeSatang = applicationFeeSatang(gpQuote, amountSatang); }
    catch { return json({ error: "gp_quote_failed" }, 503); }
  }
  if (feeSatang > 0) params.set("application_fee_amount", String(feeSatang));

  let intent: Record<string, unknown>;
  try {
    intent = await stripeRequest(stripeSecret, connected, "payment_intents", {
      method: "POST",
      headers: { "Idempotency-Key": "wynos-food-mobile-" + orderId },
      body: params,
    });
  } catch {
    // No retry with a *different* key: Stripe may have created the intent.
    return json({ error: "stripe_intent_requires_reconciliation" }, 502);
  }
  if (typeof intent.id !== "string" || typeof intent.client_secret !== "string" ||
      intent.livemode !== false || intent.currency !== "thb" ||
      Number(intent.amount) !== amountSatang ||
      (intent.metadata as Record<string, unknown> | undefined)?.order_id !== orderId) {
    return json({ error: "stripe_intent_invalid_response" }, 502);
  }

  const { error: recordError } = await admin.from("food_stripe_payments").insert({
    order_id: orderId,
    store_id: order.store_id,
    buyer_id: auth.user.id,
    stripe_account_id: connected,
    livemode: false,
    payment_intent_id: intent.id,
    amount_satang: amountSatang,
    ...(gpInstalled ? { application_fee_satang: feeSatang } : {}),
    currency: "thb",
    status: "pending",
    attempt: 1,
  });
  if (recordError) {
    // No client secret is exposed on uncertain persistence. A server-side
    // reconciliation task must cancel orphan intents before a retry.
    return json({ error: "payment_record_requires_reconciliation" }, 409);
  }
  return json({
    orderId, paymentIntentId: intent.id, clientSecret: intent.client_secret,
    publishableKey: stripePublic, connectedAccountId: connected, reused: false,
  });
});
