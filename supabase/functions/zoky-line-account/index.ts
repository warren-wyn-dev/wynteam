import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { startMerchantLineLink } from "../zoky-line-webhook/link-flow.mjs";

const STORE_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const LINK_TOKEN = /^[A-Za-z0-9_-]{16,255}$/;
const MAX_BODY = 2048;
const ORIGIN = "https://merchant.wynos.online";
function secretKey(): string | null {
  const older = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (older) return older;
  try {
    const keys = JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}") as Record<string, string>;
    return keys.default ?? null;
  } catch { return null; }
}
function json(value: unknown, status: number, origin: string | null) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
      "Vary": "Origin",
      ...(origin === ORIGIN ? { "Access-Control-Allow-Origin": ORIGIN } : {}),
    },
  });
}
Deno.serve(async (req: Request) => {
  const origin = req.headers.get("origin");
  // Prevent other websites from invoking state-changing browser APIs.
  if (origin !== ORIGIN) return json({ error: "origin_not_allowed" }, 403, null);
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: {
        "Access-Control-Allow-Origin": ORIGIN,
        "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Max-Age": "120",
      },
    });
  }
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405, origin);

  const url = Deno.env.get("SUPABASE_URL");
  const service = secretKey();
  const publishable = Deno.env.get("SUPABASE_ANON_KEY")
    ?? (() => {
      try {
        const keys = JSON.parse(Deno.env.get("SUPABASE_PUBLISHABLE_KEYS") ?? "{}") as Record<string, string>;
        return keys.default ?? "";
      } catch { return ""; }
    })();
  if (!url || !service || !publishable) return json({ error: "not_configured" }, 503, origin);

  const bearer = req.headers.get("authorization") ?? "";
  const jwt = bearer.startsWith("Bearer ") ? bearer.slice(7) : "";
  if (!jwt || jwt.length > 5000) return json({ error: "not_authenticated" }, 401, origin);
  const sessionClient = createClient(url, publishable, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: "Bearer " + jwt } },
  });
  const auth = await sessionClient.auth.getUser(jwt);
  const user = auth.data.user;
  if (auth.error || !user || user.is_anonymous) return json({ error: "not_authenticated" }, 401, origin);
  const admin = createClient(url, service, { auth: { persistSession: false, autoRefreshToken: false } });

  let body: Record<string, unknown>;
  try {
    const bytes = new Uint8Array(await req.arrayBuffer());
    if (bytes.length > MAX_BODY) return json({ error: "payload_too_large" }, 413, origin);
    const decoded = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
    if (!decoded || typeof decoded !== "object" || Array.isArray(decoded)) throw new Error("json");
    body = decoded as Record<string, unknown>;
  } catch { return json({ error: "invalid_payload" }, 400, origin); }
  const action = body.action;
  const storeId = body.storeId;
  if (typeof storeId !== "string" || !STORE_ID.test(storeId)) return json({ error: "invalid_store" }, 400, origin);
  if (!["status", "begin", "unlink"].includes(String(action))) return json({ error: "invalid_action" }, 400, origin);

  const activeMember = async () => {
    // Fail closed for unapproved stores: Zoky shares Supabase with WYNOS.
    const optIn = await admin.from("zoky_line_enabled_stores").select("store_id").eq("store_id", storeId).maybeSingle();
    if (optIn.error || !optIn.data) return false;
    const store = await admin.from("food_stores").select("merchant_account_id").eq("id", storeId).maybeSingle();
    if (store.error || !store.data) return false;
    const [member, staff] = await Promise.all([
      store.data.merchant_account_id
        ? admin.from("merchant_memberships").select("role").eq("merchant_account_id", store.data.merchant_account_id)
          .eq("user_id", user.id).eq("active", true).in("role", ["owner","admin","manager","orders"]).limit(1)
        : Promise.resolve({ data: [], error: null }),
      admin.from("food_staff").select("role").eq("store_id", storeId).eq("user_id", user.id)
        .eq("active", true).in("role", ["owner","staff"]).limit(1),
    ]);
    return !member.error && !staff.error && Boolean((member.data?.length ?? 0) + (staff.data?.length ?? 0));
  };
  if (action === "unlink") {
    // The owner of their own link can revoke even after being removed as staff.
    const result = await admin.from("zoky_line_connections")
      .update({ revoked_at: new Date().toISOString() })
      .eq("store_id", storeId).eq("user_id", user.id).is("revoked_at", null);
    return result.error ? json({ error: "unlink_failed" }, 503, origin) : json({ ok: true }, 200, origin);
  }
  if (!await activeMember()) return json({ error: "merchant_access_required" }, 403, origin);
  if (action === "status") {
    const result = await admin.from("zoky_line_connections").select("linked_at").eq("store_id",storeId)
      .eq("user_id", user.id).is("revoked_at", null).maybeSingle();
    return result.error ? json({ error: "status_failed" }, 503, origin)
      : json({ connected: Boolean(result.data), linkedAt: result.data?.linked_at ?? null }, 200, origin);
  }
  if (typeof body.linkToken !== "string" || !LINK_TOKEN.test(body.linkToken)) {
    return json({ error: "invalid_link_token" }, 400, origin);
  }
  try {
    const result = await startMerchantLineLink({
      userId: user.id,
      storeId,
      linkToken: body.linkToken,
      repository: {
        async requireActiveMember() {
          if (!await activeMember()) throw new Error("membership_revoked");
        },
        async savePendingLink(pending: { nonceHash: string; userId: string; storeId: string; expiresAt: string }) {
          const res = await admin.from("zoky_line_link_requests").insert({
            nonce_sha256: pending.nonceHash,
            user_id: pending.userId,
            store_id: pending.storeId,
            expires_at: pending.expiresAt,
          });
          if (res.error) throw new Error("save_link_failed");
        },
      },
    });
    return json({ redirectUrl: result.redirectUrl }, 200, origin);
  } catch { return json({ error: "link_failed" }, 503, origin); }
});
