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
function asPositiveInteger(value: unknown) {
  const n = Number(value);
  return Number.isSafeInteger(n) && n > 0 ? n : null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  const authHeader = req.headers.get("Authorization");
  if (!url || !key || !authHeader) return json({ error: "unauthorized" }, 401);
  if (!stripeSecret) return json({ error: "payments_not_configured", message: "ระบบคืนเงินยังไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง" }, 503);

  const stripeLiveMode = stripeLivemode(stripeSecret);
  if (stripeLiveMode == null) return json({ error: "stripe_key_mode_unknown" }, 503);
  if (stripeLiveMode) {
    const origin = req.headers.get("origin");
    if (origin !== "https://merchant.wynos.online" && origin !== "https://admin.wynos.online") {
      return json({ error: "live_stripe_origin_required" }, 403);
    }
  }

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let body: {
    orderId?: unknown;
    note?: unknown;
    amountSatang?: unknown;
    liability?: unknown;
    refundGp?: unknown;
    refundDelivery?: unknown;
    requestId?: unknown;
  };
  try { body = await req.json(); }
  catch { return json({ error: "invalid_body" }, 400); }

  const orderId = typeof body.orderId === "string" ? body.orderId : "";
  const note = typeof body.note === "string" ? body.note.trim().slice(0, 500) : "";
  if (!orderId) return json({ error: "order_id_required" }, 400);

  const [{ data: order }, { data: profile }] = await Promise.all([
    admin.from("food_orders")
      .select("id,store_id,status,payment_status,payment_provider,refund_status")
      .eq("id", orderId).maybeSingle(),
    admin.from("profiles").select("platform_role,username").eq("id", user.id).maybeSingle(),
  ]);
  if (!order) return json({ error: "order_not_found" }, 404);

  const isPlatformAdmin = profile?.platform_role === "admin";
  const { data: store } = await admin.from("food_stores")
    .select("merchant_account_id").eq("id", order.store_id).maybeSingle();
  const { data: member } = store?.merchant_account_id
    ? await admin.from("merchant_memberships")
      .select("role").eq("merchant_account_id", store.merchant_account_id)
      .eq("user_id", user.id).eq("active", true).maybeSingle()
    : { data: null };
  const isMerchantOperator = Boolean(member && ["owner","admin","manager","orders"].includes(member.role));
  if (!isPlatformAdmin && !isMerchantOperator) return json({ error: "refund_role_required" }, 403);

  if (order.payment_status !== "paid" || order.payment_provider !== "stripe") {
    return json({ error: "stripe_refund_not_eligible" }, 409);
  }
  if (!isPlatformAdmin && order.status !== "cancelled") {
    return json({ error: "stripe_refund_not_eligible" }, 409);
  }
  if (order.refund_status === "refunded") return json({ error: "already_refunded" }, 409);

  // Original payment identity is mandatory. Never fall back to the store's
  // current Connect mapping: the account that charged the payment owns refund.
  const { data: payment } = await admin.from("food_stripe_payments")
    .select("stripe_account_id,livemode,payment_intent_id,amount_satang,currency")
    .eq("order_id", order.id).maybeSingle();
  if (!payment?.stripe_account_id || !payment.payment_intent_id) {
    return json({ error: "original_payment_identity_missing" }, 409);
  }
  if (payment.livemode !== stripeLiveMode) return json({ error: "stripe_environment_mismatch" }, 409);

  const { data: priorRefunds } = await admin.from("food_refunds")
    .select("amount_satang,status").eq("order_id", order.id)
    .in("status", ["pending","succeeded"]);
  const alreadyRefunded = (priorRefunds ?? []).reduce((sum, row) => sum + Number(row.amount_satang ?? 0), 0);
  const remaining = Math.max(0, Number(payment.amount_satang) - alreadyRefunded);
  if (!Number.isSafeInteger(remaining) || remaining <= 0) return json({ error: "nothing_to_refund" }, 409);

  const requestedAmount = asPositiveInteger(body.amountSatang);
  const amountSatang = isPlatformAdmin && requestedAmount ? requestedAmount : remaining;
  if (amountSatang > remaining) return json({ error: "refund_exceeds_remaining" }, 422);
  if (!isPlatformAdmin && amountSatang !== remaining) return json({ error: "partial_refund_admin_only" }, 403);

  const liability = isPlatformAdmin && typeof body.liability === "string"
    ? body.liability
    : "merchant";
  if (!["wynos","merchant","shared"].includes(liability)) return json({ error: "invalid_refund_liability" }, 422);
  const refundGp = isPlatformAdmin ? body.refundGp === true : false;
  const refundDelivery = isPlatformAdmin ? body.refundDelivery === true : false;
  const reason = note || (isPlatformAdmin ? "Admin refund" : "Merchant refund");

  const suppliedRequestId = typeof body.requestId === "string" ? body.requestId.trim().slice(0, 120) : "";
  if (isPlatformAdmin && !suppliedRequestId) return json({ error: "request_id_required" }, 400);
  const idempotencyKey = isPlatformAdmin
    ? `admin-refund-${order.id}-${suppliedRequestId}`
    : `merchant-full-refund-${order.id}`;

  const { data: refundRequestId, error: requestError } = await admin.rpc("food_create_refund_request", {
    p_order_id: order.id,
    p_amount_satang: amountSatang,
    p_reason: reason,
    p_liability: liability,
    p_refund_gp: refundGp,
    p_refund_delivery: refundDelivery,
    p_idempotency_key: idempotencyKey,
  });
  if (requestError || typeof refundRequestId !== "string") {
    console.error("refund request ledger failed", { code: requestError?.code ?? "unknown" });
    return json({ error: "refund_request_failed" }, 500);
  }
  await admin.from("food_refunds").update({ requested_by: user.id }).eq("id", refundRequestId);

  const params = new URLSearchParams();
  params.set("payment_intent", payment.payment_intent_id);
  params.set("amount", String(amountSatang));
  params.set("reason", "requested_by_customer");
  params.set("metadata[wynos_order_id]", order.id);
  params.set("metadata[wynos_refund_request_id]", refundRequestId);
  params.set("metadata[wynos_liability]", liability);
  params.set("metadata[wynos_refund_gp]", String(refundGp));
  params.set("metadata[wynos_refund_delivery]", String(refundDelivery));
  if (note) params.set("metadata[wynos_note]", note);

  try {
    const response = await fetch("https://api.stripe.com/v1/refunds", {
      method: "POST",
      headers: stripeHeaders(stripeSecret, payment.stripe_account_id, idempotencyKey),
      body: params,
    });
    const payload = await response.json().catch(() => ({})) as Record<string,unknown>;
    if (!response.ok || typeof payload.id !== "string") {
      const err = payload.error as Record<string,unknown> | undefined;
      console.error("merchant-stripe-refund gateway failure", {
        code: typeof err?.code === "string" ? err.code : null,
        status: response.status,
        request_id: response.headers.get("request-id"),
      });
      await admin.rpc("food_apply_refund_result", {
        p_refund_id: refundRequestId,
        p_stripe_refund_id: null,
        p_status: "failed",
        p_stripe_refund_fee_satang: null,
      });
      throw new Error("gateway_refund_failed");
    }

    await admin.from("food_refunds").update({
      stripe_refund_id: payload.id,
      updated_at: new Date().toISOString(),
    }).eq("id", refundRequestId);
    await admin.from("food_orders").update({
      refund_status: "pending",
      refund_note: reason,
      refund_requested_at: new Date().toISOString(),
      refund_updated_by: user.id,
      stripe_refund_id: payload.id,
    }).eq("id", order.id);

    if (isPlatformAdmin) {
      await admin.from("audit_log").insert({
        actor_id: user.id,
        actor_username_snapshot: profile?.username ?? null,
        event_type: "admin_refund_requested",
        target_id: order.id,
        detail: {
          refund_request_id: refundRequestId,
          amount_satang: amountSatang,
          liability,
          refund_gp: refundGp,
          refund_delivery: refundDelivery,
          reason,
        },
      });
    }

    // Stripe webhook remains the source of truth for succeeded/refunded state.
    return json({ status: payload.status ?? "pending", refundId: payload.id, requestId: refundRequestId });
  } catch (error) {
    console.error("merchant-stripe-refund failed", {
      code: error instanceof Error ? error.message.slice(0, 80) : "unknown",
    });
    return json({ error: "refund_failed", message: "คืนเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง" }, 502);
  }
});
