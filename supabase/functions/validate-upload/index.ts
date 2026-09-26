// WEB-B1-QA-04: delete uploads in the image buckets whose bytes are not an
// image. Triggered by the storage.objects Database Webhook installed by
// .github/workflows/storage-upload-validator.yml. See _lib.ts.
import {
  type Deps,
  objectUrl,
  type ReadResult,
  SNIFF_BYTES,
  type Target,
  validateUpload,
  type WebhookPayload,
} from "./_lib.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const authHeaders = { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` };

async function readHead(target: Target): Promise<ReadResult> {
  let response: Response;
  try {
    response = await fetch(objectUrl(SUPABASE_URL, target.bucket, target.name), {
      headers: { ...authHeaders, Range: `bytes=0-${SNIFF_BYTES - 1}` },
    });
  } catch {
    return { status: "error" };
  }
  if (response.status === 404 || response.status === 400) {
    await response.body?.cancel();
    return { status: "missing" };
  }
  if (!response.ok || !response.body) {
    await response.body?.cancel();
    return { status: "error", httpStatus: response.status };
  }
  // Read at most SNIFF_BYTES even if the server ignores Range.
  const reader = response.body.getReader();
  const out = new Uint8Array(SNIFF_BYTES);
  let length = 0;
  try {
    while (length < SNIFF_BYTES) {
      const { done, value } = await reader.read();
      if (done || !value) break;
      const take = Math.min(value.length, SNIFF_BYTES - length);
      out.set(value.subarray(0, take), length);
      length += take;
    }
  } finally {
    await reader.cancel().catch(() => {});
  }
  return { status: "ok", bytes: out.subarray(0, length) };
}

async function remove(target: Target): Promise<boolean> {
  try {
    const response = await fetch(objectUrl(SUPABASE_URL, target.bucket, target.name), {
      method: "DELETE",
      headers: authHeaders,
    });
    await response.body?.cancel();
    return response.ok;
  } catch {
    return false;
  }
}

const deps: Deps = {
  readHead,
  remove,
  sleep: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),
  log: (entry) => console.log(JSON.stringify({ fn: "validate-upload", ...entry })),
};

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("method not allowed", { status: 405 });
  let payload: WebhookPayload;
  try {
    payload = await req.json();
  } catch {
    return new Response(JSON.stringify({ outcome: "ignored" }), { status: 200 });
  }
  const outcome = await validateUpload(payload, deps);
  return new Response(JSON.stringify({ outcome }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
