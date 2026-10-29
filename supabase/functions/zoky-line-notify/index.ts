import { createClient } from "npm:@supabase/supabase-js@2.112.3";
import { makeOrderFlexCard } from "../zoky-line-webhook/order-card.mjs";

// Internal dispatcher. Set verify_jwt=false ONLY because this endpoint uses a
// separate long random x-zoky-line-worker-key and is never exposed to browsers.
function serviceKey(): string | null {
  if (Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")) return Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  try {
    return (JSON.parse(Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}") as Record<string, string>).default ?? null;
  } catch { return null; }
}
function sameSecret(given: string | null, expected: string) {
  if (!given || !expected || given.length !== expected.length) return false;
  let diff=0;
  for(let i=0;i<given.length;i++) diff |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  return diff===0;
}
function response(status: number, code: string) {
  return new Response(JSON.stringify({ status: code }), {
    status, headers: { "content-type": "application/json", "cache-control": "no-store" },
  });
}
Deno.serve(async (request: Request) => {
  if (request.method !== "POST") return response(405,"method_not_allowed");
  const workerKey = Deno.env.get("ZOKY_LINE_WORKER_KEY") ?? "";
  if (workerKey.length < 40 || !sameSecret(request.headers.get("x-zoky-line-worker-key"),workerKey)) {
    return response(401,"unauthorized");
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = serviceKey();
  const token = Deno.env.get("ZOKY_LINE_CHANNEL_ACCESS_TOKEN");
  if (!url || !key || !token) return response(503,"not_configured");
  const admin = createClient(url,key,{auth:{persistSession:false,autoRefreshToken:false}});
  const {data: deliveries,error} = await admin.rpc("zoky_line_claim_deliveries",{p_limit:20});
  if (error || !Array.isArray(deliveries)) return response(503,"outbox_unavailable");
  let sent=0,failed=0;
  for (const delivery of deliveries) {
    try {
      const orderNumber = String(delivery.order_number);
      const totalBaht = Number(delivery.total);
      const message = makeOrderFlexCard({
        orderId:delivery.order_id,orderNumber,storeName:delivery.store_name,totalBaht,
      });
      const line = await fetch("https://api.line.me/v2/bot/message/push",{
        method:"POST",
        headers:{
          Authorization:"Bearer "+token,
          "Content-Type":"application/json",
          "X-Line-Retry-Key":crypto.randomUUID(),
        },
        body:JSON.stringify({to:delivery.line_user_id,messages:[message]}),
        signal:AbortSignal.timeout(8000),
      });
      if (!line.ok) throw new Error(line.status===429?"rate_limited":"line_send_failed");
      const updated=await admin.from("zoky_line_delivery_queue")
        .update({state:"delivered",delivered_at:new Date().toISOString(),last_error_code:null})
        .eq("id",delivery.id).eq("state","claimed");
      if(updated.error) throw new Error("delivery_receipt_failed");
      sent++;
    } catch (cause) {
      failed++;
      const retryable = delivery.attempts < 5;
      // Never print the LINE user ID, order or secret to logs.
      const code = cause instanceof Error && cause.message==="rate_limited" ? "rate_limited" : "delivery_failed";
      await admin.from("zoky_line_delivery_queue")
        .update({
          state:retryable?"pending":"failed",
          next_attempt_at:new Date(Date.now()+Math.min(60,2**Math.min(delivery.attempts,6))*60000).toISOString(),
          last_error_code:code,
        }).eq("id",delivery.id).eq("state","claimed");
    }
  }
  return new Response(JSON.stringify({ok:true,sent,failed}),{
    headers:{"content-type":"application/json","cache-control":"no-store"},
  });
});
