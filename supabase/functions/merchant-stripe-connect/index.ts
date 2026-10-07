import { createClient } from "npm:@supabase/supabase-js@2.112.3";

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
function stripeV1Headers(secret: string, idempotencyKey?: string) {
  const headers: Record<string,string> = {
    Authorization: `Basic ${btoa(secret + ":")}`,
    "Content-Type": "application/x-www-form-urlencoded",
  };
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
function v1AccountState(account: Record<string,unknown>) {
  const capabilities = (account.capabilities ?? {}) as Record<string,unknown>;
  const requirements = (account.requirements ?? {}) as Record<string,unknown>;
  const details = account.details_submitted === true;
  const charges = account.charges_enabled === true;
  const payouts = account.payouts_enabled === true;
  const promptpay = capabilities.promptpay_payments === "active";
  const disabled = typeof requirements.disabled_reason === "string" && requirements.disabled_reason.length > 0;
  return {
    details_submitted: details,
    charges_enabled: charges,
    payouts_enabled: payouts,
    promptpay_enabled: promptpay,
    status: details && charges ? "ready" : disabled ? "restricted" : details ? "pending" : "onboarding",
  };
}
function capabilityStatus(capabilities: Record<string,unknown>, key: string) {
  const value = capabilities[key] as Record<string,unknown> | undefined;
  return typeof value?.status === "string" ? value.status : null;
}
function v2AccountState(account: Record<string,unknown>) {
  const configuration = (account.configuration ?? {}) as Record<string,unknown>;
  const merchant = (configuration.merchant ?? {}) as Record<string,unknown>;
  const capabilities = (merchant.capabilities ?? {}) as Record<string,unknown>;
  const card = capabilities.card_payments as Record<string,unknown> | undefined;
  const cardStatus = capabilityStatus(capabilities, "card_payments");
  const promptpayStatus = capabilityStatus(capabilities, "promptpay_payments");
  const stripeBalance = capabilities.stripe_balance as Record<string,unknown> | undefined;
  const payouts = stripeBalance?.payouts as Record<string,unknown> | undefined;
  const payoutsStatus = typeof payouts?.status === "string" ? payouts.status : null;

  const requirements = (account.requirements ?? {}) as Record<string,unknown>;
  const entries = Array.isArray(requirements.entries) ? requirements.entries as Array<Record<string,unknown>> : [];
  const dueFromUser = entries.some((entry) => {
    if (entry.awaiting_action_from !== "user") return false;
    const deadline = entry.minimum_deadline as Record<string,unknown> | undefined;
    return deadline?.status === "currently_due" || deadline?.status === "past_due";
  });
  const cardDetails = Array.isArray(card?.status_details) ? card.status_details as Array<Record<string,unknown>> : [];
  const needsInfo = dueFromUser || cardDetails.some((detail) => detail.resolution === "provide_info");
  const hardRestriction = cardStatus === "unsupported" || cardDetails.some((detail) => detail.resolution === "contact_stripe");

  const charges = cardStatus === "active";
  const details = charges || (cardStatus === "pending" && !needsInfo);
  const status = charges && details
    ? "ready"
    : hardRestriction
      ? "restricted"
      : needsInfo
        ? "onboarding"
        : cardStatus === "pending"
          ? "pending"
          : "onboarding";

  return {
    details_submitted: details,
    charges_enabled: charges,
    payouts_enabled: payoutsStatus === "active",
    promptpay_enabled: promptpayStatus === "active",
    status,
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
    return { account, api: "v2" as const, state: v2AccountState(account) };
  } catch (error) {
    if (!(error instanceof StripeApiError) || error.code !== "v1_account_instead_of_v2_account") throw error;
    const account = await stripeJson(`https://api.stripe.com/v1/accounts/${encodeURIComponent(accountId)}`, {
      headers: stripeV1Headers(secret),
    });
    return { account, api: "v1" as const, state: v1AccountState(account) };
  }
}
async function createV2Account(secret: string, storeId: string, storeName: string | null, email: string | null) {
  const body: Record<string,unknown> = {
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
    dashboard: "full",
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
async function createOnboardingLink(secret: string, accountId: string, storeId: string, api: "v1" | "v2") {
  const refreshUrl = `https://merchant.wynos.online/?stripe=refresh&store=${encodeURIComponent(storeId)}`;
  const returnUrl = `https://merchant.wynos.online/?stripe=return&store=${encodeURIComponent(storeId)}`;

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
          collection_options: { fields: "eventually_due" },
          refresh_url: refreshUrl,
          return_url: returnUrl,
        },
      },
    }),
  });
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

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let storeId = "", action = "status";
  try {
    const body = await req.json() as { storeId?: unknown; action?: unknown };
    storeId = typeof body.storeId === "string" ? body.storeId : "";
    action = typeof body.action === "string" ? body.action : "status";
  } catch { return json({ error: "invalid_body" }, 400); }
  if (!storeId || !["status","onboard"].includes(action)) return json({ error: "invalid_request" }, 400);

  const { data: store } = await admin.from("food_stores").select("id,merchant_account_id,name").eq("id", storeId).maybeSingle();
  if (!store?.merchant_account_id) return json({ error: "store_not_found" }, 404);
  const { data: member } = await admin.from("merchant_memberships")
    .select("role").eq("merchant_account_id", store.merchant_account_id).eq("user_id", user.id).eq("active", true).maybeSingle();
  if (!member || !["owner","admin"].includes(member.role)) return json({ error: "owner_or_admin_required" }, 403);

  const { data: saved, error: savedError } = await admin.from("food_stripe_accounts").select("*").eq("store_id", storeId).maybeSingle();
  if (savedError) return json({ error: "stripe_backend_not_ready" }, 503);
  let accountId = saved?.stripe_account_id as string | undefined;

  try {
    if (!accountId && action === "onboard") {
      const account = await createV2Account(
        stripeSecret,
        storeId,
        typeof store.name === "string" ? store.name : null,
        user.email ?? null,
      );
      if (typeof account.id !== "string") throw new Error("Stripe account was not created");
      accountId = account.id;
      const state = v2AccountState(account);
      const { error: upsertError } = await admin.from("food_stripe_accounts").upsert({
        store_id: storeId, stripe_account_id: accountId, account_type: "standard", country: "TH",
        ...state, last_synced_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      }, { onConflict: "store_id" });
      if (upsertError) throw new Error("WYNOS could not save the Stripe account");
    }

    if (!accountId) return json({ connected: false, status: "not_connected" });

    const retrieved = await retrieveAccount(stripeSecret, accountId);
    const state = retrieved.state;
    await admin.from("food_stripe_accounts").upsert({
      store_id: storeId, stripe_account_id: accountId, account_type: "standard", country: "TH",
      ...state, last_synced_at: new Date().toISOString(), updated_at: new Date().toISOString(),
    }, { onConflict: "store_id" });
    await admin.from("food_stores").update({ stripe_payments_enabled: state.status === "ready" }).eq("id", storeId);

    if (action === "status" || state.status === "ready") {
      return json({ connected: true, ...state });
    }

    const link = await createOnboardingLink(stripeSecret, accountId, storeId, retrieved.api);
    if (typeof link.url !== "string") throw new Error("Stripe onboarding link unavailable");
    return json({ connected: true, ...state, url: link.url });
  } catch (error) {
    if (error instanceof StripeApiError && error.code === "accounts_v2_access_blocked") {
      return json({
        error: "stripe_accounts_v2_not_enabled",
        message: "บัญชี Stripe นี้ยังไม่ได้เปิด Accounts v2 กรุณาเปิด Accounts v2 ใน Stripe Dashboard แล้วลองเชื่อมอีกครั้ง",
      }, 502);
    }
    return json({
      error: "stripe_connect_failed",
      message: error instanceof Error ? error.message : "Stripe request failed",
    }, 502);
  }
});
