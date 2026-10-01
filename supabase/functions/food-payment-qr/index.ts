// @ts-types="npm:@types/qrcode@1.5.5"
import QRCode from "npm:qrcode@1.5.4";
import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { buildPromptPayPayload } from "./_lib.ts";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
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
  } catch {
    return null;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  const key = serviceKey();
  const url = Deno.env.get("SUPABASE_URL");
  if (!authHeader || !key || !url) return json({ error: "unauthorized" }, 401);

  const token = authHeader.replace(/^Bearer\s+/i, "");
  const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  const user = userData.user;
  if (userError || !user) return json({ error: "unauthorized" }, 401);

  let orderId = "";
  try {
    const body = await req.json() as { orderId?: unknown };
    orderId = typeof body.orderId === "string" ? body.orderId : "";
  } catch {
    return json({ error: "invalid_body" }, 400);
  }
  if (!orderId) return json({ error: "order_id_required" }, 400);

  const { data: order, error: orderError } = await admin
    .from("food_orders")
    .select("id,buyer_id,store_id,total,status")
    .eq("id", orderId)
    .maybeSingle();

  if (orderError || !order || order.buyer_id !== user.id) return json({ error: "order_not_found" }, 404);
  if (["delivered", "cancelled"].includes(order.status)) return json({ error: "order_closed" }, 409);

  const { data: store, error: storeError } = await admin
    .from("food_stores")
    .select("id,promptpay_id,promptpay_name")
    .eq("id", order.store_id)
    .maybeSingle();

  if (storeError || !store) return json({ error: "store_not_found" }, 404);
  if (!store.promptpay_id) return json({ error: "promptpay_not_configured" }, 422);

  try {
    const payload = buildPromptPayPayload(store.promptpay_id, Number(order.total));
    const svg = await QRCode.toString(payload, {
      type: "svg",
      width: 360,
      margin: 2,
      errorCorrectionLevel: "M",
    });
    return json({
      dataUrl: "data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg),
      amount: Number(order.total),
      payeeName: store.promptpay_name,
    });
  } catch {
    return json({ error: "invalid_promptpay_configuration" }, 422);
  }
});
