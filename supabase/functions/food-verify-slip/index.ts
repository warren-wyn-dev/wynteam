import { createClient } from "npm:@supabase/supabase-js@2.112.3";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

type VerificationStatus = "auto_verified" | "manual_review" | "rejected";

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

function numberOrNull(value: unknown) {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}

function codeOf(payload: unknown) {
  if (!payload || typeof payload !== "object") return null;
  const code = (payload as Record<string, unknown>).code;
  return typeof code === "number" || typeof code === "string" ? String(code) : null;
}

function dataOf(payload: unknown) {
  if (!payload || typeof payload !== "object") return null;
  const data = (payload as Record<string, unknown>).data;
  return data && typeof data === "object" ? data as Record<string, unknown> : null;
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
    .select("id,buyer_id,store_id,total,status,payment_status,payment_slip_path")
    .eq("id", orderId)
    .maybeSingle();

  if (orderError || !order || order.buyer_id !== user.id) return json({ error: "order_not_found" }, 404);
  if (["delivered", "cancelled"].includes(order.status)) return json({ error: "order_closed" }, 409);
  if (!order.payment_slip_path || order.payment_status !== "submitted") {
    return json({ error: "slip_not_submitted" }, 409);
  }

  const branchId = Deno.env.get("SLIPOK_BRANCH_ID")?.trim();
  const apiKey = Deno.env.get("SLIPOK_API_KEY")?.trim();
  const receiverStoreId = Deno.env.get("SLIPOK_RECEIVER_STORE_ID")?.trim();
  const receiverBound = Boolean(receiverStoreId && receiverStoreId === order.store_id);

  const record = async (args: {
    provider: string;
    result: VerificationStatus;
    transactionRef?: string | null;
    amount?: number | null;
    amountMatch?: boolean | null;
    receiverMatch?: boolean | null;
    providerCode?: string | null;
    note?: string | null;
  }) => {
    const { data, error } = await admin.rpc("food_record_payment_verification", {
      p_order_id: order.id,
      p_provider: args.provider,
      p_result: args.result,
      p_transaction_ref: args.transactionRef ?? null,
      p_amount: args.amount ?? null,
      p_amount_match: args.amountMatch ?? null,
      p_receiver_match: args.receiverMatch ?? null,
      p_provider_code: args.providerCode ?? null,
      p_note: args.note ?? null,
    });
    if (error) throw error;
    return String(data) as VerificationStatus;
  };

  if (!branchId || !apiKey) {
    const status = await record({
      provider: "manual",
      result: "manual_review",
      providerCode: "provider_not_configured",
      note: "ระบบตรวจสลิปอัตโนมัติยังไม่ได้เชื่อมต่อ ร้านจะตรวจสอบให้",
    });
    return json({ status, provider: "manual" });
  }

  const { data: slip, error: slipError } = await admin.storage
    .from("food-private")
    .download(order.payment_slip_path);

  if (slipError || !slip) {
    const status = await record({
      provider: "slipok",
      result: "manual_review",
      providerCode: "slip_download_failed",
      note: "ระบบเปิดสลิปเพื่อตรวจอัตโนมัติไม่ได้ ร้านจะตรวจสอบให้",
    });
    return json({ status, provider: "slipok" });
  }

  const form = new FormData();
  form.append("files", slip, "payment-slip");
  form.append("amount", Number(order.total).toFixed(2));
  form.append("log", receiverBound ? "true" : "false");

  let response: Response;
  let payload: unknown;
  try {
    response = await fetch(`https://api.slipok.com/api/line/apikey/${encodeURIComponent(branchId)}`, {
      method: "POST",
      headers: { "x-authorization": apiKey },
      body: form,
    });
    payload = await response.json().catch(() => ({}));
  } catch {
    const status = await record({
      provider: "slipok",
      result: "manual_review",
      providerCode: "provider_unreachable",
      note: "ระบบตรวจสลิปอัตโนมัติติดต่อผู้ให้บริการไม่ได้ ร้านจะตรวจสอบให้",
    });
    return json({ status, provider: "slipok" });
  }

  const providerCode = codeOf(payload);
  const providerData = dataOf(payload);
  const transactionRef = typeof providerData?.transRef === "string" ? providerData.transRef : null;
  const amount = numberOrNull(providerData?.amount ?? providerData?.paidLocalAmount);
  const amountMatch = amount == null ? null : Math.abs(amount - Number(order.total)) < 0.005;

  if (response.ok && providerData) {
    const status = await record({
      provider: "slipok",
      result: receiverBound && amountMatch === true && transactionRef ? "auto_verified" : "manual_review",
      transactionRef,
      amount,
      amountMatch,
      receiverMatch: receiverBound ? true : null,
      providerCode: providerCode ?? "200",
      note: receiverBound
        ? "SlipOK ตรวจสลิป ยอด และบัญชีผู้รับสำเร็จ"
        : "SlipOK ตรวจสลิปและยอดแล้ว แต่บัญชีผู้รับยังต้องให้ร้านยืนยัน",
    });
    return json({ status, provider: "slipok", receiverVerified: receiverBound });
  }

  const code = Number(providerCode);
  if ([1012, 1013, 1014].includes(code)) {
    const status = await record({
      provider: "slipok",
      result: "rejected",
      transactionRef,
      amount,
      amountMatch: code === 1013 ? false : amountMatch,
      receiverMatch: code === 1014 ? false : (receiverBound ? true : null),
      providerCode,
      note: code === 1012
        ? "สลิปนี้ถูกใช้แล้ว"
        : code === 1013
          ? "ยอดเงินในสลิปไม่ตรงกับยอดออเดอร์"
          : "บัญชีผู้รับในสลิปไม่ตรงกับร้าน",
    });
    return json({ status, provider: "slipok", code: providerCode });
  }

  if ([1005, 1006, 1007, 1008, 1011].includes(code)) {
    const status = await record({
      provider: "slipok",
      result: "rejected",
      transactionRef,
      amount,
      amountMatch,
      receiverMatch: null,
      providerCode,
      note: "สลิปไม่ถูกต้องหรือไม่พบรายการชำระเงินจริง",
    });
    return json({ status, provider: "slipok", code: providerCode });
  }

  const status = await record({
    provider: "slipok",
    result: "manual_review",
    transactionRef,
    amount,
    amountMatch,
    receiverMatch: null,
    providerCode: providerCode ?? String(response.status),
    note: "ระบบตรวจอัตโนมัติยังยืนยันรายการไม่ได้ ร้านจะตรวจสอบให้",
  });
  return json({ status, provider: "slipok", code: providerCode });
});
