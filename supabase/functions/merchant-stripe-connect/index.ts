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
function stripeHeaders(secret: string, idempotencyKey?: string) {
  const headers: Record<string,string> = {
    Authorization: `Basic ${btoa(secret + ":")}`,
    "Content-Type": "application/x-www-form-urlencoded",
  };
  if (idempotencyKey) headers["Idempotency-Key"] = idempotencyKey;
  return headers;
}
async function stripeJson(url: string, init: RequestInit) {
  const response = await fetch(url, init);
  const payload = await response.json().catch(() => ({})) as Record<string,unknown>;
  if (!response.ok) {
    const err = payload.error as Record<string,unknown> | undefined;
    throw new Error(typeof err?.message === "string" ? err.message : "Stripe request failed");
  }
  return payload;
}
function accountState(account: Record<string,unknown>) {
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

  const { data: store } = await admin.from("food_stores").select("id,merchant_account_id").eq("id", storeId).maybeSingle();
  if (!store?.merchant_account_id) return json({ error: "store_not_found" }, 404);
  const { data: member } = await admin.from("merchant_memberships")
    .select("role").eq("merchant_account_id", store.merchant_account_id).eq("user_id", user.id).eq("active", true).maybeSingle();
  if (!member || !["owner","admin"].includes(member.role)) return json({ error: "owner_or_admin_required" }, 403);

  const { data: saved, error: savedError } = await admin.from("food_stripe_accounts").select("*").eq("store_id", storeId).maybeSingle();
  if (savedError) return json({ error: "stripe_backend_not_ready" }, 503);
  let accountId = saved?.stripe_account_id as string | undefined;

  try {
    if (!accountId && action === "onboard") {
      const params = new URLSearchParams();
      params.set("type", "standard");
      params.set("country", "TH");
      if (user.email) params.set("email", user.email);
      params.set("capabilities[card_payments][requested]", "true");
      params.set("capabilities[promptpay_payments][requested]", "true");
      params.set("metadata[wynos_store_id]", storeId);
      const account = await stripeJson("https://api.stripe.com/v1/accounts", {
        method: "POST", headers: stripeHeaders(stripeSecret, `wynos-connect-${storeId}`), body: params,
      });
      if (typeof account.id !== "string") throw new Error("Stripe account was not created");
      accountId = account.id;
      const state = accountState(account);
      await admin.from("food_stripe_accounts").upsert({
        store_id: storeId, stripe_account_id: accountId, account_type: "standard", country: "TH",
        ...state, last_synced_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      }, { onConflict: "store_id" });
    }

    if (!accountId) return json({ connected: false, status: "not_connected" });

    const account = await stripeJson(`https://api.stripe.com/v1/accounts/${encodeURIComponent(accountId)}`, {
      headers: stripeHeaders(stripeSecret),
    });
    const state = accountState(account);
    await admin.from("food_stripe_accounts").upsert({
      store_id: storeId, stripe_account_id: accountId, account_type: "standard", country: "TH",
      ...state, last_synced_at: new Date().toISOString(), updated_at: new Date().toISOString(),
    }, { onConflict: "store_id" });
    await admin.from("food_stores").update({ stripe_payments_enabled: state.status === "ready" }).eq("id", storeId);

    if (action === "status" || state.status === "ready") {
      return json({ connected: true, ...state });
    }

    const linkParams = new URLSearchParams();
    linkParams.set("account", accountId);
    linkParams.set("refresh_url", `https://merchant.wynos.online/?stripe=refresh&store=${encodeURIComponent(storeId)}`);
    linkParams.set("return_url", `https://merchant.wynos.online/?stripe=return&store=${encodeURIComponent(storeId)}`);
    linkParams.set("type", "account_onboarding");
    const link = await stripeJson("https://api.stripe.com/v1/account_links", {
      method: "POST", headers: stripeHeaders(stripeSecret), body: linkParams,
    });
    if (typeof link.url !== "string") throw new Error("Stripe onboarding link unavailable");
    return json({ connected: true, ...state, url: link.url });
  } catch (error) {
    return json({ error: "stripe_connect_failed", message: error instanceof Error ? error.message : "Stripe request failed" }, 502);
  }
});
