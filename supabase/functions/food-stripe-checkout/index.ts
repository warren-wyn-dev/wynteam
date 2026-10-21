import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import { applicationFeeSatang, foodReturnBaseUrl, isFoodWebOrigin } from "./_lib.ts";

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
  try {
    const body = await req.json() as { orderId?: unknown };
    orderId = typeof body.orderId === "string" ? body.orderId : "";
  } catch { return json({ error: "invalid_body" }, 400); }
  if (!orderId) return json({ error: "order_id_required" }, 400);

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

  const { data: existing, error: existingError } = await admin.from("food_stripe_payments")
    .select("checkout_session_id,attempt,status").eq("order_id", order.id).maybeSingle();
  if (existingError) {
    return json({ error: "payment_lookup_failed", message: "ตรวจสอบการชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" }, 503);
  }
  if (existing && ["paid", "refunded"].includes(existing.status)) {
    return json({ error: "payment_already_completed" }, 409);
  }

  let attempt = Number(existing?.attempt ?? 1);
  if (existing?.checkout_session_id) {
    try {
      const session = await stripeJson(
        `https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(existing.checkout_session_id)}`,
        { headers: stripeHeaders(stripeSecret, account.stripe_account_id) },
      );
      if (session.payment_status === "paid") return json({ error: "payment_already_completed" }, 409);
      // A completed Checkout can still be processing an asynchronous payment.
      // Its webhook remains authoritative; another session could charge twice.
      if (session.status === "complete") {
        return json({ error: "payment_processing", message: "กำลังยืนยันการชำระเงิน กรุณารอสักครู่แล้วตรวจสอบออเดอร์อีกครั้ง" }, 409);
      }
      if (session.status === "open" && typeof session.url === "string") {
        return json({ url: session.url, sessionId: session.id, reused: true });
      }
      // A failed payment attempt does not expire its Checkout Session. Only a
      // confirmed expired session is safe to replace, regardless of ledger status.
      if (session.status !== "expired") {
        return json({ error: "stripe_session_lookup_failed", message: "ตรวจสอบการชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" }, 503);
      }
      attempt += 1;
    } catch {
      // A lookup outage tells us nothing about whether the old URL can accept
      // payment. Preserve its idempotency attempt and never create another URL.
      return json({ error: "stripe_session_lookup_failed", message: "ตรวจสอบการชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" }, 503);
    }
  }

  const params = new URLSearchParams();
  params.set("mode", "payment");
  params.set("client_reference_id", order.id);
  const returnBaseUrl = foodReturnBaseUrl(
    requestOrigin, stripeLiveMode, Deno.env.get("STRIPE_TEST_RETURN_ORIGINS"),
  );
  params.set("success_url", `${returnBaseUrl}/?order=${encodeURIComponent(order.order_number)}&stripe=success`);
  params.set("cancel_url", `${returnBaseUrl}/?order=${encodeURIComponent(order.order_number)}&stripe=cancelled`);
  params.set("line_items[0][price_data][currency]", "thb");
  params.set("line_items[0][price_data][product_data][name]", `ZOKY #${order.order_number}`);
  params.set("line_items[0][price_data][unit_amount]", String(amountSatang));
  params.set("line_items[0][quantity]", "1");
  // Stripe Checkout uses the connected account's active payment-method
  // configuration. Card remains capability-gated and PromptPay only appears
  // when Stripe marks it available for this connected account.
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

  const paymentRecord = {
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
  };
  if (existing) {
    // The webhook may have paid/refunded this order since our first read.
    // A conditional PATCH is atomic; a read followed by an unconditional
    // upsert could regress the authoritative ledger back to pending.
    let update = admin.from("food_stripe_payments").update(paymentRecord)
      .eq("order_id", order.id)
      .eq("attempt", existing.attempt ?? 1)
      .in("status", ["pending", "failed"]);
    update = existing.checkout_session_id
      ? update.eq("checkout_session_id", existing.checkout_session_id)
      : update.is("checkout_session_id", null);
    const { data: recorded, error: paymentError } = await update.select("checkout_session_id").maybeSingle();
    if (paymentError) return json({ error: "payment_record_failed" }, 500);
    if (!recorded) return json({ error: "payment_state_changed", message: "สถานะการชำระเงินเปลี่ยนแล้ว กรุณาตรวจสอบออเดอร์อีกครั้ง" }, 409);
  } else {
    // Concurrent first attempts share Stripe's idempotency key. If another
    // request already inserted the row, leave it intact even if a webhook has
    // since advanced it to a terminal state.
    const { error: paymentError } = await admin.from("food_stripe_payments")
      .upsert(paymentRecord, { onConflict: "order_id", ignoreDuplicates: true });
    if (paymentError) return json({ error: "payment_record_failed" }, 500);
  }

  const { data: recordedPayment, error: recordedError } = await admin.from("food_stripe_payments")
    .select("checkout_session_id,attempt,status").eq("order_id", order.id).maybeSingle();
  if (recordedError) return json({ error: "payment_lookup_failed" }, 503);
  if (!recordedPayment || recordedPayment.checkout_session_id !== session.id ||
      Number(recordedPayment.attempt) !== attempt || !["pending", "failed"].includes(recordedPayment.status)) {
    return json({ error: "payment_state_changed", message: "สถานะการชำระเงินเปลี่ยนแล้ว กรุณาตรวจสอบออเดอร์อีกครั้ง" }, 409);
  }

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
