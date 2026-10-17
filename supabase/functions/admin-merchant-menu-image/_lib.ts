// Upload bytes never become a menu reference until the existing audited menu
// save succeeds. Only the trusted publisher may write the reserved namespace.
export const MAX_MENU_IMAGE_BYTES = 4 * 1024 * 1024;
export const MENU_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Cache-Control": "no-store",
};

export type UploadPermission = "allowed" | "denied" | "missing" | "limited" | "unavailable";
export type MenuImageDependencies = {
  authenticate: (authorization: string) => Promise<boolean>;
  authorize: (authorization: string, storeId: string) => Promise<UploadPermission>;
  normalize: (bytes: Uint8Array, contentType: string) => Promise<Uint8Array>;
  publish: (path: string, bytes: Uint8Array) => Promise<void>;
  randomId?: () => string;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

async function boundedBody(req: Request): Promise<Uint8Array | null> {
  if (!req.body) return null;
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  let timedOut = false;
  const deadline = setTimeout(() => {
    timedOut = true;
    void reader.cancel().catch(() => {});
  }, 15_000);
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_MENU_IMAGE_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
  } finally {
    clearTimeout(deadline);
    reader.releaseLock();
  }
  if (!size || timedOut) return null;
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

export function menuImageHandler(deps: MenuImageDependencies) {
  // A single isolate has a 256 MiB platform limit. Bound body buffers while
  // cold WASM initializes as well as synchronous decode work; other isolates
  // may serve independent uploads. Do not queue unbounded authenticated bodies.
  let activeUpload = false;
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
    const authorization = req.headers.get("Authorization") ?? "";
    if (!/^Bearer\s+\S+$/i.test(authorization) || authorization.length > 8192) {
      return json({ error: "unauthorized" }, 401);
    }
    const storeId = new URL(req.url).searchParams.get("store_id") ?? "";
    if (!UUID.test(storeId)) return json({ error: "invalid_store" }, 400);
    const contentType = (req.headers.get("Content-Type") ?? "").toLowerCase();
    if (!MENU_IMAGE_TYPES.has(contentType)) return json({ error: "unsupported_image_type" }, 415);
    const length = req.headers.get("Content-Length");
    if (length !== null && (!/^\d+$/.test(length) || Number(length) === 0)) {
      return json({ error: "invalid_image_size" }, 400);
    }
    if (length !== null && Number(length) > MAX_MENU_IMAGE_BYTES) {
      return json({ error: "image_too_large" }, 413);
    }
    let admitted = false;
    try {
      if (!await deps.authenticate(authorization)) return json({ error: "unauthorized" }, 401);
      const permission = await deps.authorize(authorization, storeId.toLowerCase());
      if (permission !== "allowed") {
        const status = { denied: 403, missing: 404, limited: 429, unavailable: 503 }[permission] ?? 503;
        return json({ error: permission === "limited" ? "upload_limit_reached" : permission === "unavailable"
          ? "upload_unavailable" : permission === "missing" ? "store_not_found" : "not_authorized" }, status);
      }
      // Authentication and the atomic per-actor budget precede body allocation
      // and WASM work. A missing/false permission response always fails closed.
      if (req.signal.aborted) return json({ error: "upload_cancelled" }, 400);
      if (activeUpload) return json({ error: "upload_busy" }, 503);
      activeUpload = true;
      admitted = true;
      const bytes = await boundedBody(req);
      if (!bytes) return json({ error: "invalid_image_size" }, 413);
      if (length !== null && Number(length) !== bytes.byteLength) return json({ error: "invalid_image_size" }, 400);
      let normalized: Uint8Array;
      try {
        normalized = await deps.normalize(bytes, contentType);
      } catch {
        return json({ error: "invalid_image" }, 422);
      }
      if (!normalized.byteLength || normalized.byteLength > MAX_MENU_IMAGE_BYTES) {
        return json({ error: "invalid_image_size" }, 422);
      }
      if (req.signal.aborted) return json({ error: "upload_cancelled" }, 400);
      const id = deps.randomId ? deps.randomId() : crypto.randomUUID();
      if (!UUID.test(id)) throw new Error("invalid_generated_identity");
      const path = `admin-menu/${storeId.toLowerCase()}/${id.toLowerCase()}.webp`;
      await deps.publish(path, normalized);
      return json({ path });
    } catch {
      // Provider responses, identities and credentials are never reflected in
      // errors. Retrying can leave an unattached immutable image; never delete
      // a possibly referenced object during request recovery.
      return json({ error: "upload_unavailable" }, 503);
    } finally {
      if (admitted) activeUpload = false;
    }
  };
}
