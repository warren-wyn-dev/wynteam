import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { fetchFcmAccessToken, isDeadTokenError, webPushTopic, type FcmServiceAccount } from "../send-push-notification/_lib.ts";
import { foodPromoTokenQuery, foodPromoPushPayload, foodPromoConsentQuery, isFoodPromoQuietTime } from "./_lib.ts";

type Delivery = {
  delivery_id: string; recipient_id: string; broadcast_id: string;
  push_title: string; push_body: string; coupon_code: string | null;
};

const URL_BASE = Deno.env.get("SUPABASE_URL") ?? "";
// Supabase projects may expose a legacy service-role key or the newer
// JSON secret-key bundle. Use the same backward-compatible fallback as
// the existing Food unpaid-timeout worker; never accept a public key.
function serviceKey(): string {
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (legacy) return legacy;
  const raw = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (!raw) return "";
  try {
    const keys = JSON.parse(raw) as Record<string, string>;
    return keys.default ?? Object.values(keys)[0] ?? "";
  } catch { return ""; }
}
const KEY = serviceKey();
const SERVICE = Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "";
const headers = () => ({ apikey: KEY, Authorization: `Bearer ${KEY}`, "Content-Type": "application/json" });

async function rpc<T>(name: string, payload: Record<string, unknown>): Promise<T> {
  const response = await fetch(`${URL_BASE}/rest/v1/rpc/${name}`, {
    method: "POST", headers: headers(), body: JSON.stringify(payload),
  });
  if (!response.ok) throw new Error(`${name}: HTTP ${response.status}`);
  return await response.json() as T;
}

async function recipientStillOptedIn(recipientId: string): Promise<boolean> {
  const response = await fetch(`${URL_BASE}/rest/v1/${foodPromoConsentQuery(recipientId)}`, { headers: headers() });
  if (!response.ok) throw new Error(`marketing consent lookup HTTP ${response.status}`);
  const rows = await response.json() as Array<{ user_id?: string }>;
  return rows.length > 0 && rows[0]?.user_id === recipientId;
}

async function tokensForFood(recipientId: string): Promise<string[]> {
  const response = await fetch(`${URL_BASE}/rest/v1/${foodPromoTokenQuery(recipientId)}`, { headers: headers() });
  if (!response.ok) throw new Error(`food token lookup HTTP ${response.status}`);
  const rows = await response.json() as Array<{ token?: string }>;
  return [...new Set(rows.map(r => r.token).filter((t): t is string => typeof t === "string" && !!t))];
}

async function discardDeadToken(token: string) {
  const response = await fetch(`${URL_BASE}/rest/v1/push_tokens?token=eq.${encodeURIComponent(token)}`, {
    method: "DELETE", headers: headers(),
  });
  if (!response.ok) console.warn("Food promo could not remove revoked FCM token", response.status);
}

async function sendOne(accessToken: string, service: FcmServiceAccount, claim: Delivery): Promise<boolean> {
  if (!await recipientStillOptedIn(claim.recipient_id)) return false;
  const tokens = await tokensForFood(claim.recipient_id);
  if (!tokens.length) return false;
  const data = foodPromoPushPayload(claim.broadcast_id, claim.delivery_id, claim.push_title, claim.push_body, claim.coupon_code);
  let sent = false;
  for (const token of tokens) {
    const response = await fetch(`https://fcm.googleapis.com/v1/projects/${service.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({ message: {
        token, data, webpush: { headers: { TTL: "21600", Topic: webPushTopic(`foodpromo_${claim.broadcast_id}`) } },
      } }),
    });
    if (response.ok) { sent = true; continue; }
    const err = await response.json().catch(() => null);
    const status = err?.error?.status as string | undefined;
    const message = err?.error?.message as string | undefined;
    if (isDeadTokenError(status, message)) await discardDeadToken(token);
    console.warn("Food promotion Push failed", { status: status ?? "unknown", http: response.status });
  }
  return sent;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return Response.json({ error: "method_not_allowed" }, { status: 405 });
  // Vault-authenticated pg_cron, never exposed as a URL/query value.
  const key = req.headers.get("x-wynos-food-promo-key") ?? "";
  if (!KEY || !URL_BASE || key.length < 32) {
    return Response.json({ error: "unauthorized" }, { status: 401 });
  }
  const authorized = await rpc<boolean>("verify_food_promo_cron_key", { p_key: key }).catch(() => false);
  if (!authorized) return Response.json({ error: "unauthorized" }, { status: 401 });
  const body = await req.json().catch(() => null) as { source?: unknown } | null;
  if (body?.source !== "pg_cron") return Response.json({ error: "forbidden_source" }, { status: 403 });
  if (isFoodPromoQuietTime(new Date())) return Response.json({ claimed: 0, deferred: "quiet_hours" });
  if (!SERVICE) return Response.json({ error: "fcm_not_configured" }, { status: 503 });
  try {
    const service = JSON.parse(SERVICE) as FcmServiceAccount;
    if (!service.project_id || !service.client_email || !service.private_key) {
      return Response.json({ error: "invalid_fcm_config" }, { status: 503 });
    }
    const claims = await rpc<Delivery[]>("food_promo_claim_batch", { p_limit: 50 });
    if (!claims.length) return Response.json({ claimed: 0, sent: 0, failed: 0 });
    const token = await fetchFcmAccessToken(service);
    let sent = 0, failed = 0;
    for (const claim of claims) {
      let success = false;
      let error = "no_food_token_or_delivery_failure";
      try {
        success = await sendOne(token, service, claim);
      } catch (e) { error = e instanceof Error ? e.name : "send_error"; }
      await rpc("food_promo_finish_delivery", {
        p_delivery_id: claim.delivery_id, p_success: success,
        p_error: success ? null : error,
      });
      if (success) sent++; else failed++;
    }
    return Response.json({ claimed: claims.length, sent, failed });
  } catch (err) {
    console.error("Food promo dispatch failed", err instanceof Error ? err.name : "error");
    return Response.json({ error: "dispatch_failed" }, { status: 500 });
  }
});
