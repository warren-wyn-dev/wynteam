import { createClient } from "npm:@supabase/supabase-js@2.112.3";

type AdminClient = ReturnType<typeof createClient<any>>;

const STRIPE_V2_VERSION = "2026-07-29.dahlia";
const V2_ACCOUNT_SYNC_EVENTS = new Set([
  "v2.core.account.created",
  "v2.core.account.updated",
  "v2.core.account[defaults].updated",
  "v2.core.account[identity].updated",
  "v2.core.account[requirements].updated",
  "v2.core.account[configuration.merchant].updated",
  "v2.core.account[configuration.merchant].capability_status_updated",
]);

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
async function verifyAgainstConfiguredSecrets(body: string, header: string, configured: string[]) {
  const secrets = [...new Set(configured.map((value) => value.trim()).filter(Boolean))];
  for (const secret of secrets) {
    if (await verifyStripeSignature(body, header, secret)) return true;
  }
  return false;
}
async function vaultWebhookSecret(admin: AdminClient, name: "stripe_webhook_secret" | "stripe_v2_webhook_secret") {
  const { data, error } = await admin.rpc("food_get_stripe_webhook_secret", { p_name: name });
  if (error) {
    console.warn("stripe webhook vault secret unavailable", { name });
    return "";
  }
  return typeof data === "string" ? data.trim() : "";
}
function stringValue(value: unknown) { return typeof value === "string" ? value : null; }
function numberValue(value: unknown) { return typeof value === "number" && Number.isFinite(value) ? value : null; }
function stripeLivemode(secret: string) {
  if (/^(?:sk|rk)_live_/.test(secret)) return true;
  if (/^(?:sk|rk)_test_/.test(secret)) return false;
  return null;
}
function stripeV1Headers(secret: string, account?: string) {
  const headers: Record<string,string> = { Authorization: `Basic ${btoa(secret + ":")}` };
  if (account) headers["Stripe-Account"] = account;
  return headers;
}
function stripeV2Headers(secret: string) {
  return { Authorization: `Bearer ${secret}`, "Stripe-Version": STRIPE_V2_VERSION };
}
async function stripeJson(url: string, init: RequestInit) {
  const response = await fetch(url, init);
  const payload = await response.json().catch(() => ({})) as Record<string,unknown>;
  if (!response.ok) {
    const error = payload.error as Record<string,unknown> | undefined;
    console.error("stripe-webhook Stripe API error", {
      status: response.status,
      code: stringValue(error?.code),
      request_id: response.headers.get("request-id"),
    });
    throw new Error("stripe_api_error");
  }
  return payload;
}
function capabilityStatus(capabilities: Record<string,unknown>, key: string) {
  const value = capabilities[key] as Record<string,unknown> | undefined;
  return stringValue(value?.status);
}
function requirementsDueCount(requirements: Record<string,unknown>) {
  const entries = Array.isArray(requirements.entries) ? requirements.entries as Array<Record<string,unknown>> : [];
  return entries.filter((entry) => {
    if (entry.awaiting_action_from !== "user") return false;
    const deadline = entry.minimum_deadline as Record<string,unknown> | undefined;
    return deadline?.status === "currently_due" || deadline?.status === "past_due";
  }).length;
}
function promptPayStatus(value: unknown): "active" | "pending" | "inactive" | "unsupported" | "unrequested" | "unknown" {
  if (value === "active" || value === "pending" || value === "inactive" || value === "unsupported" || value === "unrequested") return value;
  return "unknown";
}
function payoutInterval(value: unknown): "daily" | "weekly" | "monthly" | "manual" | "unknown" {
  if (value === "daily" || value === "weekly" || value === "monthly" || value === "manual") return value;
  return "unknown";
}
function thbAmount(rows: unknown) {
  if (!Array.isArray(rows)) return 0;
  const row = rows.find((item) => String((item as Record<string,unknown>).currency ?? "").toLowerCase() === "thb") as Record<string,unknown> | undefined;
  return Math.max(0, Math.trunc(numberValue(row?.amount) ?? 0));
}
async function fetchBank(secret: string, accountId: string) {
  try {
    const payload = await stripeJson(
      `https://api.stripe.com/v1/accounts/${encodeURIComponent(accountId)}/external_accounts?object=bank_account&limit=10`,
      { headers: stripeV1Headers(secret) },
    );
    const data = Array.isArray(payload.data) ? payload.data as Array<Record<string,unknown>> : [];
    const bank = data.find((item) => item.default_for_currency === true && String(item.currency ?? "").toLowerCase() === "thb")
      ?? data.find((item) => String(item.currency ?? "").toLowerCase() === "thb")
      ?? data[0];
    const last4 = stringValue(bank?.last4);
    const status = stringValue(bank?.status);
    return {
      ready: Boolean(last4) && !["errored","verification_failed","tokenized_account_number_deactivated"].includes(status ?? ""),
      name: stringValue(bank?.bank_name),
      last4: last4 && /^\d{4}$/.test(last4) ? last4 : null,
    };
  } catch {
    return { ready: false, name: null, last4: null };
  }
}
async function fetchBalance(secret: string, accountId: string) {
  try {
    const payload = await stripeJson("https://api.stripe.com/v1/balance", { headers: stripeV1Headers(secret, accountId) });
    return { pending: thbAmount(payload.pending), available: thbAmount(payload.available) };
  } catch {
    return { pending: 0, available: 0 };
  }
}
async function fetchPromptPayStatus(secret: string, accountId: string) {
  try {
    const payload = await stripeJson(
      "https://api.stripe.com/v1/payment_method_configurations?active=true&limit=100",
      { headers: stripeV1Headers(secret, accountId) },
    );
    const configs = Array.isArray(payload.data) ? payload.data as Array<Record<string,unknown>> : [];
    const config = configs.find((item) => item.is_default === true) ?? configs[0];
    const promptpay = config?.promptpay as Record<string,unknown> | undefined;
    if (!promptpay) return "unsupported" as const;
    if (promptpay.available === true) return "active" as const;
    const display = (promptpay.display_preference ?? {}) as Record<string,unknown>;
    const effective = stringValue(display.value);
    const preference = stringValue(display.preference);
    if (effective === "on" || preference === "on") return "pending" as const;
    if (effective === "off" || preference === "off") return "inactive" as const;
    return "unknown" as const;
  } catch {
    return "unknown" as const;
  }
}

async function fetchPayoutInterval(secret: string, accountId: string) {
  try {
    const payload = await stripeJson("https://api.stripe.com/v1/balance_settings", { headers: stripeV1Headers(secret, accountId) });
    const payments = (payload.payments ?? {}) as Record<string,unknown>;
    const payouts = (payments.payouts ?? {}) as Record<string,unknown>;
    const schedule = (payouts.schedule ?? {}) as Record<string,unknown>;
    return payoutInterval(schedule.interval);
  } catch {
    return "unknown";
  }
}
async function syncMappedAccount(admin: AdminClient, secret: string, accountId: string) {
  const { data: saved } = await admin.from("food_stripe_accounts")
    .select("store_id,account_api_version,livemode").eq("stripe_account_id", accountId).maybeSingle();
  if (!saved?.store_id) return false;
  const keyLivemode = stripeLivemode(secret);
  if (keyLivemode == null || saved.livemode !== keyLivemode) return false;

  const [bank, balance, payoutSchedule, ppStatus] = await Promise.all([
    fetchBank(secret, accountId),
    fetchBalance(secret, accountId),
    fetchPayoutInterval(secret, accountId),
    fetchPromptPayStatus(secret, accountId),
  ]);

  let details = false;
  let charges = false;
  let payouts = false;
  let dueCount = 0;
  let restricted = false;
  const accountApi = saved.account_api_version === "v2" ? "v2" : "v1";

  if (accountApi === "v2") {
    const query = new URLSearchParams();
    query.append("include[0]", "configuration.merchant");
    query.append("include[1]", "requirements");
    const account = await stripeJson(
      `https://api.stripe.com/v2/core/accounts/${encodeURIComponent(accountId)}?${query.toString()}`,
      { headers: stripeV2Headers(secret) },
    );
    const configuration = (account.configuration ?? {}) as Record<string,unknown>;
    const merchant = (configuration.merchant ?? {}) as Record<string,unknown>;
    const capabilities = (merchant.capabilities ?? {}) as Record<string,unknown>;
    const card = capabilities.card_payments as Record<string,unknown> | undefined;
    const cardStatus = capabilityStatus(capabilities, "card_payments");
    const stripeBalance = capabilities.stripe_balance as Record<string,unknown> | undefined;
    const payoutCapability = stripeBalance?.payouts as Record<string,unknown> | undefined;
    const requirements = (account.requirements ?? {}) as Record<string,unknown>;
    dueCount = requirementsDueCount(requirements);
    details = cardStatus === "active" || (cardStatus === "pending" && dueCount === 0);
    charges = cardStatus === "active";
    payouts = stringValue(payoutCapability?.status) === "active";
    const cardDetails = Array.isArray(card?.status_details) ? card.status_details as Array<Record<string,unknown>> : [];
    restricted = cardStatus === "unsupported" || cardDetails.some((item) => item.resolution === "contact_stripe");
  } else {
    const account = await stripeJson(`https://api.stripe.com/v1/accounts/${encodeURIComponent(accountId)}`, {
      headers: stripeV1Headers(secret),
    });
    const requirements = (account.requirements ?? {}) as Record<string,unknown>;
    const dueValues = [
      ...(Array.isArray(requirements.currently_due) ? requirements.currently_due : []),
      ...(Array.isArray(requirements.past_due) ? requirements.past_due : []),
    ].map(String);
    dueCount = new Set(dueValues).size;
    details = account.details_submitted === true;
    charges = account.charges_enabled === true;
    payouts = account.payouts_enabled === true;
    restricted = typeof requirements.disabled_reason === "string" && requirements.disabled_reason.length > 0;
  }

  const automaticPayouts = payoutSchedule !== "manual" && payoutSchedule !== "unknown";
  const ready = charges && payouts && dueCount === 0 && bank.ready && automaticPayouts;
  const status = ready ? "ready" : restricted ? "restricted" : dueCount > 0 ? "onboarding" : "pending";
  const now = new Date().toISOString();
  const { error: updateError } = await admin.from("food_stripe_accounts").update({
    account_api_version: accountApi,
    details_submitted: details,
    charges_enabled: charges,
    payouts_enabled: payouts,
    promptpay_enabled: ppStatus === "active",
    promptpay_status: ppStatus,
    requirements_due_count: dueCount,
    bank_ready: bank.ready,
    bank_name: bank.name,
    bank_last4: bank.last4,
    payout_interval: payoutSchedule,
    balance_pending_satang: balance.pending,
    balance_available_satang: balance.available,
    last_error_code: null,
    status,
    last_synced_at: now,
    updated_at: now,
  }).eq("store_id", saved.store_id);
  if (updateError) throw updateError;
  await admin.from("food_stores").update({ stripe_payments_enabled: ready }).eq("id", saved.store_id);
  return true;
}
async function claimAccountSyncEvent(admin: AdminClient, eventId: string, eventType: string, accountId: string | null, objectId: string | null) {
  const { data, error } = await admin.rpc("food_claim_stripe_webhook_event", {
    p_event_id: eventId,
    p_event_type: eventType,
    p_stripe_account_id: accountId,
    p_object_id: objectId,
  });
  if (error) throw error;
  return data === true;
}
async function releaseAccountSyncEventClaim(admin: AdminClient, eventId: string, eventType: string) {
  const { error } = await admin.rpc("food_release_stripe_webhook_event_claim", {
    p_event_id: eventId,
    p_event_type: eventType,
  });
  if (error) console.warn("stripe webhook claim release failed", { eventId, eventType });
}
async function recordNoop(admin: AdminClient, eventId: string, eventType: string, accountId: string | null, objectId: string | null) {
  const { data, error } = await admin.rpc("food_apply_stripe_event", {
    p_event_id: eventId, p_event_type: eventType, p_order_id: null, p_stripe_account_id: accountId,
    p_object_id: objectId, p_checkout_session_id: null, p_payment_intent_id: null, p_amount_satang: null,
    p_currency: "thb", p_state: "noop", p_payment_method: null, p_note: null, p_refund_id: null,
  });
  if (error) throw error;
  return data === true;
}



Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim() ?? "";
  if (!url || !key) return json({ error: "not_configured" }, 503);
  const stripeLiveMode = stripeLivemode(stripeSecret);
  if (stripeSecret && stripeLiveMode == null) return json({ error: "not_configured" }, 503);

  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const envSnapshotSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET")?.trim() ?? "";
  const envV2Secret = Deno.env.get("STRIPE_V2_WEBHOOK_SECRET")?.trim() ?? "";
  const vaultSnapshotSecret = await vaultWebhookSecret(admin, "stripe_webhook_secret");
  const vaultV2Secret = await vaultWebhookSecret(admin, "stripe_v2_webhook_secret");
  const configuredSecrets = [envSnapshotSecret, vaultSnapshotSecret, envV2Secret, vaultV2Secret];
  if (!configuredSecrets.some(Boolean)) return json({ error: "not_configured" }, 503);

  const raw = await req.text();
  const signature = req.headers.get("stripe-signature") ?? "";
  if (!(await verifyAgainstConfiguredSecrets(raw, signature, configuredSecrets))) {
    return json({ error: "invalid_signature" }, 400);
  }

  let event: Record<string,unknown>;
  try { event = JSON.parse(raw) as Record<string,unknown>; }
  catch { return json({ error: "invalid_json" }, 400); }

  const eventId = stringValue(event.id);
  const eventType = stringValue(event.type);
  if (!eventId || !eventType) return json({ error: "invalid_event" }, 400);

  // Accounts v2 thin events for connected accounts arrive in "Your account"
  // scope. Only the account lifecycle/configuration events WYNOS needs may
  // trigger a state sync, and the signed related object must be an Account.
  if (V2_ACCOUNT_SYNC_EVENTS.has(eventType)) {
    const related = event.related_object as Record<string,unknown> | undefined;
    if (stringValue(related?.type) !== "v2.core.account") return json({ error: "invalid_related_object" }, 400);
    const accountId = stringValue(related?.id);
    if (!accountId || !stripeSecret) return json({ error: "account_sync_unavailable" }, 503);
    let claimed = false;
    try {
      claimed = await claimAccountSyncEvent(admin, eventId, eventType, accountId, accountId);
      if (!claimed) return json({ received: true, duplicate: true });
      const mapped = await syncMappedAccount(admin, stripeSecret, accountId);
      return json({ received: true, mapped });
    } catch {
      if (claimed) await releaseAccountSyncEventClaim(admin, eventId, eventType);
      console.error("stripe v2 account event failed", { eventId, eventType });
      return json({ error: "event_processing_failed" }, 500);
    }
  }
  if (eventType.startsWith("v2.core.account")) {
    return json({ received: true, ignored: true });
  }

  const stripeAccountId = stringValue(event.account);
  const data = event.data as Record<string,unknown> | undefined;
  const object = data?.object as Record<string,unknown> | undefined;
  if (!object) return json({ error: "invalid_event" }, 400);

  if (eventType === "account.updated") {
    const accountId = stringValue(object.id) ?? stripeAccountId;
    let claimed = false;
    try {
      claimed = await claimAccountSyncEvent(admin, eventId, eventType, accountId, accountId);
      if (!claimed) return json({ received: true, duplicate: true });
      if (accountId && stripeSecret) await syncMappedAccount(admin, stripeSecret, accountId);
      return json({ received: true });
    } catch {
      if (claimed) await releaseAccountSyncEventClaim(admin, eventId, eventType);
      return json({ error: "event_processing_failed" }, 500);
    }
  }

  if (eventType === "payout.paid" || eventType === "payout.failed" || eventType === "payout.updated" || eventType === "payout.created") {
    const payoutId = stringValue(object.id);
    if (!payoutId || !stripeAccountId) return json({ received: true, ignored: true });
    const amount = Math.max(0, Math.trunc(numberValue(object.amount) ?? 0));
    const arrivalEpoch = numberValue(object.arrival_date);
    const arrivalDate = arrivalEpoch ? new Date(arrivalEpoch * 1000).toISOString().slice(0, 10) : null;
    const rawStatus = stringValue(object.status);
    const payoutStatus = rawStatus === "in_transit" || rawStatus === "paid" || rawStatus === "failed" || rawStatus === "canceled"
      ? rawStatus
      : "pending";
    const createdEpoch = numberValue(object.created);
    const { data: applied, error: payoutError } = await admin.rpc("food_record_stripe_payout_event", {
      p_event_id: eventId,
      p_event_type: eventType,
      p_stripe_account_id: stripeAccountId,
      p_payout_id: payoutId,
      p_amount_satang: amount,
      p_currency: stringValue(object.currency) ?? "thb",
      p_status: payoutStatus,
      p_arrival_date: arrivalDate,
      p_failure_code: eventType === "payout.failed" ? stringValue(object.failure_code) : null,
      p_stripe_created_at: createdEpoch ? new Date(createdEpoch * 1000).toISOString() : null,
    });
    if (payoutError) return json({ error: "event_processing_failed" }, 500);
    return json({ received: true, duplicate: applied === false });
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

  if (orderId && stripeLiveMode != null) {
    const { data: paymentEnvironment } = await admin.from("food_stripe_payments")
      .select("livemode").eq("order_id", orderId).maybeSingle();
    if (typeof paymentEnvironment?.livemode === "boolean" && paymentEnvironment.livemode !== stripeLiveMode) {
      return json({ received: true, ignored: true });
    }
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
    const request = event.request as Record<string,unknown> | undefined;
    console.warn("stripe payment failed", {
      event_id: eventId,
      event_type: eventType,
      decline_code: stringValue(lastError?.decline_code),
      request_id: stringValue(request?.id),
    });
    note = "การชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง";
  } else if (eventType === "charge.refunded") {
    const refunded = numberValue(object.amount_refunded);
    const original = numberValue(object.amount);
    if (refunded != null && original != null && refunded >= original) {
      state = "refunded";
      amount = original;
    }
  } else if (eventType === "refund.created" || eventType === "refund.updated") {
    if (object.status === "succeeded") {
      refundId = stringValue(object.id);
      amount = numberValue(object.amount);
      if (orderId && amount != null) {
        const { data: order } = await admin.from("food_orders").select("total").eq("id", orderId).maybeSingle();
        const expected = Math.round(Number(order?.total ?? 0) * 100);
        state = expected > 0 && amount === expected ? "refunded" : "noop";
      }
    }
  } else if (eventType === "refund.failed") {
    console.warn("stripe refund failed", { eventType, refundId: stringValue(object.id) });
    state = "noop";
    refundId = stringValue(object.id);
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
