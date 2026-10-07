import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const STRIPE_V2_VERSION = "2026-07-29.dahlia";

function serviceKey() {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) return null;
  try {
    const keys = JSON.parse(raw) as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? null;
  } catch {
    return null;
  }
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function constantTimeEqual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

async function hmacHex(secret: string, value: string) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(value));
  return [...new Uint8Array(signature)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function verifyStripeSignature(body: string, header: string, secret: string) {
  const parts = header.split(",").map((part) => part.trim());
  const timestamp = parts.find((part) => part.startsWith("t="))?.slice(2);
  const signatures = parts.filter((part) => part.startsWith("v1=")).map((part) => part.slice(3));
  if (!timestamp || !signatures.length) return false;
  const ts = Number(timestamp);
  if (!Number.isFinite(ts) || Math.abs(Math.floor(Date.now() / 1000) - ts) > 300) return false;
  const expected = await hmacHex(secret, `${timestamp}.${body}`);
  return signatures.some((signature) => constantTimeEqual(signature, expected));
}

async function verifyAgainstConfiguredSecrets(body: string, signature: string) {
  const secrets = [
    Deno.env.get("STRIPE_WEBHOOK_SECRET")?.trim(),
    Deno.env.get("STRIPE_V2_WEBHOOK_SECRET")?.trim(),
  ].filter((value): value is string => Boolean(value));
  if (!secrets.length) return { configured: false, valid: false };
  for (const secret of secrets) {
    if (await verifyStripeSignature(body, signature, secret)) return { configured: true, valid: true };
  }
  return { configured: true, valid: false };
}

function stringValue(value: unknown) {
  return typeof value === "string" ? value : null;
}

function numberValue(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function stripeV1Headers(secret: string, accountId?: string) {
  const headers: Record<string, string> = {
    Authorization: `Basic ${btoa(secret + ":")}`,
  };
  if (accountId) headers["Stripe-Account"] = accountId;
  return headers;
}

function stripeV2Headers(secret: string) {
  return {
    Authorization: `Bearer ${secret}`,
    "Stripe-Version": STRIPE_V2_VERSION,
  };
}

async function stripeJson(url: string, init: RequestInit) {
  const response = await fetch(url, init);
  const payload = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok) {
    const err = payload.error as Record<string, unknown> | undefined;
    console.error("stripe-webhook api failure", {
      code: stringValue(err?.code),
      status: response.status,
      request_id: response.headers.get("request-id"),
    });
    throw new Error("stripe_api_failed");
  }
  return payload;
}

function requirementEntries(account: Record<string, unknown>) {
  const requirements = (account.requirements ?? {}) as Record<string, unknown>;
  return Array.isArray(requirements.entries)
    ? requirements.entries as Array<Record<string, unknown>>
    : [];
}

function requirementNeedsUser(entry: Record<string, unknown>) {
  if (entry.awaiting_action_from !== "user") return false;
  const deadline = entry.minimum_deadline as Record<string, unknown> | undefined;
  const status = stringValue(deadline?.status);
  return status === "currently_due" || status === "past_due";
}

function capabilityStatus(capabilities: Record<string, unknown>, key: string) {
  const value = capabilities[key] as Record<string, unknown> | undefined;
  return stringValue(value?.status);
}

function promptpayStatus(status: string | null) {
  return status === "active" || status === "pending" || status === "inactive" ||
      status === "unsupported" || status === "unrequested"
    ? status
    : "unknown";
}

async function retrieveBank(secret: string, accountId: string) {
  try {
    const query = new URLSearchParams({ object: "bank_account", limit: "10" });
    const payload = await stripeJson(
      `https://api.stripe.com/v1/accounts/${encodeURIComponent(accountId)}/external_accounts?${query.toString()}`,
      { headers: stripeV1Headers(secret) },
    );
    const data = Array.isArray(payload.data) ? payload.data as Array<Record<string, unknown>> : [];
    const selected =
      data.find((item) => item.currency === "thb" && item.default_for_currency === true) ??
      data.find((item) => item.currency === "thb") ??
      data[0];
    if (!selected) return { ready: false, bankName: null, last4: null };
    const last4 = typeof selected.last4 === "string" && /^\d{4}$/.test(selected.last4) ? selected.last4 : null;
    const bankName = typeof selected.bank_name === "string" && selected.bank_name.trim()
      ? selected.bank_name.trim().slice(0, 120)
      : null;
    const status = stringValue(selected.status);
    return {
      ready: Boolean(last4) && status !== "errored" && status !== "verification_failed",
      bankName,
      last4,
    };
  } catch {
    return { ready: false, bankName: null, last4: null };
  }
}

async function retrievePayoutInterval(secret: string, accountId: string) {
  try {
    const payload = await stripeJson("https://api.stripe.com/v1/balance_settings", {
      headers: stripeV1Headers(secret, accountId),
    });
    const payments = payload.payments as Record<string, unknown> | undefined;
    const payouts = payments?.payouts as Record<string, unknown> | undefined;
    const schedule = payouts?.schedule as Record<string, unknown> | undefined;
    const interval = stringValue(schedule?.interval);
    return interval === "daily" || interval === "weekly" || interval === "monthly" || interval === "manual"
      ? interval
      : "unknown";
  } catch {
    return "unknown";
  }
}

async function syncV2Account(
  admin: ReturnType<typeof createClient>,
  stripeSecret: string,
  accountId: string,
) {
  const { data: saved } = await admin
    .from("food_stripe_accounts")
    .select("store_id")
    .eq("stripe_account_id", accountId)
    .maybeSingle();
  if (!saved?.store_id) return false;

  const query = new URLSearchParams();
  query.append("include[0]", "configuration.merchant");
  query.append("include[1]", "identity");
  query.append("include[2]", "defaults");
  query.append("include[3]", "requirements");
  const account = await stripeJson(
    `https://api.stripe.com/v2/core/accounts/${encodeURIComponent(accountId)}?${query.toString()}`,
    { headers: stripeV2Headers(stripeSecret) },
  );

  const configuration = (account.configuration ?? {}) as Record<string, unknown>;
  const merchant = (configuration.merchant ?? {}) as Record<string, unknown>;
  const capabilities = (merchant.capabilities ?? {}) as Record<string, unknown>;
  const card = capabilities.card_payments as Record<string, unknown> | undefined;
  const cardStatus = capabilityStatus(capabilities, "card_payments");
  const promptStatus = capabilityStatus(capabilities, "promptpay_payments");
  const stripeBalance = capabilities.stripe_balance as Record<string, unknown> | undefined;
  const payoutCapability = stripeBalance?.payouts as Record<string, unknown> | undefined;
  const payoutsStatus = stringValue(payoutCapability?.status);
  const cardDetails = Array.isArray(card?.status_details)
    ? card.status_details as Array<Record<string, unknown>>
    : [];
  const due = requirementEntries(account).filter(requirementNeedsUser);
  const needsInfo = due.length > 0 || cardDetails.some((detail) => detail.resolution === "provide_info");
  const restricted =
    cardStatus === "unsupported" ||
    cardDetails.some((detail) => detail.resolution === "contact_stripe");

  const [bank, interval] = await Promise.all([
    retrieveBank(stripeSecret, accountId),
    retrievePayoutInterval(stripeSecret, accountId),
  ]);
  const charges = cardStatus === "active";
  const payouts = payoutsStatus === "active";
  const ready = charges && payouts && !needsInfo && bank.ready;
  const status = ready ? "ready" : restricted ? "restricted" : needsInfo ? "onboarding" : "pending";

  const now = new Date().toISOString();
  await admin.from("food_stripe_accounts").update({
    account_api_version: "v2",
    details_submitted: !needsInfo && (charges || cardStatus === "pending" || cardStatus === "active"),
    charges_enabled: charges,
    payouts_enabled: payouts,
    promptpay_enabled: promptStatus === "active",
    promptpay_status: promptpayStatus(promptStatus),
    bank_ready: bank.ready,
    bank_name: bank.bankName,
    bank_last4: bank.last4,
    payout_interval: interval,
    requirements_due_count: due.length,
    status,
    last_error_code: null,
    last_synced_at: now,
    updated_at: now,
  }).eq("store_id", saved.store_id);
  await admin.from("food_stores").update({ stripe_payments_enabled: ready }).eq("id", saved.store_id);
  return true;
}

async function syncV1Account(
  admin: ReturnType<typeof createClient>,
  stripeSecret: string,
  object: Record<string, unknown>,
) {
  const accountId = stringValue(object.id);
  if (!accountId) return false;

  const { data: saved } = await admin
    .from("food_stripe_accounts")
    .select("store_id")
    .eq("stripe_account_id", accountId)
    .maybeSingle();
  if (!saved?.store_id) return false;

  const capabilities = (object.capabilities ?? {}) as Record<string, unknown>;
  const requirements = (object.requirements ?? {}) as Record<string, unknown>;
  const currentDue = Array.isArray(requirements.currently_due) ? requirements.currently_due.length : 0;
  const pastDue = Array.isArray(requirements.past_due) ? requirements.past_due.length : 0;
  const due = currentDue + pastDue;
  const details = object.details_submitted === true;
  const charges = object.charges_enabled === true;
  const payouts = object.payouts_enabled === true;
  const disabled = Boolean(stringValue(requirements.disabled_reason));
  const [bank, interval] = await Promise.all([
    retrieveBank(stripeSecret, accountId),
    retrievePayoutInterval(stripeSecret, accountId),
  ]);
  const ready = details && charges && payouts && due === 0 && bank.ready;
  const status = ready ? "ready" : disabled ? "restricted" : due > 0 ? "onboarding" : "pending";
  const pp = typeof capabilities.promptpay_payments === "string" ? capabilities.promptpay_payments : null;
  const now = new Date().toISOString();

  await admin.from("food_stripe_accounts").update({
    account_api_version: "v1",
    details_submitted: details,
    charges_enabled: charges,
    payouts_enabled: payouts,
    promptpay_enabled: pp === "active",
    promptpay_status: promptpayStatus(pp),
    bank_ready: bank.ready,
    bank_name: bank.bankName,
    bank_last4: bank.last4,
    payout_interval: interval,
    requirements_due_count: due,
    status,
    last_error_code: null,
    last_synced_at: now,
    updated_at: now,
  }).eq("store_id", saved.store_id);
  await admin.from("food_stores").update({ stripe_payments_enabled: ready }).eq("id", saved.store_id);
  return true;
}

function unixDate(value: unknown) {
  const seconds = numberValue(value);
  if (seconds == null) return null;
  return new Date(seconds * 1000).toISOString().slice(0, 10);
}

function unixTimestamp(value: unknown) {
  const seconds = numberValue(value);
  return seconds == null ? null : new Date(seconds * 1000).toISOString();
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  if (!url || !key || !stripeSecret) return json({ error: "not_configured" }, 503);

  const raw = await req.text();
  const signature = req.headers.get("stripe-signature") ?? "";
  const verification = await verifyAgainstConfiguredSecrets(raw, signature);
  if (!verification.configured) return json({ error: "webhook_not_configured" }, 503);
  if (!verification.valid) return json({ error: "invalid_signature" }, 400);

  let event: Record<string, unknown>;
  try {
    event = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const eventId = stringValue(event.id);
  const eventType = stringValue(event.type);
  if (!eventId || !eventType) return json({ error: "invalid_event" }, 400);

  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });

  if (eventType.startsWith("v2.core.account")) {
    const related = event.related_object as Record<string, unknown> | undefined;
    const accountId = stringValue(related?.id);
    if (!accountId) return json({ error: "invalid_v2_account_event" }, 400);

    try {
      const mapped = await syncV2Account(admin, stripeSecret, accountId);
      if (!mapped) {
        console.error("stripe-webhook unmapped v2 account", { event_type: eventType });
        return json({ received: true, ignored: true });
      }
      const { error } = await admin.rpc("food_apply_stripe_event", {
        p_event_id: eventId,
        p_event_type: eventType,
        p_order_id: null,
        p_stripe_account_id: accountId,
        p_object_id: accountId,
        p_checkout_session_id: null,
        p_payment_intent_id: null,
        p_amount_satang: null,
        p_currency: "thb",
        p_state: "noop",
        p_payment_method: null,
        p_note: null,
        p_refund_id: null,
      });
      if (error) return json({ error: "event_processing_failed" }, 500);
      return json({ received: true });
    } catch {
      return json({ error: "event_processing_failed" }, 500);
    }
  }

  const stripeAccountId = stringValue(event.account);
  const data = event.data as Record<string, unknown> | undefined;
  const object = data?.object as Record<string, unknown> | undefined;
  if (!object) return json({ error: "invalid_event" }, 400);

  if (eventType === "account.updated") {
    const accountId = stringValue(object.id);
    if (!accountId) return json({ error: "invalid_account_event" }, 400);
    try {
      const mapped = await syncV1Account(admin, stripeSecret, object);
      if (!mapped) {
        console.error("stripe-webhook unmapped legacy account", { event_type: eventType });
        return json({ received: true, ignored: true });
      }
      const { error } = await admin.rpc("food_apply_stripe_event", {
        p_event_id: eventId,
        p_event_type: eventType,
        p_order_id: null,
        p_stripe_account_id: accountId,
        p_object_id: accountId,
        p_checkout_session_id: null,
        p_payment_intent_id: null,
        p_amount_satang: null,
        p_currency: "thb",
        p_state: "noop",
        p_payment_method: null,
        p_note: null,
        p_refund_id: null,
      });
      if (error) return json({ error: "event_processing_failed" }, 500);
      return json({ received: true });
    } catch {
      return json({ error: "event_processing_failed" }, 500);
    }
  }

  if (eventType === "payout.paid" || eventType === "payout.failed" || eventType === "payout.updated" || eventType === "payout.created") {
    const payoutId = stringValue(object.id);
    const status = stringValue(object.status);
    const currency = stringValue(object.currency) ?? "thb";
    const amount = numberValue(object.amount);
    if (!stripeAccountId || !payoutId || !status || amount == null) {
      return json({ error: "invalid_payout_event" }, 400);
    }
    const { error } = await admin.rpc("food_record_stripe_payout_event", {
      p_event_id: eventId,
      p_event_type: eventType,
      p_stripe_account_id: stripeAccountId,
      p_payout_id: payoutId,
      p_amount_satang: amount,
      p_currency: currency,
      p_status: status,
      p_arrival_date: unixDate(object.arrival_date),
      p_failure_code: stringValue(object.failure_code),
      p_stripe_created_at: unixTimestamp(object.created),
    });
    if (error) return json({ error: "event_processing_failed" }, 500);
    return json({ received: true });
  }

  let orderId: string | null = null;
  const metadata = (object.metadata ?? {}) as Record<string, unknown>;
  orderId =
    stringValue(metadata.order_id) ??
    stringValue(metadata.wynos_order_id) ??
    stringValue(object.client_reference_id);
  const sessionId = eventType.startsWith("checkout.session.") ? stringValue(object.id) : null;
  let paymentIntentId = stringValue(object.payment_intent);
  if (eventType.startsWith("payment_intent.")) paymentIntentId = stringValue(object.id);

  if (!orderId && paymentIntentId) {
    const { data: payment } = await admin
      .from("food_stripe_payments")
      .select("order_id")
      .eq("payment_intent_id", paymentIntentId)
      .maybeSingle();
    orderId = payment?.order_id ?? null;
  }
  if (!orderId && sessionId) {
    const { data: payment } = await admin
      .from("food_stripe_payments")
      .select("order_id")
      .eq("checkout_session_id", sessionId)
      .maybeSingle();
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
    const lastError = object.last_payment_error as Record<string, unknown> | undefined;
    console.error("stripe-webhook payment failed", {
      event_type: eventType,
      decline_code: stringValue(lastError?.decline_code),
      code: stringValue(lastError?.code),
    });
    note = "การชำระเงินไม่สำเร็จ กรุณาลองใหม่หรือเลือกวิธีชำระเงินอื่น";
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
