import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import { refundResponseState, verifiedApplicationFeeRefund } from "./_lib.ts";

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

  const { data: payment, error: paymentError } = await admin.from("food_stripe_payments")
    .select("stripe_account_id,livemode,application_fee_satang").eq("order_id", order.id).maybeSingle();
  if (paymentError) return json({ error: "payment_record_unavailable" }, 503);

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
  // GP v1: a full refund also returns the WYNOS GP (application fee) to the store.
  const feeSatang = Number(payment?.application_fee_satang ?? 0);
  if (!Number.isSafeInteger(feeSatang) || feeSatang < 0) return json({ error: "application_fee_record_invalid" }, 503);
  if (feeSatang > 0) params.set("refund_application_fee", "true");
  params.set("metadata[wynos_order_id]", order.id);
  if (note) params.set("metadata[wynos_note]", note);

  let payload: Record<string, unknown>;
  let refundStatus: "pending" | "failed";
  try {
    const response = await fetch("https://api.stripe.com/v1/refunds", {
      method: "POST",
      headers: stripeHeaders(stripeSecret, stripeAccountId, `wynos-refund-${order.id}`),
      body: params,
    });
    payload = await response.json().catch(() => ({})) as Record<string,unknown>;
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
    refundStatus = refundResponseState(payload.status);
  } catch {
    // A timeout/invalid response can occur after Stripe accepted the request.
    // Keep the persisted state and reuse the same idempotency key on retry.
    console.error("merchant-stripe-refund request outcome unavailable", { order_id: order.id });
    return json({
      error: "refund_failed",
      message: "คืนเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง",
    }, 502);
  }

  let orderRecordPending = false;
  try {
    const { data: recorded, error: recordError } = await admin.from("food_orders").update({
      refund_status: refundStatus,
      refund_note: note || "Stripe refund requested",
      refund_requested_at: new Date().toISOString(),
      refund_updated_by: user.id,
      stripe_refund_id: payload.id,
    }).eq("id", order.id).eq("status", "cancelled").eq("payment_status", "paid")
      .neq("refund_status", "refunded").select("id").maybeSingle();
    orderRecordPending = Boolean(recordError) || !recorded;
  } catch {
    orderRecordPending = true;
  }
  if (orderRecordPending) {
    console.warn("merchant-stripe-refund order recording requires reconciliation", { order_id: order.id, stripe_refund_id: payload.id });
  }

  // A pending customer refund must never create a GP credit. Even a succeeded
  // customer refund needs independent evidence from the platform's fee object.
  let gpRecordPending = feeSatang > 0;
  if (feeSatang > 0 && payload.status === "succeeded" && typeof payload.charge === "string") {
    try {
      const chargeResponse = await fetch(`https://api.stripe.com/v1/charges/${encodeURIComponent(payload.charge)}`, {
        headers: { Authorization: `Basic ${btoa(stripeSecret + ":")}`, "Stripe-Account": stripeAccountId },
      });
      const charge = await chargeResponse.json() as Record<string, unknown>;
      const feeId = chargeResponse.ok && charge.id === payload.charge && typeof charge.application_fee === "string"
        ? charge.application_fee : null;
      if (!feeId) throw new Error("application_fee_unavailable");
      const feeResponse = await fetch(`https://api.stripe.com/v1/application_fees/${encodeURIComponent(feeId)}`, {
        headers: { Authorization: `Basic ${btoa(stripeSecret + ":")}` },
      });
      const fee = await feeResponse.json() as Record<string, unknown>;
      const confirmedSatang = feeResponse.ok && fee.id === feeId
        ? verifiedApplicationFeeRefund(fee, feeSatang, stripeAccountId, payload.charge) : null;
      if (confirmedSatang == null) throw new Error("application_fee_refund_unconfirmed");
      const refundedAt = new Date().toISOString();
      let recordError: unknown = null;
      for (let attempt = 0; attempt < 3; attempt += 1) {
        const { data: updated, error: updateError } = await admin.from("food_stripe_payments").update({
          application_fee_refunded_satang: confirmedSatang,
          application_fee_refunded_at: refundedAt,
        }).eq("order_id", order.id).eq("application_fee_refunded_satang", 0).select("order_id").maybeSingle();
        recordError = updateError;
        if (!updateError && !updated) {
          const { data: saved, error: readError } = await admin.from("food_stripe_payments")
            .select("application_fee_refunded_satang").eq("order_id", order.id).maybeSingle();
          recordError = readError || (Number(saved?.application_fee_refunded_satang) === confirmedSatang
            ? null : new Error("application_fee_record_missing"));
        }
        if (!recordError) break;
      }
      gpRecordPending = Boolean(recordError);
    } catch {
      console.warn("merchant-stripe-refund GP refund requires reconciliation", { order_id: order.id, stripe_refund_id: payload.id });
    }
  }
  if (refundStatus === "failed") {
    return json({
      error: "refund_failed",
      message: "คืนเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง",
    }, 502);
  }
  return json({ status: payload.status, refundId: payload.id, gpRecordPending, orderRecordPending });
});
