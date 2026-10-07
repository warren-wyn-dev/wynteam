import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};
const STRIPE_V2_VERSION = "2026-07-29.dahlia";

type AccountApi = "v1" | "v2";
type MerchantAction = "status" | "onboard" | "manage" | "finance";

type MerchantState = {
  details_submitted: boolean;
  charges_enabled: boolean;
  payouts_enabled: boolean;
  promptpay_enabled: boolean;
  promptpay_status: "active" | "pending" | "inactive" | "unsupported" | "unrequested" | "unknown";
  bank_ready: boolean;
  bank_name: string | null;
  bank_last4: string | null;
  payout_interval: "daily" | "weekly" | "monthly" | "manual" | "unknown";
  requirements_due_count: number;
  status: "onboarding" | "pending" | "ready" | "restricted";
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

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

function stripeV1Headers(secret: string, accountId?: string, idempotencyKey?: string) {
  const headers: Record<string, string> = {
    Authorization: `Basic ${btoa(secret + ":")}`,
    "Content-Type": "application/x-www-form-urlencoded",
  };
  if (accountId) headers["Stripe-Account"] = accountId;
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  return headers;
}

function stripeV2Headers(secret: string, idempotencyKey?: string) {
  const headers: Record<string, string> = {
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
  requestId: string | null;
  constructor(message: string, code: string | null, status: number, requestId: string | null) {
    super(message);
    this.name = "StripeApiError";
    this.code = code;
    this.status = status;
    this.requestId = requestId;
  }
}

async function stripeJson(url: string, init: RequestInit) {
  const response = await fetch(url, init);
  const payload = await response.json().catch(() => ({})) as Record<string, unknown>;
  if (!response.ok) {
    const err = payload.error as Record<string, unknown> | undefined;
    throw new StripeApiError(
      typeof err?.message === "string" ? err.message : "Stripe request failed",
      typeof err?.code === "string" ? err.code : null,
      response.status,
      response.headers.get("request-id"),
    );
  }
  return payload;
}

function capabilityStatus(capabilities: Record<string, unknown>, key: string) {
  const value = capabilities[key] as Record<string, unknown> | undefined;
  return typeof value?.status === "string" ? value.status : null;
}

function normalizePromptPay(status: string | null): MerchantState["promptpay_status"] {
  if (status === "active" || status === "pending" || status === "unsupported") return status;
  if (status === "inactive") return "inactive";
  if (status === "unrequested") return "unrequested";
  return "unknown";
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
  const deadlineStatus = typeof deadline?.status === "string" ? deadline.status : "";
  return deadlineStatus === "currently_due" || deadlineStatus === "past_due";
}

function v2CoreState(account: Record<string, unknown>) {
  const configuration = (account.configuration ?? {}) as Record<string, unknown>;
  const merchant = (configuration.merchant ?? {}) as Record<string, unknown>;
  const capabilities = (merchant.capabilities ?? {}) as Record<string, unknown>;
  const card = capabilities.card_payments as Record<string, unknown> | undefined;
  const cardStatus = capabilityStatus(capabilities, "card_payments");
  const promptpayStatus = capabilityStatus(capabilities, "promptpay_payments");
  const stripeBalance = capabilities.stripe_balance as Record<string, unknown> | undefined;
  const payouts = stripeBalance?.payouts as Record<string, unknown> | undefined;
  const payoutsStatus = typeof payouts?.status === "string" ? payouts.status : null;

  const entries = requirementEntries(account);
  const due = entries.filter(requirementNeedsUser);
  const cardDetails = Array.isArray(card?.status_details)
    ? card.status_details as Array<Record<string, unknown>>
    : [];
  const needsInfo = due.length > 0 || cardDetails.some((detail) => detail.resolution === "provide_info");
  const hardRestriction =
    cardStatus === "unsupported" ||
    cardDetails.some((detail) => detail.resolution === "contact_stripe");

  return {
    cardStatus,
    promptpayStatus,
    payoutsStatus,
    needsInfo,
    hardRestriction,
    requirementsDueCount: due.length,
  };
}

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
    const account = await stripeJson(
      `https://api.stripe.com/v1/accounts/${encodeURIComponent(accountId)}`,
      { headers: stripeV1Headers(secret) },
    );
    return { account, api: "v1" as const };
  }
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
    const status = typeof selected.status === "string" ? selected.status : null;
    return {
      ready: Boolean(last4) && status !== "errored" && status !== "verification_failed",
      bankName,
      last4,
    };
  } catch {
    return { ready: false, bankName: null, last4: null };
  }
}

function payoutInterval(payload: Record<string, unknown>): MerchantState["payout_interval"] {
  const payments = payload.payments as Record<string, unknown> | undefined;
  const payouts = payments?.payouts as Record<string, unknown> | undefined;
  const schedule = payouts?.schedule as Record<string, unknown> | undefined;
  const interval = schedule?.interval;
  return interval === "daily" || interval === "weekly" || interval === "monthly" || interval === "manual"
    ? interval
    : "unknown";
}

async function retrieveBalanceSettings(secret: string, accountId: string) {
  try {
    const payload = await stripeJson("https://api.stripe.com/v1/balance_settings", {
      headers: stripeV1Headers(secret, accountId),
    });
    return { payload, interval: payoutInterval(payload) };
  } catch {
    return { payload: {}, interval: "unknown" as const };
  }
}

async function preferDailyPayouts(secret: string, accountId: string) {
  const current = await retrieveBalanceSettings(secret, accountId);
  if (current.interval === "daily") return current.interval;

  try {
    const params = new URLSearchParams();
    params.set("payments[payouts][schedule][interval]", "daily");
    const payload = await stripeJson("https://api.stripe.com/v1/balance_settings", {
      method: "POST",
      headers: stripeV1Headers(secret, accountId, `wynos-payout-daily-${accountId}`),
      body: params,
    });
    return payoutInterval(payload);
  } catch {
    return current.interval;
  }
}

async function buildState(secret: string, accountId: string, api: AccountApi, account: Record<string, unknown>) {
  const [bank, settings] = await Promise.all([
    retrieveBank(secret, accountId),
    api === "v2" ? preferDailyPayouts(secret, accountId) : retrieveBalanceSettings(secret, accountId).then((x) => x.interval),
  ]);

  if (api === "v1") {
    const capabilities = (account.capabilities ?? {}) as Record<string, unknown>;
    const requirements = (account.requirements ?? {}) as Record<string, unknown>;
    const currentDue = Array.isArray(requirements.currently_due) ? requirements.currently_due.length : 0;
    const pastDue = Array.isArray(requirements.past_due) ? requirements.past_due.length : 0;
    const requirementsDueCount = currentDue + pastDue;
    const details = account.details_submitted === true;
    const charges = account.charges_enabled === true;
    const payouts = account.payouts_enabled === true;
    const promptpay = capabilities.promptpay_payments === "active";
    const promptStatus = capabilities.promptpay_payments;
    const disabled = typeof requirements.disabled_reason === "string" && requirements.disabled_reason.length > 0;
    const ready = details && charges && payouts && requirementsDueCount === 0 && bank.ready;

    return {
      details_submitted: details,
      charges_enabled: charges,
      payouts_enabled: payouts,
      promptpay_enabled: promptpay,
      promptpay_status: normalizePromptPay(typeof promptStatus === "string" ? promptStatus : null),
      bank_ready: bank.ready,
      bank_name: bank.bankName,
      bank_last4: bank.last4,
      payout_interval: settings,
      requirements_due_count: requirementsDueCount,
      status: ready ? "ready" : disabled ? "restricted" : requirementsDueCount > 0 ? "onboarding" : "pending",
    } satisfies MerchantState;
  }

  const core = v2CoreState(account);
  const charges = core.cardStatus === "active";
  const payoutsEnabled = core.payoutsStatus === "active";
  const ready = charges && payoutsEnabled && !core.needsInfo && bank.ready;
  const details = !core.needsInfo && (charges || core.cardStatus === "pending" || core.cardStatus === "active");

  return {
    details_submitted: details,
    charges_enabled: charges,
    payouts_enabled: payoutsEnabled,
    promptpay_enabled: core.promptpayStatus === "active",
    promptpay_status: normalizePromptPay(core.promptpayStatus),
    bank_ready: bank.ready,
    bank_name: bank.bankName,
    bank_last4: bank.last4,
    payout_interval: settings,
    requirements_due_count: core.requirementsDueCount,
    status: ready
      ? "ready"
      : core.hardRestriction
        ? "restricted"
        : core.needsInfo
          ? "onboarding"
          : "pending",
  } satisfies MerchantState;
}

async function saveState(
  admin: ReturnType<typeof createClient>,
  storeId: string,
  accountId: string,
  api: AccountApi,
  state: MerchantState,
  lastErrorCode: string | null = null,
) {
  const now = new Date().toISOString();
  const { error } = await admin.from("food_stripe_accounts").upsert({
    store_id: storeId,
    stripe_account_id: accountId,
    account_type: "standard",
    account_api_version: api,
    country: "TH",
    ...state,
    last_error_code: lastErrorCode,
    last_synced_at: now,
    updated_at: now,
  }, { onConflict: "store_id" });
  if (error) throw new Error("stripe_state_save_failed");

  const { error: storeError } = await admin
    .from("food_stores")
    .update({ stripe_payments_enabled: state.status === "ready" })
    .eq("id", storeId);
  if (storeError) throw new Error("stripe_store_state_save_failed");
}

async function syncAccount(
  admin: ReturnType<typeof createClient>,
  secret: string,
  storeId: string,
  accountId: string,
) {
  const retrieved = await retrieveAccount(secret, accountId);
  const state = await buildState(secret, accountId, retrieved.api, retrieved.account);
  await saveState(admin, storeId, accountId, retrieved.api, state);
  return { ...retrieved, state };
}

async function createV2Account(
  secret: string,
  storeId: string,
  storeName: string | null,
  email: string | null,
) {
  const body: Record<string, unknown> = {
    identity: { country: "th" },
    configuration: {
      merchant: {
        capabilities: {
          card_payments: { requested: true },
          promptpay_payments: { requested: true },
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

async function createAccountLink(secret: string, accountId: string, storeId: string, api: AccountApi) {
  const refreshUrl = `https://merchant.wynos.online/?payments=refresh&store=${encodeURIComponent(storeId)}`;
  const returnUrl = `https://merchant.wynos.online/?payments=return&store=${encodeURIComponent(storeId)}`;

  if (api === "v1") {
    const params = new URLSearchParams();
    params.set("account", accountId);
    params.set("refresh_url", refreshUrl);
    params.set("return_url", returnUrl);
    params.set("type", "account_onboarding");
    return await stripeJson("https://api.stripe.com/v1/account_links", {
      method: "POST",
      headers: stripeV1Headers(secret),
      body: params,
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
          collection_options: { fields: "eventually_due" },
          refresh_url: refreshUrl,
          return_url: returnUrl,
        },
      },
    }),
  });
}

async function createAccountSession(secret: string, accountId: string, mode: "onboard" | "manage") {
  const params = new URLSearchParams();
  params.set("account", accountId);
  if (mode === "onboard") {
    params.set("components[account_onboarding][enabled]", "true");
    params.set("components[account_onboarding][features][external_account_collection]", "true");
  } else {
    params.set("components[account_management][enabled]", "true");
    params.set("components[account_management][features][external_account_collection]", "true");
    params.set("components[notification_banner][enabled]", "true");
    params.set("components[notification_banner][features][external_account_collection]", "true");
  }
  return await stripeJson("https://api.stripe.com/v1/account_sessions", {
    method: "POST",
    headers: stripeV1Headers(secret),
    body: params,
  });
}

async function embeddedOrHosted(
  secret: string,
  publishableKey: string | null,
  accountId: string,
  storeId: string,
  api: AccountApi,
  mode: "onboard" | "manage",
) {
  if (publishableKey) {
    try {
      const session = await createAccountSession(secret, accountId, mode);
      if (typeof session.client_secret === "string") {
        return {
          surface: "embedded" as const,
          client_secret: session.client_secret,
          publishable_key: publishableKey,
        };
      }
    } catch (error) {
      if (error instanceof StripeApiError) {
        console.error("merchant-stripe-connect embedded unavailable", {
          code: error.code,
          status: error.status,
          request_id: error.requestId,
        });
      }
    }
  }

  if (mode === "manage") {
    return {
      surface: "unavailable" as const,
      message: "ยังไม่สามารถเปิดหน้าจัดการข้อมูลรับเงินได้ กรุณาลองใหม่อีกครั้ง",
    };
  }

  const link = await createAccountLink(secret, accountId, storeId, api);
  if (typeof link.url !== "string") throw new Error("onboarding_link_unavailable");
  return { surface: "redirect" as const, url: link.url };
}

function sumThb(items: unknown) {
  if (!Array.isArray(items)) return 0;
  return items.reduce((sum, row) => {
    const item = row as Record<string, unknown>;
    return item.currency === "thb" && typeof item.amount === "number" ? sum + item.amount : sum;
  }, 0);
}

function bangkokStartUnix() {
  const day = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  return Math.floor(Date.parse(`${day}T00:00:00+07:00`) / 1000);
}

async function financeSnapshot(secret: string, accountId: string) {
  const [balance, payouts] = await Promise.all([
    stripeJson("https://api.stripe.com/v1/balance", {
      headers: stripeV1Headers(secret, accountId),
    }),
    stripeJson(
      `https://api.stripe.com/v1/payouts?limit=100&created%5Bgte%5D=${bangkokStartUnix()}`,
      { headers: stripeV1Headers(secret, accountId) },
    ),
  ]);

  const payoutRows = Array.isArray(payouts.data) ? payouts.data as Array<Record<string, unknown>> : [];
  const paidTodaySatang = payoutRows.reduce((sum, payout) => {
    return payout.status === "paid" && payout.currency === "thb" && typeof payout.amount === "number"
      ? sum + payout.amount
      : sum;
  }, 0);

  return {
    pending: sumThb(balance.pending) / 100,
    available: sumThb(balance.available) / 100,
    paid_today: paidTodaySatang / 100,
  };
}

function safeErrorResponse(error: unknown) {
  if (error instanceof StripeApiError) {
    console.error("merchant-stripe-connect stripe failure", {
      code: error.code,
      status: error.status,
      request_id: error.requestId,
    });
    if (error.code === "accounts_v2_access_blocked") {
      return json({
        error: "payments_setup_unavailable",
        message: "ระบบเปิดรับชำระเงินรุ่นใหม่ยังไม่พร้อมสำหรับบัญชีนี้ กรุณาติดต่อ WYNOS",
      }, 502);
    }
    if (error.code === "account_country_invalid_address" || error.code === "country_unsupported") {
      return json({
        error: "payments_country_unavailable",
        message: "ยังไม่สามารถเปิดรับชำระเงินสำหรับข้อมูลร้านนี้ได้ กรุณาตรวจสอบข้อมูลร้านแล้วลองอีกครั้ง",
      }, 502);
    }
    return json({
      error: "payments_setup_failed",
      message: "ตั้งค่าการรับชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง",
    }, 502);
  }

  console.error("merchant-stripe-connect internal failure", {
    code: error instanceof Error ? error.message.slice(0, 120) : "unknown",
  });
  return json({
    error: "payments_setup_failed",
    message: "ตั้งค่าการรับชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง",
  }, 502);
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY")?.trim();
  const publishableKey = Deno.env.get("STRIPE_PUBLISHABLE_KEY")?.trim() || null;
  const authHeader = req.headers.get("Authorization");

  if (!url || !key || !authHeader) return json({ error: "unauthorized" }, 401);
  if (!stripeSecret) return json({ error: "payments_not_configured" }, 503);

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let storeId = "";
  let action: MerchantAction = "status";
  try {
    const body = await req.json() as { storeId?: unknown; action?: unknown };
    storeId = typeof body.storeId === "string" ? body.storeId : "";
    action = typeof body.action === "string" ? body.action as MerchantAction : "status";
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  if (!storeId || !["status", "onboard", "manage", "finance"].includes(action)) {
    return json({ error: "invalid_request" }, 400);
  }

  const { data: store } = await admin
    .from("food_stores")
    .select("id,merchant_account_id,name")
    .eq("id", storeId)
    .maybeSingle();
  if (!store?.merchant_account_id) return json({ error: "store_not_found" }, 404);

  const { data: member } = await admin
    .from("merchant_memberships")
    .select("role")
    .eq("merchant_account_id", store.merchant_account_id)
    .eq("user_id", user.id)
    .eq("active", true)
    .maybeSingle();

  const role = typeof member?.role === "string" ? member.role : "";
  if (!role) return json({ error: "merchant_access_required" }, 403);
  if (action === "onboard" || action === "manage") {
    if (!["owner", "admin"].includes(role)) return json({ error: "owner_or_admin_required" }, 403);
  } else if (!["owner", "admin", "manager", "orders"].includes(role)) {
    return json({ error: "merchant_access_required" }, 403);
  }

  const { data: saved, error: savedError } = await admin
    .from("food_stripe_accounts")
    .select("*")
    .eq("store_id", storeId)
    .maybeSingle();
  if (savedError) return json({ error: "payments_backend_not_ready" }, 503);

  let accountId = typeof saved?.stripe_account_id === "string" ? saved.stripe_account_id : "";
  let creationToken: string | null = null;

  try {
    if (!accountId && action === "onboard") {
      creationToken = crypto.randomUUID();
      const { data: claimed, error: claimError } = await admin.rpc("food_claim_stripe_account_creation", {
        p_store_id: storeId,
        p_operation_token: creationToken,
        p_ttl_seconds: 90,
      });
      if (claimError) throw new Error("account_creation_lock_failed");

      if (!claimed) {
        const { data: concurrent } = await admin
          .from("food_stripe_accounts")
          .select("stripe_account_id,status")
          .eq("store_id", storeId)
          .maybeSingle();
        if (typeof concurrent?.stripe_account_id === "string" && concurrent.stripe_account_id) {
          accountId = concurrent.stripe_account_id;
        } else {
          return json({
            connected: false,
            status: "pending",
            message: "กำลังตั้งค่าการรับชำระเงิน กรุณารอสักครู่",
          }, 202);
        }
      }

      if (!accountId) {
        const account = await createV2Account(
          stripeSecret,
          storeId,
          typeof store.name === "string" ? store.name : null,
          user.email ?? null,
        );
        if (typeof account.id !== "string") throw new Error("stripe_account_not_created");
        accountId = account.id;
        const state = await buildState(stripeSecret, accountId, "v2", account);
        await saveState(admin, storeId, accountId, "v2", state);
      }
    }

    if (!accountId) {
      return json({
        connected: false,
        status: "not_connected",
        details_submitted: false,
        charges_enabled: false,
        payouts_enabled: false,
        promptpay_enabled: false,
        promptpay_status: "unknown",
        bank_ready: false,
        bank_name: null,
        bank_last4: null,
        payout_interval: "unknown",
        requirements_due_count: 0,
      });
    }

    const synced = await syncAccount(admin, stripeSecret, storeId, accountId);

    if (action === "finance") {
      const snapshot = await financeSnapshot(stripeSecret, accountId);
      return json({ connected: true, ...synced.state, ...snapshot });
    }

    if (action === "status") return json({ connected: true, ...synced.state });

    if (action === "manage") {
      const surface = await embeddedOrHosted(
        stripeSecret,
        publishableKey,
        accountId,
        storeId,
        synced.api,
        "manage",
      );
      return json({ connected: true, ...synced.state, ...surface });
    }

    if (synced.state.status === "ready") {
      return json({ connected: true, ...synced.state, surface: "none" });
    }

    const surface = await embeddedOrHosted(
      stripeSecret,
      publishableKey,
      accountId,
      storeId,
      synced.api,
      "onboard",
    );
    return json({ connected: true, ...synced.state, ...surface });
  } catch (error) {
    return safeErrorResponse(error);
  } finally {
    if (creationToken) {
      await admin.rpc("food_release_stripe_account_creation", {
        p_store_id: storeId,
        p_operation_token: creationToken,
      }).catch(() => undefined);
    }
  }
});
