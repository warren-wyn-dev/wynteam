import { createClient } from "npm:@supabase/supabase-js@2.112.3";

type AdminClient = ReturnType<typeof createClient<any>>;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const STRIPE_V2_VERSION = "2026-07-29.dahlia";

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
function stripeV1Headers(secret: string, account?: string, idempotencyKey?: string) {
  const headers: Record<string,string> = {
    Authorization: `Basic ${btoa(secret + ":")}`,
    "Content-Type": "application/x-www-form-urlencoded",
  };
  if (account) headers["Stripe-Account"] = account;
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  return headers;
}
function stripeV2Headers(secret: string, idempotencyKey?: string) {
  const headers: Record<string,string> = {
    Authorization: `Bearer ${secret}`,
    "Content-Type": "application/json",
    "Stripe-Version": STRIPE_V2_VERSION,
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  return headers;
}
class StripeApiError extends Error {
  code: string | null;
  status: number;
  constructor(message: string, code: string | null, status: number) {
    super(message);
    this.name = "StripeApiError";
    this.code = code;
    this.status = status;
  }
}
async function stripeJson(url: string, init: RequestInit) {
  const response = await fetch(url, init);
  const payload = await response.json().catch(() => ({})) as Record<string,unknown>;
  if (!response.ok) {
    const err = payload.error as Record<string,unknown> | undefined;
    throw new StripeApiError(
      typeof err?.message === "string" ? err.message : "Stripe request failed",
      typeof err?.code === "string" ? err.code : null,
      response.status,
    );
  }
  return payload;
}
function stringValue(value: unknown) { return typeof value === "string" ? value : null; }
function numberValue(value: unknown) { return typeof value === "number" && Number.isFinite(value) ? value : null; }
function capabilityStatus(capabilities: Record<string,unknown>, key: string) {
  const value = capabilities[key] as Record<string,unknown> | undefined;
  return typeof value?.status === "string" ? value.status : null;
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
  const row = rows.find((item) => {
    const value = item as Record<string,unknown>;
    return String(value.currency ?? "").toLowerCase() === "thb";
  }) as Record<string,unknown> | undefined;
  return Math.max(0, Math.trunc(numberValue(row?.amount) ?? 0));
}
function safeStripeError(error: unknown) {
  if (error instanceof StripeApiError) return { code: error.code, status: error.status };
  return { code: "internal_error", status: 500 };
}
function thaiConnectMessage(error: unknown) {
  if (error instanceof StripeApiError) {
    if (error.code === "accounts_v2_access_blocked") return "ระบบรับชำระเงินสำหรับร้านค้ายังไม่พร้อมใช้งาน กรุณาลองใหม่ภายหลัง";
    if (error.status === 429) return "มีคำขอจำนวนมาก กรุณาลองใหม่อีกครั้งในอีกสักครู่";
    if (error.status >= 500) return "ระบบรับชำระเงินขัดข้องชั่วคราว กรุณาลองใหม่อีกครั้ง";
  }
  return "ไม่สามารถตั้งค่าการรับชำระเงินได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง";
}

type BankSummary = { ready: boolean; name: string | null; last4: string | null };
type MoneySummary = { pending: number; available: number };
type PayoutSummary = { interval: string | null };
type PromptPaySummary = {
  enabled: boolean;
  status: "active" | "pending" | "inactive" | "unsupported" | "unrequested" | "unknown";
};

async function retrieveAccount(secret: string, accountId: string) {
  const query = new URLSearchParams();
  query.append("include[0]", "configuration.merchant");
  query.append("include[1]", "identity");
  query.append("include[2]", "defaults");
  query.append("include[3]", "requirements");
  try {
    const account = await stripeJson(
      `https://api.stripe.com/v2/core/accounts/${encodeURIComponent(accountId)}?${query.toString()}`,
      { headers: stripeV2Headers(secret) },
    );
    return { account, api: "v2" as const };
  } catch (error) {
    if (!(error instanceof StripeApiError) || error.code !== "v1_account_instead_of_v2_account") throw error;
    const account = await stripeJson(`https://api.stripe.com/v1/accounts/${encodeURIComponent(accountId)}`, {
      headers: stripeV1Headers(secret),
    });
    return { account, api: "v1" as const };
  }
}
async function fetchBankSummary(secret: string, accountId: string): Promise<BankSummary> {
  try {
    const payload = await stripeJson(
      `https://api.stripe.com/v1/accounts/${encodeURIComponent(accountId)}/external_accounts?object=bank_account&limit=10`,
      { headers: stripeV1Headers(secret) },
    );
    const data = Array.isArray(payload.data) ? payload.data as Array<Record<string,unknown>> : [];
    const bank = data.find((item) => item.default_for_currency === true && String(item.currency ?? "").toLowerCase() === "thb")
      ?? data.find((item) => String(item.currency ?? "").toLowerCase() === "thb")
      ?? data[0];
    if (!bank) return { ready: false, name: null, last4: null };
    const status = stringValue(bank.status);
    const last4 = stringValue(bank.last4);
    return {
      ready: Boolean(last4) && !["errored","verification_failed","tokenized_account_number_deactivated"].includes(status ?? ""),
      name: stringValue(bank.bank_name),
      last4: last4 && /^\d{4}$/.test(last4) ? last4 : null,
    };
  } catch {
    return { ready: false, name: null, last4: null };
  }
}
async function fetchMoneySummary(secret: string, accountId: string): Promise<MoneySummary> {
  try {
    const payload = await stripeJson("https://api.stripe.com/v1/balance", {
      headers: stripeV1Headers(secret, accountId),
    });
    return { pending: thbAmount(payload.pending), available: thbAmount(payload.available) };
  } catch {
    return { pending: 0, available: 0 };
  }
}
async function fetchPayoutSummary(secret: string, accountId: string): Promise<PayoutSummary> {
  try {
    const payload = await stripeJson("https://api.stripe.com/v1/balance_settings", {
      headers: stripeV1Headers(secret, accountId),
    });
    const payments = (payload.payments ?? {}) as Record<string,unknown>;
    const payouts = (payments.payouts ?? {}) as Record<string,unknown>;
    const schedule = (payouts.schedule ?? {}) as Record<string,unknown>;
    return { interval: payoutInterval(schedule.interval) };
  } catch {
    return { interval: "unknown" };
  }
}
async function paymentMethodConfiguration(secret: string, accountId: string) {
  const payload = await stripeJson(
    "https://api.stripe.com/v1/payment_method_configurations?active=true&limit=100",
    { headers: stripeV1Headers(secret, accountId) },
  );
  const configs = Array.isArray(payload.data) ? payload.data as Array<Record<string,unknown>> : [];
  return configs.find((item) => item.is_default === true) ?? configs[0] ?? null;
}
async function fetchPromptPaySummary(secret: string, accountId: string): Promise<PromptPaySummary> {
  try {
    const config = await paymentMethodConfiguration(secret, accountId);
    const promptpay = config?.promptpay as Record<string,unknown> | undefined;
    if (!promptpay) return { enabled: false, status: "unsupported" };

    if (promptpay.available === true) return { enabled: true, status: "active" };
    const display = (promptpay.display_preference ?? {}) as Record<string,unknown>;
    const effective = stringValue(display.value);
    const preference = stringValue(display.preference);
    if (effective === "on" || preference === "on") return { enabled: false, status: "pending" };
    if (effective === "off" || preference === "off") return { enabled: false, status: "inactive" };
    return { enabled: false, status: "unknown" };
  } catch {
    return { enabled: false, status: "unknown" };
  }
}
async function preferPromptPay(secret: string, accountId: string) {
  try {
    const config = await paymentMethodConfiguration(secret, accountId);
    const configId = stringValue(config?.id);
    const promptpay = config?.promptpay as Record<string,unknown> | undefined;
    if (!configId || !promptpay) return;

    const display = (promptpay.display_preference ?? {}) as Record<string,unknown>;
    const effective = stringValue(display.value);
    const preference = stringValue(display.preference);
    if (promptpay.available === true || effective === "on" || preference === "on") return;

    const params = new URLSearchParams();
    params.set("promptpay[display_preference][preference]", "on");
    await stripeJson(
      `https://api.stripe.com/v1/payment_method_configurations/${encodeURIComponent(configId)}`,
      {
        method: "POST",
        headers: stripeV1Headers(secret, accountId, `wynos-promptpay-${accountId}`),
        body: params,
      },
    );
  } catch (error) {
    // PromptPay isn't available to every account. Keep cards working and
    // reflect the actual PromptPay state instead of failing onboarding.
    console.warn("merchant-stripe-connect PromptPay preference unchanged", safeStripeError(error));
  }
}

async function preferDailyPayouts(secret: string, accountId: string) {
  const params = new URLSearchParams();
  params.set("payments[payouts][schedule][interval]", "daily");
  try {
    await stripeJson("https://api.stripe.com/v1/balance_settings", {
      method: "POST",
      headers: stripeV1Headers(secret, accountId, `wynos-payout-daily-${accountId}`),
      body: params,
    });
  } catch (error) {
    // Daily isn't universally configurable. Keep Stripe's fastest permitted
    // automatic schedule instead of turning payouts manual or weakening risk controls.
    const safe = safeStripeError(error);
    console.warn("merchant-stripe-connect payout schedule unchanged", safe);
  }
}
function v1CoreState(account: Record<string,unknown>) {
  const capabilities = (account.capabilities ?? {}) as Record<string,unknown>;
  const requirements = (account.requirements ?? {}) as Record<string,unknown>;
  const dueValues = [
    ...(Array.isArray(requirements.currently_due) ? requirements.currently_due : []),
    ...(Array.isArray(requirements.past_due) ? requirements.past_due : []),
  ].map(String);
  const dueCount = new Set(dueValues).size;
  const disabled = typeof requirements.disabled_reason === "string" && requirements.disabled_reason.length > 0;
  const pp = promptPayStatus(capabilities.promptpay_payments);
  return {
    details: account.details_submitted === true,
    charges: account.charges_enabled === true,
    payouts: account.payouts_enabled === true,
    promptpayEnabled: pp === "active",
    promptpayStatus: pp,
    dueCount,
    needsInfo: dueCount > 0,
    restricted: disabled,
  };
}
function v2CoreState(account: Record<string,unknown>) {
  const configuration = (account.configuration ?? {}) as Record<string,unknown>;
  const merchant = (configuration.merchant ?? {}) as Record<string,unknown>;
  const capabilities = (merchant.capabilities ?? {}) as Record<string,unknown>;
  const card = capabilities.card_payments as Record<string,unknown> | undefined;
  const cardStatus = capabilityStatus(capabilities, "card_payments");

  const stripeBalance = capabilities.stripe_balance as Record<string,unknown> | undefined;
  const payouts = stripeBalance?.payouts as Record<string,unknown> | undefined;
  const payoutsStatus = stringValue(payouts?.status);
  const requirements = (account.requirements ?? {}) as Record<string,unknown>;
  const dueCount = requirementsDueCount(requirements);
  const cardDetails = Array.isArray(card?.status_details) ? card.status_details as Array<Record<string,unknown>> : [];
  const restricted = cardStatus === "unsupported" || cardDetails.some((detail) => detail.resolution === "contact_stripe");
  return {
    details: cardStatus === "active" || (cardStatus === "pending" && dueCount === 0),
    charges: cardStatus === "active",
    payouts: payoutsStatus === "active",
    dueCount,
    needsInfo: dueCount > 0,
    restricted,
  };
}
function composeState(
  core: ReturnType<typeof v1CoreState> | ReturnType<typeof v2CoreState>,
  bank: BankSummary,
  money: MoneySummary,
  payout: PayoutSummary,
  promptpay: PromptPaySummary,
) {
  const settings = payoutInterval(payout.interval);
  const charges = core.charges;
  const payoutsEnabled = core.payouts;
  const automaticPayouts = settings !== "manual" && settings !== "unknown";
  const ready = charges && payoutsEnabled && !core.needsInfo && bank.ready && automaticPayouts;
  const status = ready ? "ready" : core.restricted ? "restricted" : core.needsInfo ? "onboarding" : "pending";
  return {
    details_submitted: core.details,
    charges_enabled: charges,
    payouts_enabled: payoutsEnabled,
    promptpay_enabled: promptpay.enabled,
    promptpay_status: promptpay.status,
    requirements_due_count: core.dueCount,
    bank_ready: bank.ready,
    bank_name: bank.name,
    bank_last4: bank.last4,
    payout_interval: settings,
    balance_pending_satang: money.pending,
    balance_available_satang: money.available,
    last_error_code: null,
    status,
  };
}
function sanitized(state: Record<string,unknown>) {
  return {
    connected: true,
    status: state.status,
    details_submitted: state.details_submitted,
    charges_enabled: state.charges_enabled,
    payouts_enabled: state.payouts_enabled,
    promptpay_enabled: state.promptpay_enabled,
    promptpay_status: state.promptpay_status,
    requirements_due_count: state.requirements_due_count,
    bank_ready: state.bank_ready,
    bank_name: state.bank_name,
    bank_last4: state.bank_last4,
    payout_interval: state.payout_interval,
    balance_pending_satang: state.balance_pending_satang,
    balance_available_satang: state.balance_available_satang,
  };
}
async function syncAccount(admin: AdminClient, secret: string, storeId: string, accountId: string) {
  const retrieved = await retrieveAccount(secret, accountId);
  const [bank, money, payout, promptpay] = await Promise.all([
    fetchBankSummary(secret, accountId),
    fetchMoneySummary(secret, accountId),
    fetchPayoutSummary(secret, accountId),
    fetchPromptPaySummary(secret, accountId),
  ]);
  const core = retrieved.api === "v2" ? v2CoreState(retrieved.account) : v1CoreState(retrieved.account);
  const state = composeState(core, bank, money, payout, promptpay);
  const now = new Date().toISOString();
  const { error } = await admin.from("food_stripe_accounts").upsert({
    store_id: storeId,
    stripe_account_id: accountId,
    account_type: "standard",
    account_api_version: retrieved.api,
    country: "TH",
    ...state,
    last_synced_at: now,
    updated_at: now,
  }, { onConflict: "store_id" });
  if (error) throw new Error("stripe_state_save_failed");
  await admin.from("food_stores").update({ stripe_payments_enabled: state.status === "ready" }).eq("id", storeId);
  return { api: retrieved.api, state };
}
async function createV2Account(secret: string, storeId: string, storeName: string | null, email: string | null) {
  const body: Record<string,unknown> = {
    identity: { country: "th" },
    configuration: {
      merchant: {
        capabilities: {
          card_payments: { requested: true },
        },
      },
    },
    defaults: {
      currency: "thb",
      responsibilities: {
        fees_collector: "stripe",
        losses_collector: "stripe",
      },
    },
    dashboard: "none",
    metadata: { wynos_store_id: storeId },
    include: ["configuration.merchant", "identity", "defaults", "requirements"],
  };
  if (email) body.contact_email = email;
  if (storeName?.trim()) body.display_name = storeName.trim().slice(0, 100);
  return await stripeJson("https://api.stripe.com/v2/core/accounts", {
    method: "POST",
    headers: stripeV2Headers(secret, `wynos-connect-v2-${storeId}`),
    body: JSON.stringify(body),
  });
}
async function createAccountSession(secret: string, accountId: string, component: "account_onboarding" | "account_management") {
  const params = new URLSearchParams();
  params.set("account", accountId);
  if (component === "account_management") {
    params.set("components[account_management][enabled]", "true");
    params.set("components[account_management][features][external_account_collection]", "true");
  } else {
    params.set("components[account_onboarding][enabled]", "true");
    params.set("components[account_onboarding][features][external_account_collection]", "true");
  }
  // Keep ongoing KYC/risk requests visible inside WYNOS even after first onboarding.
  params.set("components[notification_banner][enabled]", "true");
  return await stripeJson("https://api.stripe.com/v1/account_sessions", {
    method: "POST",
    headers: stripeV1Headers(secret),
    body: params,
  });
}
async function createOnboardingLink(secret: string, accountId: string, storeId: string, api: "v1" | "v2") {
  const refreshUrl = `https://merchant.wynos.online/?payments=refresh&store=${encodeURIComponent(storeId)}`;
  const returnUrl = `https://merchant.wynos.online/?payments=return&store=${encodeURIComponent(storeId)}`;
  if (api === "v1") {
    const params = new URLSearchParams();
    params.set("account", accountId);
    params.set("refresh_url", refreshUrl);
    params.set("return_url", returnUrl);
    params.set("type", "account_onboarding");
    return await stripeJson("https://api.stripe.com/v1/account_links", {
      method: "POST", headers: stripeV1Headers(secret), body: params,
    });
  }
  return await stripeJson("https://api.stripe.com/v2/core/account_links", {
    method: "POST",
    headers: stripeV2Headers(secret),
    body: JSON.stringify({
      account: accountId,
      use_case: {
        type: "account_onboarding",
        account_onboarding: {
          configurations: ["merchant"],
          collection_options: { fields: "currently_due" },
          refresh_url: refreshUrl,
          return_url: returnUrl,
        },
      },
    }),
  });
}
async function acquireProvisioningLock(admin: AdminClient, storeId: string, token: string) {
  const { data, error } = await admin.rpc("food_claim_stripe_account_creation", {
    p_store_id: storeId,
    p_operation_token: token,
    p_ttl_seconds: 45,
  });
  if (error) throw new Error("stripe_lock_unavailable");
  return data === true;
}
async function releaseProvisioningLock(admin: AdminClient, storeId: string, token: string) {
  const { error } = await admin.rpc("food_release_stripe_account_creation", {
    p_store_id: storeId,
    p_operation_token: token,
  });
  if (error) console.warn("merchant-stripe-connect lock release failed", { storeId });
}
async function waitForSavedAccount(admin: AdminClient, storeId: string) {
  for (let attempt = 0; attempt < 6; attempt += 1) {
    const { data } = await admin.from("food_stripe_accounts").select("stripe_account_id").eq("store_id", storeId).maybeSingle();
    if (typeof data?.stripe_account_id === "string") return data.stripe_account_id;
    await new Promise((resolve) => setTimeout(resolve, 180));
  }
  return null;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  const publishableKey = Deno.env.get("STRIPE_PUBLISHABLE_KEY")?.trim() ?? null;
  const authHeader = req.headers.get("Authorization");
  if (!url || !key || !authHeader) return json({ error: "unauthorized", message: "กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง" }, 401);
  if (!stripeSecret) return json({ error: "stripe_not_configured", message: "ระบบรับชำระเงินยังไม่พร้อมใช้งาน" }, 503);

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized", message: "กรุณาเข้าสู่ระบบใหม่แล้วลองอีกครั้ง" }, 401);

  let storeId = "", action = "status", component = "account_onboarding";
  try {
    const body = await req.json() as { storeId?: unknown; action?: unknown; component?: unknown };
    storeId = typeof body.storeId === "string" ? body.storeId : "";
    action = typeof body.action === "string" ? body.action : "status";
    component = body.component === "account_management" ? "account_management" : "account_onboarding";
  } catch {
    return json({ error: "invalid_body", message: "คำขอไม่ถูกต้อง กรุณาลองใหม่" }, 400);
  }
  if (!storeId || !["status","onboard","session"].includes(action)) {
    return json({ error: "invalid_request", message: "คำขอไม่ถูกต้อง กรุณาลองใหม่" }, 400);
  }

  const { data: store } = await admin.from("food_stores").select("id,merchant_account_id,name").eq("id", storeId).maybeSingle();
  if (!store?.merchant_account_id) return json({ error: "store_not_found", message: "ไม่พบร้านที่เลือก" }, 404);
  const { data: member } = await admin.from("merchant_memberships")
    .select("role").eq("merchant_account_id", store.merchant_account_id).eq("user_id", user.id).eq("active", true).maybeSingle();
  if (!member || !["owner","admin","manager","orders"].includes(member.role)) {
    return json({ error: "merchant_access_required", message: "ไม่มีสิทธิ์เข้าถึงข้อมูลการรับเงินของร้านนี้" }, 403);
  }
  if (action !== "status" && !["owner","admin"].includes(member.role)) {
    return json({ error: "owner_or_admin_required", message: "เฉพาะเจ้าของร้านหรือแอดมินเท่านั้นที่จัดการการรับเงินได้" }, 403);
  }

  let accountId: string | null = null;
  const { data: saved, error: savedError } = await admin.from("food_stripe_accounts")
    .select("stripe_account_id").eq("store_id", storeId).maybeSingle();
  if (savedError) return json({ error: "stripe_backend_not_ready", message: "ระบบรับชำระเงินยังไม่พร้อมใช้งาน" }, 503);
  if (typeof saved?.stripe_account_id === "string") accountId = saved.stripe_account_id;

  try {
    if (!accountId && action === "onboard") {
      const lockToken = crypto.randomUUID();
      const acquired = await acquireProvisioningLock(admin, storeId, lockToken);
      if (!acquired) {
        accountId = await waitForSavedAccount(admin, storeId);
        if (!accountId) return json({ error: "setup_in_progress", message: "กำลังตั้งค่าการรับชำระเงิน กรุณารอสักครู่แล้วลองอีกครั้ง" }, 409);
      } else {
        try {
          const recheck = await admin.from("food_stripe_accounts").select("stripe_account_id").eq("store_id", storeId).maybeSingle();
          if (typeof recheck.data?.stripe_account_id === "string") {
            accountId = recheck.data.stripe_account_id;
          } else {
            const account = await createV2Account(
              stripeSecret,
              storeId,
              typeof store.name === "string" ? store.name : null,
              user.email ?? null,
            );
            if (typeof account.id !== "string") throw new Error("stripe_account_create_failed");
            accountId = account.id;
            const core = v2CoreState(account);
            const state = composeState(
              core,
              { ready: false, name: null, last4: null },
              { pending: 0, available: 0 },
              { interval: null },
              { enabled: false, status: "unknown" },
            );
            const { error: insertError } = await admin.from("food_stripe_accounts").insert({
              store_id: storeId,
              stripe_account_id: accountId,
              account_type: "standard",
              account_api_version: "v2",
              country: "TH",
              ...state,
              last_synced_at: new Date().toISOString(),
              updated_at: new Date().toISOString(),
            });
            if (insertError) {
              const existing = await admin.from("food_stripe_accounts").select("stripe_account_id").eq("store_id", storeId).maybeSingle();
              if (typeof existing.data?.stripe_account_id === "string") accountId = existing.data.stripe_account_id;
              else throw new Error("stripe_state_save_failed");
            }
            await preferDailyPayouts(stripeSecret, accountId);
          }
        } finally {
          await releaseProvisioningLock(admin, storeId, lockToken);
        }
      }
    }

    if (!accountId) return json({ connected: false, status: "not_connected" });

    let synced = await syncAccount(admin, stripeSecret, storeId, accountId);
    if (action === "onboard" && synced.api === "v2") {
      await Promise.all([
        preferPromptPay(stripeSecret, accountId),
        preferDailyPayouts(stripeSecret, accountId),
      ]);
      synced = await syncAccount(admin, stripeSecret, storeId, accountId);
    }
    const publicState = sanitized(synced.state);

    if (action === "status") return json(publicState);

    if (action === "session") {
      if (!publishableKey) return json({ error: "embedded_unavailable", message: "ไม่สามารถเปิดหน้าตั้งค่ารับเงินได้ในขณะนี้ กรุณาลองใหม่อีกครั้ง" }, 503);
      const session = await createAccountSession(stripeSecret, accountId, component as "account_onboarding" | "account_management");
      if (typeof session.client_secret !== "string") throw new Error("account_session_missing_secret");
      return json({ surface: "embedded", clientSecret: session.client_secret, publishableKey });
    }

    if (synced.state.status === "ready") {
      return json({ ...publicState, flow: synced.api === "v2" && publishableKey ? "embedded" : "ready", surface: synced.api === "v2" && publishableKey ? "embedded" : "none", publishableKey: synced.api === "v2" ? publishableKey : null });
    }

    if (synced.api === "v2" && publishableKey) {
      return json({ ...publicState, flow: "embedded", surface: "embedded", publishableKey });
    }

    const link = await createOnboardingLink(stripeSecret, accountId, storeId, synced.api);
    if (typeof link.url !== "string") throw new Error("stripe_onboarding_link_unavailable");
    return json({ ...publicState, flow: "redirect", surface: "redirect", url: link.url });
  } catch (error) {
    console.error("merchant-stripe-connect failed", { storeId, action, ...safeStripeError(error) });
    return json({ error: "stripe_connect_failed", message: thaiConnectMessage(error) }, 502);
  }
});
