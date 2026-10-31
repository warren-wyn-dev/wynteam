import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { handleLineWebhook } from "./handler.mjs";
import { createLineEventProcessor } from "./events.mjs";

function serviceKey(): string | null {
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
const channelSecret = Deno.env.get("ZOKY_LINE_CHANNEL_SECRET") ?? "";
const channelToken = Deno.env.get("ZOKY_LINE_CHANNEL_ACCESS_TOKEN") ?? "";
const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const key = serviceKey();
// Readiness gate: a misconfigured function MUST NOT process LINE messages.
// The database RPCs are deployed only after the separate production approval.
const ready = Boolean(channelSecret && channelToken && key && supabaseUrl);
const admin = ready ? createClient(supabaseUrl, key!, {
  auth: { autoRefreshToken: false, persistSession: false },
}) : null;

const processor = admin ? createLineEventProcessor({
  channelToken,
  repository: {
    async completeLink({ nonceHash, lineUserId }: { nonceHash: string; lineUserId: string }) {
      const { data, error } = await admin.rpc("zoky_line_complete_link", {
        p_nonce_sha256: nonceHash, p_line_user_id: lineUserId,
      });
      if (error) throw new Error("line_link_write_failed");
      return data === true;
    },
    async transitionOrder({ lineUserId, action, orderId }: { lineUserId: string; action: string; orderId: string }) {
      const { data, error } = await admin.rpc("zoky_line_transition_order", {
        p_line_user_id: lineUserId, p_action: action, p_order_id: orderId,
      });
      if (error) throw new Error("line_order_transition_failed");
      return data as { ok: boolean } | null;
    },
  },
}) : null;

Deno.serve((request: Request) => {
  if (!ready) return new Response(JSON.stringify({ status: "not_configured" }), {
    status: 503, headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
  return handleLineWebhook(request, channelSecret, processor);
});
