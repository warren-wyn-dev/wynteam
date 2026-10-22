import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import { runWorker, stripeLivemode } from "./_lib.ts";

// Invoked once per minute by pg_cron through pg_net, never by a browser.
// The Vault-backed request key is verified against a service-role-only RPC.
// Executes queued Stripe jobs (expire Checkout on cancel, full refunds);
// all decisions live in _lib.ts.
function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status, headers: { "Content-Type": "application/json" },
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
  } catch { return null; }
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  const dbUrl = Deno.env.get("SUPABASE_URL");
  const dbKey = serviceKey();
  const token = req.headers.get("x-wynos-cron-key");
  if (!dbUrl || !dbKey || !token) return json({ error: "unauthorized" }, 401);

  const admin = createClient(dbUrl, dbKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const check = await admin.rpc("food_refund_worker_cron_authorized", { p_token: token });
  if (check.error || check.data !== true) return json({ error: "unauthorized" }, 401);

  // Fail closed before claiming anything: jobs stay queued until Stripe is configured.
  const secret = Deno.env.get("STRIPE_SECRET_KEY")?.trim() ?? "";
  const livemode = secret ? stripeLivemode(secret) : null;
  if (!secret || livemode == null) return json({ error: "payments_not_configured" }, 503);

  const result = await runWorker(
    async (fn, args) => {
      const { data, error } = await admin.rpc(fn, args);
      return { data, error };
    },
    { secret, livemode, fetch: (input, init) => fetch(input, init) },
  );
  if (!result.ok) return json({ error: result.error }, 500);
  return json({ claimed: result.claimed, counts: result.counts });
});
