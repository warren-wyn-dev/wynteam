import { menuImageHandler, type UploadPermission } from "./_lib.ts";
import { normalizeMenuImage } from "./_image.ts";

function runtimeKey(single: string, multiple: string): string | null {
  const legacy = Deno.env.get(single);
  if (legacy) return legacy;
  try {
    const values: unknown = JSON.parse(Deno.env.get(multiple) ?? "{}");
    if (!values || typeof values !== "object" || Array.isArray(values)) return null;
    const keys = values as Record<string, unknown>;
    const value = keys.default ?? Object.values(keys)[0];
    return typeof value === "string" && value ? value : null;
  } catch {
    return null;
  }
}

// The existing Supabase Edge runtime owns the privileged Storage client. No
// privileged credential is added to the Admin app or used for permission RPCs.
const url = Deno.env.get("SUPABASE_URL")?.replace(/\/+$/, "");
const service = runtimeKey("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEYS");
const publishable = runtimeKey("SUPABASE_ANON_KEY", "SUPABASE_PUBLISHABLE_KEYS");
const boundedFetch: typeof fetch = (input, init) => fetch(input, {
  ...init,
  signal: init?.signal ? AbortSignal.any([init.signal, AbortSignal.timeout(15_000)]) : AbortSignal.timeout(15_000),
});

const handler = menuImageHandler({
  async authenticate(authorization) {
    if (!url || !publishable || !service) throw new Error("runtime_unavailable");
    const response = await boundedFetch(`${url}/auth/v1/user`, {
      headers: { apikey: publishable, Authorization: authorization },
    });
    if (response.status === 401 || response.status === 403) {
      await response.body?.cancel();
      return false;
    }
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error("auth_unavailable");
    }
    const user: unknown = await response.json();
    if (!user || typeof user !== "object" || !("id" in user)
      || typeof user.id !== "string" || !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(user.id)) {
      throw new Error("auth_unavailable");
    }
    return true;
  },
  async authorize(authorization, storeId): Promise<UploadPermission> {
    if (!url || !publishable) return "unavailable";
    const response = await boundedFetch(`${url}/rest/v1/rpc/admin_authorize_merchant_menu_upload`, {
      method: "POST",
      headers: { apikey: publishable, Authorization: authorization, "Content-Type": "application/json" },
      body: JSON.stringify({ p_store_id: storeId }),
    });
    const data: unknown = await response.json();
    if (response.ok) return data === true ? "allowed" : "denied";
    const message = data && typeof data === "object" && "message" in data ? data.message : null;
    if (message === "Menu image upload limit reached") return "limited";
    if (message === "Store not found") return "missing";
    if (message === "Not authorized") return "denied";
    return "unavailable";
  },
  normalize: normalizeMenuImage,
  async publish(path, bytes) {
    if (!url || !service) throw new Error("runtime_unavailable");
    const encoded = path.split("/").map(encodeURIComponent).join("/");
    const response = await boundedFetch(`${url}/storage/v1/object/food-public/${encoded}`, {
      method: "POST",
      headers: {
        apikey: service, Authorization: `Bearer ${service}`, "Content-Type": "image/webp",
        "x-upsert": "false", "Cache-Control": "max-age=31536000",
      },
      body: new Uint8Array(bytes),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error("storage_unavailable");
    }
    await response.body?.cancel();
  },
});

Deno.serve(handler);
