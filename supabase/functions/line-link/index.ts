// ZOKY-LINE-001: link / unlink / status of a ZOKY account's LINE OA delivery.
//
// verify_jwt = true. The ZOKY user comes only from the caller's Supabase JWT;
// the LINE userId comes only from an ID token verified by LINE for our LINE
// Login channel. public.line_links is written only here and in line-webhook.
import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import {
  addFriendUrl,
  corsHeaders,
  extraOrigins,
  type FriendStatus,
  type LineAudience,
  lineFriendStatus,
  parseLinkRequest,
  verifiedLineUserId,
} from "./_lib.ts";

function oaEnv(audience: LineAudience) {
  const prefix = audience === "food" ? "LINE_FOOD" : "LINE_MERCHANT";
  return {
    accessToken: Deno.env.get(`${prefix}_CHANNEL_ACCESS_TOKEN`)?.trim() ?? "",
    addFriendUrl: addFriendUrl(Deno.env.get(`${prefix}_OA_BASIC_ID`)),
  };
}

Deno.serve(async (req) => {
  const cors = corsHeaders(req.headers.get("origin"), extraOrigins(Deno.env.get("LINE_LINK_EXTRA_ORIGINS")));
  const json = (body: unknown, status = 200) =>
    new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const authHeader = req.headers.get("Authorization");
  if (!url || !serviceKey || !authHeader) return json({ error: "unauthorized" }, 401);
  if (Deno.env.get("LINE_NOTIFICATIONS_ENABLED") !== "1") return json({ error: "line_disabled" }, 503);

  let parsed: ReturnType<typeof parseLinkRequest>;
  try {
    parsed = parseLinkRequest(await req.json());
  } catch {
    parsed = null;
  }
  if (!parsed) return json({ error: "invalid_body" }, 400);
  const request = parsed;

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(authHeader.replace(/^Bearer\s+/i, ""));
  const user = userData?.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  const oa = oaEnv(request.audience);
  if (!oa.accessToken) return json({ error: "line_not_configured" }, 503);

  const table = () => admin.from("line_links");
  const statusOf = async () => {
    const { data, error } = await table()
      .select("line_user_id,friend_status,linked_at")
      .eq("user_id", user.id)
      .eq("audience", request.audience)
      .maybeSingle();
    if (error) throw new Error("line_links read failed");
    if (!data) return { linked: false, friendStatus: null, addFriendUrl: oa.addFriendUrl };
    // Refresh friendship so the UI can ask the user to add the OA.
    const live = await lineFriendStatus(fetch, oa.accessToken, data.line_user_id as string);
    const friendStatus: FriendStatus = live === "unknown" ? data.friend_status as FriendStatus : live;
    if (friendStatus !== data.friend_status) {
      await table().update({ friend_status: friendStatus, updated_at: new Date().toISOString() })
        .eq("user_id", user.id).eq("audience", request.audience);
    }
    return { linked: true, friendStatus, linkedAt: data.linked_at, addFriendUrl: oa.addFriendUrl };
  };

  try {
    if (request.action === "status") return json(await statusOf());

    if (request.action !== "link") {
      const { error } = await table().delete().eq("user_id", user.id).eq("audience", request.audience);
      if (error) return json({ error: "unlink_failed" }, 500);
      return json({ linked: false, friendStatus: null, addFriendUrl: oa.addFriendUrl });
    }

    const channelId = Deno.env.get("LINE_LOGIN_CHANNEL_ID")?.trim() ?? "";
    if (!/^\d{6,12}$/.test(channelId)) return json({ error: "line_not_configured" }, 503);
    const lineUserId = await verifiedLineUserId(fetch, request.idToken, channelId, Date.now());
    if (!lineUserId) return json({ error: "invalid_line_token" }, 401);

    // Whoever proves control of this LINE account moves it to their ZOKY
    // account; the previous account stops receiving its messages.
    const moved = await table().delete()
      .eq("audience", request.audience).eq("line_user_id", lineUserId).neq("user_id", user.id);
    if (moved.error) return json({ error: "link_failed" }, 500);

    const friendStatus = await lineFriendStatus(fetch, oa.accessToken, lineUserId);
    const now = new Date().toISOString();
    const { error } = await table().upsert({
      user_id: user.id,
      audience: request.audience,
      line_user_id: lineUserId,
      friend_status: friendStatus,
      linked_at: now,
      updated_at: now,
    }, { onConflict: "user_id,audience" });
    if (error) return json({ error: "link_failed" }, 409);
    return json({ linked: true, friendStatus, linkedAt: now, addFriendUrl: oa.addFriendUrl });
  } catch {
    return json({ error: "internal_error" }, 500);
  }
});
