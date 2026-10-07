import { createClient } from "npm:@supabase/supabase-js@2.112.3";

function serviceKey() {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) return null;
  try { const keys = JSON.parse(raw) as Record<string,string>; return keys.default ?? Object.values(keys)[0] ?? null; }
  catch { return null; }
}
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}
function constantTimeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i=0;i<a.length;i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
async function hmacHex(secret: string, value: string) {
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return [...new Uint8Array(signature)].map((b) => b.toString(16).padStart(2,"0")).join("");
}
async function verifyStripeSignature(body: string, header: string, secret: string) {
  const parts = header.split(",").map((part) => part.trim());
  const timestamp = parts.find((part) => part.startsWith("t="))?.slice(2);
  const signatures = parts.filter((part) => part.startsWith("v1=")).map((part) => part.slice(3));
  if (!timestamp || !signatures.length) return false;
  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(Math.floor(Date.now()/1000) - ts) > 300) return false;
  const expected = await hmacHex(secret, `${timestamp}.${body}`);
  return signatures.some((signature) => constantTimeEqual(signature, expected));
}
function stringValue(value: unknown) { return typeof value === "string" ? value : null; }
function numberValue(value: unknown) { return typeof value === "number" && Number.isFinite(value) ? value : null; }

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET")?.trim();
  if (!url || !key || !secret) return json({ error: "not_configured" }, 503);

  const raw = await req.text();
  const signature = req.headers.get("stripe-signature") ?? "";
  if (!(await verifyStripeSignature(raw, signature, secret))) return json({ error: "invalid_signature" }, 400);

  let event: Record<string,unknown>;
  try { event = JSON.parse(raw) as Record<string,unknown>; }
  catch { return json({ error: "invalid_json" }, 400); }

  const eventId = stringValue(event.id);
  const eventType = stringValue(event.type);
  const stripeAccountId = stringValue(event.account);
  const data = event.data as Record<string,unknown> | undefined;
  const object = data?.object as Record<string,unknown> | undefined;
  if (!eventId || !eventType || !object) return json({ error: "invalid_event" }, 400);

  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

  if (eventType === "account.updated") {
    const accountId = stringValue(object.id);
    if (accountId) {
      const capabilities = (object.capabilities ?? {}) as Record<string,unknown>;
      const requirements = (object.requirements ?? {}) as Record<string,unknown>;
      const details = object.details_submitted === true;
      const charges = object.charges_enabled === true;
      const disabled = typeof requirements.disabled_reason === "string" && requirements.disabled_reason.length > 0;
      const state = details && charges ? "ready" : disabled ? "restricted" : details ? "pending" : "onboarding";
      const { data: saved } = await admin.from("food_stripe_accounts").select("store_id").eq("stripe_account_id", accountId).maybeSingle();
      if (saved?.store_id) {
        await admin.from("food_stripe_accounts").update({
          details_submitted: details,
          charges_enabled: charges,
          payouts_enabled: object.payouts_enabled === true,
          promptpay_enabled: capabilities.promptpay_payments === "active",
          status: state,
          last_synced_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }).eq("store_id", saved.store_id);
        await admin.from("food_stores").update({ stripe_payments_enabled: state === "ready" }).eq("id", saved.store_id);
      }
    }
    await admin.rpc("food_apply_stripe_event", {
      p_event_id: eventId, p_event_type: eventType, p_order_id: null, p_stripe_account_id: accountId ?? stripeAccountId,
      p_object_id: accountId, p_checkout_session_id: null, p_payment_intent_id: null, p_amount_satang: null,
      p_currency: "thb", p_state: "noop", p_payment_method: null, p_note: null, p_refund_id: null,
    });
    return json({ received: true });
  }

  let orderId: string | null = null;
  const metadata = (object.metadata ?? {}) as Record<string,unknown>;
  orderId = stringValue(metadata.order_id) ?? stringValue(metadata.wynos_order_id) ?? stringValue(object.client_reference_id);
  const sessionId = eventType.startsWith("checkout.session.") ? stringValue(object.id) : null;
  let paymentIntentId = stringValue(object.payment_intent);
  if (eventType.startsWith("payment_intent.")) paymentIntentId = stringValue(object.id);

  if (!orderId && paymentIntentId) {
    const { data: payment } = await admin.from("food_stripe_payments").select("order_id").eq("payment_intent_id", paymentIntentId).maybeSingle();
    orderId = payment?.order_id ?? null;
  }
  if (!orderId && sessionId) {
    const { data: payment } = await admin.from("food_stripe_payments").select("order_id").eq("checkout_session_id", sessionId).maybeSingle();
    orderId = payment?.order_id ?? null;
  }

  let state: "paid" | "failed" | "refunded" | "noop" = "noop";
  let amount = numberValue(object.amount_total) ?? numberValue(object.amount);
  const currency = stringValue(object.currency) ?? "thb";
  let paymentMethod: string | null = null;
  let note: string | null = null;
  let refundId: string | null = null;

  if (eventType === "checkout.session.completed" || eventType === "checkout.session.async_payment_succeeded") {
    if (object.payment_status === "paid") state = "paid";
    const types = object.payment_method_types;
    if (Array.isArray(types) && typeof types[0] === "string") paymentMethod = types[0];
  } else if (eventType === "checkout.session.async_payment_failed" || eventType === "payment_intent.payment_failed") {
    state = "failed";
    const lastError = object.last_payment_error as Record<string,unknown> | undefined;
    note = stringValue(lastError?.message) ?? "Stripe payment failed";
  } else if (eventType === "charge.refunded") {
    const refunded = numberValue(object.amount_refunded);
    const original = numberValue(object.amount);
    if (refunded != null && original != null && refunded >= original) {
      state = "refunded";
      amount = original;
    }
  } else if (eventType === "refund.created" || eventType === "refund.updated") {
    if (object.status === "succeeded") {
      state = "refunded";
      refundId = stringValue(object.id);
      amount = numberValue(object.amount);
    }
  }

  const { error } = await admin.rpc("food_apply_stripe_event", {
    p_event_id: eventId,
    p_event_type: eventType,
    p_order_id: orderId,
    p_stripe_account_id: stripeAccountId,
    p_object_id: stringValue(object.id),
    p_checkout_session_id: sessionId,
    p_payment_intent_id: paymentIntentId,
    p_amount_satang: amount,
    p_currency: currency,
    p_state: state,
    p_payment_method: paymentMethod,
    p_note: note,
    p_refund_id: refundId,
  });
  if (error) return json({ error: "event_processing_failed" }, 500);
  return json({ received: true });
});
