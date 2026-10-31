// ZOKY-LINE-001: LINE OA webhook. Keeps public.line_links.friend_status in
// step with follow/unfollow so blocked users are not pushed to.
//
// verify_jwt = false: LINE cannot send a Supabase JWT. Every request is
// authenticated by X-Line-Signature against the OA's channel secret, chosen
// by ?oa=food|merchant. Unsigned or mis-signed requests change nothing.
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import { audienceFromUrl, friendUpdates, isValidLineSignature } from "./_lib.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const audience = audienceFromUrl(req.url);
  if (!audience) return new Response("Unknown OA", { status: 404 });

  const secret = Deno.env.get(audience === "food" ? "LINE_FOOD_CHANNEL_SECRET" : "LINE_MERCHANT_CHANNEL_SECRET")?.trim() ?? "";
  const rawBody = await req.text();
  if (rawBody.length > 1_000_000) return new Response("Too large", { status: 413 });
  if (!(await isValidLineSignature(secret, rawBody, req.headers.get("x-line-signature")))) {
    return new Response("Invalid signature", { status: 401 });
  }

  let updates: ReturnType<typeof friendUpdates>;
  try {
    updates = friendUpdates(JSON.parse(rawBody));
  } catch {
    return new Response("Bad request", { status: 400 });
  }
  // LINE's "Verify" button sends an empty event list.
  if (updates.length === 0) return new Response("OK", { status: 200 });

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return new Response("Not configured", { status: 503 });
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  const now = new Date().toISOString();
  const results = await Promise.all(updates.map(({ lineUserId, friendStatus }) =>
    admin.from("line_links")
      .update({ friend_status: friendStatus, updated_at: now })
      .eq("audience", audience)
      .eq("line_user_id", lineUserId)
  ));
  const failed = results.filter((result) => result.error).length;
  if (failed > 0) {
    console.error(`line-webhook: ${failed} of ${results.length} friend updates failed`);
    // 500 makes LINE redeliver when webhook redelivery is enabled.
    return new Response("Update failed", { status: 500 });
  }
  return new Response("OK", { status: 200 });
});
