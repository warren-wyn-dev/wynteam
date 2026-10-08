"use client";

import { useCallback, useEffect, useRef, useState, type CSSProperties } from "react";
import type { User } from "@supabase/supabase-js";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const SANDBOX_URL = "https://pcatuxtenluqzjzzwsvl.supabase.co";
// Client-visible diagnostics expose only whether a setting is valid, never its value.
const SANDBOX_FLAG_OK = process.env.NEXT_PUBLIC_WYNOS_STRIPE_SANDBOX === "true";
const SANDBOX_URL_OK =
  (process.env.NEXT_PUBLIC_SUPABASE_URL?.trim().replace(/\/+$/, "") ?? "") === SANDBOX_URL;
const PUBLISHABLE_KEY_PRESENT = Boolean(process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY?.trim());
const ENABLED = SANDBOX_FLAG_OK && SANDBOX_URL_OK && PUBLISHABLE_KEY_PRESENT;
const QA_MERCHANT_USER_ID = "50956870-1d09-4e0a-98bf-2c1e0e0c722b";
const QA_CONNECT_STORE_ID = "6638327e-353f-4151-8d69-d84b5badb831";

type Order = {
  id: string;
  order_number: string;
  total: number;
  status: string;
  payment_status: string;
};

function formatBaht(value: number) {
  return new Intl.NumberFormat("th-TH", {
    style: "currency",
    currency: "THB",
  }).format(value);
}

export default function StripeSandboxPage() {
  const [user, setUser] = useState<User | null>(null);
  const [orders, setOrders] = useState<Order[]>([]);
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(false);
  const [busyOrder, setBusyOrder] = useState<string | null>(null);
  const [reconcileBusy, setReconcileBusy] = useState(false);
  const [reconcileMessage, setReconcileMessage] = useState("");
  const [connectBusy, setConnectBusy] = useState(false);
  const [connectMessage, setConnectMessage] = useState("");
  const [connectStatusMessage, setConnectStatusMessage] = useState("");
  const [connectCheckBusy, setConnectCheckBusy] = useState(false);
  const [returnStatus, setReturnStatus] = useState<string | null>(null);
  const autoReconcileStarted = useRef<string | null>(null);

  const refresh = useCallback(async (userId: string) => {
    if (!ENABLED) return;
    const client = getSupabaseBrowserClient();
    if (!client) return;
    const { data, error } = await client
      .from("food_orders")
      .select("id,order_number,total,status,payment_status")
      .eq("buyer_id", userId)
      .order("created_at", { ascending: false })
      .limit(20);
    if (error) {
      setMessage("โหลดคำสั่งซื้อไม่ได้: " + error.message);
      return;
    }
    setOrders((data ?? []) as Order[]);
  }, []);

  useEffect(() => {
    if (!ENABLED) return;
    const client = getSupabaseBrowserClient();
    if (!client) return;
    let mounted = true;
    const params = new URLSearchParams(window.location.search);
    const stripe = params.get("stripe");
    if (stripe === "success") {
      setReturnStatus("Stripe กลับจากหน้าชำระเงินแล้ว กำลังตรวจสอบผลชำระกับ Stripe อัตโนมัติ โดยไม่เรียกเก็บเงินซ้ำ");
    } else if (stripe === "cancelled") {
      setReturnStatus("คุณยกเลิกการชำระเงินทดสอบแล้ว");
    }
    const connect = params.get("connect");
    if (connect === "return") {
      setReturnStatus("กลับจาก Stripe Connect Test Mode แล้ว กรุณาตรวจสอบสถานะบัญชีร้านค้าอีกครั้ง");
    } else if (connect === "refresh") {
      setReturnStatus("ลิงก์ Stripe Connect หมดอายุ กรุณากดเชื่อมร้านค้าทดลองอีกครั้ง");
    }
    void client.auth.getUser().then(({ data }) => {
      if (!mounted) return;
      setUser(data.user);
      if (data.user) void refresh(data.user.id);
    });
    const { data: sub } = client.auth.onAuthStateChange((_event, session) => {
      if (!mounted) return;
      setUser(session?.user ?? null);
      if (session?.user) void refresh(session.user.id);
      else setOrders([]);
    });
    return () => {
      mounted = false;
      sub.subscription.unsubscribe();
    };
  }, [refresh]);

  async function auth(mode: "signin" | "signup") {
    const client = getSupabaseBrowserClient();
    if (!ENABLED || !client || loading) return;
    setLoading(true);
    setMessage("");
    try {
      const result =
        mode === "signup"
          ? await client.auth.signUp({ email: email.trim(), password })
          : await client.auth.signInWithPassword({ email: email.trim(), password });
      if (result.error) throw result.error;
      setPassword("");
      setMessage(
        mode === "signup"
          ? "สมัครบัญชีทดสอบแล้ว หากระบบต้องยืนยันอีเมล ให้เปิดลิงก์ยืนยันก่อนเข้าสู่ระบบ"
          : "เข้าสู่ระบบทดสอบแล้ว",
      );
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "ดำเนินการไม่สำเร็จ");
    } finally {
      setLoading(false);
    }
  }

  async function checkConnectStatus() {
    if (!ENABLED || !user || user.id !== QA_MERCHANT_USER_ID || connectCheckBusy) return;
    const client = getSupabaseBrowserClient();
    if (!client) return;
    setConnectCheckBusy(true);
    try {
      const { data, error } = await client.functions.invoke("merchant-stripe-connect", {
        body: { storeId: QA_CONNECT_STORE_ID, action: "status" },
      });
      if (error) throw error;
      const state = data as {
        connected?: boolean;
        status?: string;
        charges_enabled?: boolean;
        payouts_enabled?: boolean;
        requirements_due_count?: number;
      } | null;
      if (!state?.connected) {
        setConnectStatusMessage("ยังไม่พบบัญชี Stripe Connect Test Mode ของร้านทดลอง");
      } else if (state.status === "ready" && state.charges_enabled && state.payouts_enabled) {
        setConnectStatusMessage("Stripe Connect Test Mode พร้อมรับชำระเงินทดสอบแล้ว ✓");
      } else if (state.requirements_due_count && state.requirements_due_count > 0) {
        setConnectStatusMessage("Stripe ยังต้องการข้อมูลร้านค้าเพิ่ม " + state.requirements_due_count + " รายการ กรุณากดเชื่อมร้านค้าทดลองเพื่อดำเนินการต่อ");
      } else if (state.charges_enabled && !state.payouts_enabled) {
        setConnectStatusMessage("Stripe เปิดรับชำระเงินแล้ว แต่ยังรอเปิดการเบิกจ่าย (Payouts) จึงยังไม่พร้อมทดสอบ Checkout");
      } else {
        setConnectStatusMessage("สถานะร้านค้าทดสอบ: " + (state.status || "กำลังดำเนินการ") + " — ยังไม่พร้อม Checkout");
      }
    } catch {
      setConnectStatusMessage("ตรวจสอบสถานะ Stripe ไม่สำเร็จ กรุณาลองอีกครั้ง");
    } finally {
      setConnectCheckBusy(false);
    }
  }

  async function connectMerchant() {
    if (!ENABLED || !user || user.id !== QA_MERCHANT_USER_ID || connectBusy) return;
    const client = getSupabaseBrowserClient();
    if (!client) return;
    setConnectBusy(true);
    setConnectMessage("");
    try {
      const { data, error } = await client.functions.invoke("merchant-stripe-connect", {
        body: { storeId: QA_CONNECT_STORE_ID, action: "onboard", qaHostedOnboarding: true },
      });
      if (error) {
        const response = (error as { context?: Response }).context;
        const details = response && typeof response.json === "function"
          ? await response.json().catch(() => null) as { message?: string; error?: string } | null
          : null;
        throw new Error(details?.message || details?.error || error.message);
      }
      const payload = data as { url?: string; message?: string; error?: string } | null;
      if (!payload?.url) {
        if ((payload as { flow?: string } | null)?.flow === "embedded") {
          throw new Error("ได้รับ Embedded Onboarding แทนลิงก์ทดสอบ กรุณารีเฟรช Preview เวอร์ชันล่าสุด");
        }
        throw new Error(payload?.message || payload?.error || "ยังไม่สามารถเปิด Stripe Connect Test Mode ได้");
      }
      const destination = new URL(payload.url);
      if (destination.protocol !== "https:" ||
          !(destination.hostname === "connect.stripe.com" || destination.hostname.endsWith(".stripe.com"))) {
        throw new Error("ลิงก์ Stripe Connect ไม่ผ่านการตรวจสอบ");
      }
      window.location.assign(destination.href);
    } catch (error) {
      setConnectMessage(error instanceof Error ? error.message : "ไม่สามารถเริ่ม Stripe Connect ได้");
      setConnectBusy(false);
    }
  }

  const reconcileCheckout = useCallback(async (order: Order) => {
    if (!ENABLED || !user || user.id !== QA_MERCHANT_USER_ID ||
        order.order_number !== "WF000003" || reconcileBusy || busyOrder) return;
    const client = getSupabaseBrowserClient();
    if (!client) return;
    setReconcileBusy(true);
    setReconcileMessage("");
    setMessage("");
    try {
      const { data, error } = await client.functions.invoke("food-stripe-checkout", {
        body: { orderId: order.id, action: "reconcile" },
      });
      if (error) {
        const response = (error as { context?: Response }).context;
        const body = response && typeof response.json === "function"
          ? await response.json().catch(() => null) as { error?: string } | null
          : null;
        const messages: Record<string, string> = {
          checkout_not_paid: "Stripe ยังไม่ยืนยันว่ารายการนี้ชำระสำเร็จ ระบบยังไม่เปลี่ยนสถานะ",
          qa_checkout_session_not_found: "ยังไม่พบ Checkout Session สำหรับคำสั่งซื้อนี้",
          stripe_checkout_verification_mismatch: "ข้อมูล Checkout ไม่ตรงกับคำสั่งซื้อทดสอบ ระบบปฏิเสธการยืนยันเพื่อความปลอดภัย",
          stripe_verification_failed: "ยังเชื่อมต่อ Stripe เพื่อตรวจสอบรายการไม่ได้",
          payment_intent_not_available: "Stripe ยังไม่ส่งหมายเลข Payment Intent",
          reconcile_record_failed: "Stripe ยืนยันแล้วแต่การบันทึกสถานะไม่สำเร็จ กรุณาติดต่อผู้ดูแล",
        };
        throw new Error((body?.error && messages[body.error]) || "ไม่สามารถตรวจสอบผลชำระจาก Stripe ได้");
      }
      const result = data as { reconciled?: boolean; payment_status?: string } | null;
      if (!result?.reconciled || result.payment_status !== "paid") {
        throw new Error("Stripe ยังไม่สามารถยืนยันว่าชำระเงินสำเร็จ");
      }
      await refresh(user.id);
      setReturnStatus("Stripe Test API ยืนยันการชำระ ฿50 แล้ว และอัปเดตคำสั่งซื้อเป็น paid ✓");
      setReconcileMessage("สำเร็จ: Stripe ยืนยันว่าได้รับชำระเงินทดสอบแล้ว ✓");
    } catch (error) {
      setReconcileMessage(error instanceof Error ? error.message : "ตรวจสอบผลชำระไม่ได้");
    } finally {
      setReconcileBusy(false);
    }
  }, [user, busyOrder, reconcileBusy, refresh]);

  useEffect(() => {
    // Only the explicitly isolated QA order can be reconciled after a Stripe
    // redirect. The server independently checks Stripe session ID, account,
    // payment status, THB amount, currency, buyer and metadata. No new charge.
    if (!ENABLED || !user || user.id !== QA_MERCHANT_USER_ID ||
        !returnStatus?.startsWith("Stripe กลับจากหน้าชำระเงินแล้ว")) return;
    const order = orders.find((candidate) =>
      candidate.order_number === "WF000003" && ["pending", "issue"].includes(candidate.payment_status));
    if (!order || autoReconcileStarted.current === order.id) return;
    autoReconcileStarted.current = order.id;
    void reconcileCheckout(order);
  }, [orders, user, returnStatus, reconcileCheckout]);

  async function checkout(order: Order) {
    if (!ENABLED || busyOrder || !user) return;
    if (!["pending", "issue"].includes(order.payment_status)) return;
    const client = getSupabaseBrowserClient();
    if (!client) return;
    setBusyOrder(order.id);
    setMessage("");
    try {
      const { data, error } = await client.functions.invoke("food-stripe-checkout", {
        body: { orderId: order.id },
      });
      if (error) {
        const response = (error as { context?: Response }).context;
        const body = response && typeof response.json === "function"
          ? await response.json().catch(() => null) as { error?: string; message?: string } | null
          : null;
        const safeCodes: Record<string, string> = {
          sandbox_food_redirect_not_configured: "ยังไม่ได้ตั้งค่า URL สำหรับกลับจาก Stripe Checkout ใน Sandbox",
          stripe_not_ready: "ร้านค้าทดสอบยังไม่พร้อมรับชำระเงิน",
          stripe_checkout_failed: "Stripe ไม่สามารถสร้าง Checkout ได้ กรุณาแจ้งผู้ดูแลทดสอบ",
          sandbox_test_keys_required: "คีย์ Stripe Test Mode ยังไม่พร้อมใช้งาน",
          stripe_not_configured: "คีย์ Stripe Test Mode ยังไม่ถูกตั้งค่าใน Supabase Sandbox",
          payment_record_failed: "บันทึกข้อมูล Checkout ไม่สำเร็จ",
          order_not_payable: "คำสั่งซื้อนี้ยังไม่พร้อมชำระเงิน",
        };
        throw new Error(body?.message || (body?.error && safeCodes[body.error]) || (body?.error ? "ไม่สามารถเปิด Checkout ได้ (" + body.error + ")" : error.message));
      }
      const payload = data as { url?: string; error?: string; message?: string } | null;
      if (!payload?.url) {
        throw new Error(payload?.error || payload?.message || "ยังไม่สามารถสร้าง Checkout ได้");
      }
      const url = new URL(payload.url);
      if (url.protocol !== "https:" || url.hostname !== "checkout.stripe.com") {
        throw new Error("Stripe Checkout URL ไม่ผ่านการตรวจสอบ");
      }
      window.location.assign(url.href);
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "เปิด Stripe Checkout ไม่สำเร็จ");
      setBusyOrder(null);
    }
  }

  const panel: CSSProperties = {
    border: "1px solid #dfe3ea",
    borderRadius: 18,
    backgroundColor: "#fff",
    padding: 22,
    marginBottom: 16,
  };
  const action: CSSProperties = {
    border: 0,
    borderRadius: 12,
    padding: "12px 18px",
    backgroundColor: "#182746",
    color: "#fff",
    fontWeight: 600,
    cursor: "pointer",
  };

  return (
    <main style={{ minHeight: "100vh", background: "#f6f8fc", color: "#152033", padding: "32px 16px" }}>
      <div style={{ maxWidth: 760, margin: "0 auto" }}>
        <p style={{ fontSize: 12, fontWeight: 700, letterSpacing: 2, color: "#475569" }}>
          WYNOS FOOD · TEST MODE ONLY
        </p>
        <h1 style={{ fontSize: 30, margin: "4px 0 8px" }}>Stripe Sandbox</h1>
        <p style={{ color: "#64748b", marginBottom: 24 }}>
          หน้า QA แยกสำหรับทดสอบบัญชี คำสั่งซื้อ และ Stripe Checkout ไม่มีการใช้คีย์ Live
        </p>

        {!ENABLED ? (
          <section style={panel}>
            <h2>ปิดการทำงานเพื่อความปลอดภัย</h2>
            <p>โปรเจกต์นี้ต้องใช้ Supabase Sandbox และตั้งค่าทดสอบให้ครบก่อนเริ่มชำระเงิน</p>
            <ul style={{ lineHeight: 2, marginTop: 12 }}>
              <li>เปิดโหมดทดสอบ: {SANDBOX_FLAG_OK ? "ถูกต้อง ✓" : "ยังไม่ถูกต้อง ✕"}</li>
              <li>Supabase URL เป็น Sandbox: {SANDBOX_URL_OK ? "ถูกต้อง ✓" : "ยังไม่ถูกต้อง ✕"}</li>
              <li>มี Publishable Key: {PUBLISHABLE_KEY_PRESENT ? "ตั้งค่าแล้ว ✓" : "ยังไม่มี ✕"}</li>
            </ul>
            <p style={{ fontSize: 13, color: "#64748b" }}>
              ข้อมูลนี้บอกเพียงผลตรวจสอบ ไม่แสดงค่า API Keys หรือ Secrets และมีผลเฉพาะ Preview ที่ Deploy ล่าสุด
            </p>
          </section>
        ) : (
          <>
            <section style={panel}>
              <strong>สภาพแวดล้อม: Supabase Sandbox</strong>
              <p style={{ fontSize: 13, color: "#64748b", overflowWrap: "anywhere" }}>{SANDBOX_URL}</p>
              <p style={{ fontSize: 13, color: "#64748b" }}>
                ใช้บัญชีทดสอบเท่านั้น อย่าใช้รหัสผ่านของบัญชี Production
              </p>
            </section>

            {returnStatus && <section style={panel} role="status">{returnStatus}</section>}
            {message && <section style={panel} role="status">{message}</section>}

            {!user ? (
              <section style={panel}>
                <h2>เข้าสู่ระบบบัญชีทดลอง</h2>
                <div style={{ display: "grid", gap: 12, maxWidth: 480 }}>
                  <label>
                    อีเมลทดสอบ
                    <input
                      type="email"
                      autoComplete="email"
                      value={email}
                      onChange={(event) => setEmail(event.target.value)}
                      style={{ display: "block", width: "100%", padding: 12, border: "1px solid #cbd5e1", borderRadius: 9 }}
                    />
                  </label>
                  <label>
                    รหัสผ่านสำหรับบัญชีทดสอบ
                    <input
                      type="password"
                      autoComplete="current-password"
                      value={password}
                      onChange={(event) => setPassword(event.target.value)}
                      style={{ display: "block", width: "100%", padding: 12, border: "1px solid #cbd5e1", borderRadius: 9 }}
                    />
                  </label>
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
                    <button style={action} disabled={loading || !email || !password} onClick={() => void auth("signin")}>
                      เข้าสู่ระบบ
                    </button>
                    <button
                      style={{ ...action, backgroundColor: "#eff3f9", color: "#152033" }}
                      disabled={loading || !email || password.length < 8}
                      onClick={() => void auth("signup")}
                    >
                      สมัครบัญชีทดสอบ
                    </button>
                  </div>
                </div>
              </section>
            ) : (
              <section style={panel}>
                <div style={{ display: "flex", gap: 12, alignItems: "center", justifyContent: "space-between", flexWrap: "wrap" }}>
                  <div><strong>บัญชีทดลอง</strong><div style={{ fontSize: 13, color: "#64748b" }}>{user.email}</div></div>
                  <button
                    style={{ ...action, backgroundColor: "#eff3f9", color: "#152033" }}
                    onClick={() => void getSupabaseBrowserClient()?.auth.signOut()}
                  >
                    ออกจากระบบ
                  </button>
                </div>
                {user.id === QA_MERCHANT_USER_ID && (
                  <div style={{ border: "1px solid #bfdbfe", borderRadius: 12, padding: 16, marginTop: 24, background: "#f8fbff" }}>
                    <h2 style={{ margin: "0 0 8px" }}>ร้านค้าทดลอง · Stripe Connect</h2>
                    <p style={{ color: "#64748b" }}>
                      เชื่อมร้าน WYNOS Stripe QA Store เฉพาะ Supabase Sandbox เท่านั้น
                      เพื่อเปิดรับการชำระเงินด้วย Stripe Test Mode ไม่มีการรับเงินจริง
                    </p>
                    {connectMessage && <p role="alert" style={{ color: "#b91c1c", overflowWrap: "anywhere" }}>{connectMessage}</p>}
                    {connectStatusMessage && <p role="status" style={{ color: "#334155", overflowWrap: "anywhere" }}>{connectStatusMessage}</p>}
                    <button style={{ ...action, marginBottom: 10 }} disabled={connectCheckBusy} onClick={() => void checkConnectStatus()}>
                      {connectCheckBusy ? "กำลังตรวจสถานะ Stripe..." : "ตรวจสอบสถานะ Stripe Connect"}
                    </button>
                    <button style={action} disabled={connectBusy} onClick={() => void connectMerchant()}>
                      {connectBusy ? "กำลังเตรียม Stripe Connect..." : "เชื่อมร้านค้าทดลองกับ Stripe Connect"}
                    </button>
                  </div>
                )}
                <h2 style={{ marginTop: 26 }}>คำสั่งซื้อของคุณ</h2>
                <button style={{ ...action, marginBottom: 16 }} onClick={() => void refresh(user.id)}>
                  รีเฟรชสถานะจากฐานข้อมูล
                </button>
                {orders.length === 0 ? (
                  <p style={{ color: "#64748b" }}>
                    ยังไม่มีคำสั่งซื้อทดสอบ ต้องเตรียมร้านค้าและคำสั่งซื้อใน Sandbox ก่อนเริ่ม Checkout
                  </p>
                ) : (
                  <div style={{ display: "grid", gap: 10 }}>
                    {orders.map((order) => (
                      <div key={order.id} style={{ border: "1px solid #e2e8f0", borderRadius: 12, padding: 15 }}>
                        <strong>{order.order_number}</strong>
                        <p style={{ margin: "8px 0", color: "#64748b" }}>
                          {formatBaht(Number(order.total))} · สถานะ: {order.payment_status} · {order.status}
                        </p>
                        {user.id === QA_MERCHANT_USER_ID && order.order_number === "WF000003" &&
                          ["pending", "issue"].includes(order.payment_status) && (
                            <div style={{ marginBottom: 12 }}>
                              <button disabled={reconcileBusy || Boolean(busyOrder)} onClick={() => void reconcileCheckout(order)}
                                style={{ ...action, backgroundColor: "#136f63" }}>
                                {reconcileBusy ? "กำลังตรวจสอบกับ Stripe..." : "ตรวจสอบผลชำระกับ Stripe (ไม่จ่ายซ้ำ)"}
                              </button>
                              {reconcileMessage && <p role="status" style={{ margin: "10px 0 0", color: "#134e4a", overflowWrap: "anywhere" }}>{reconcileMessage}</p>}
                            </div>
                          )}
                        {["pending", "issue"].includes(order.payment_status) &&
                          !(user.id === QA_MERCHANT_USER_ID && order.order_number === "WF000003" && returnStatus?.includes("Stripe กลับจากหน้าชำระเงินแล้ว")) && (
                          <button disabled={Boolean(busyOrder) || reconcileBusy} onClick={() => void checkout(order)} style={action}>
                            {busyOrder === order.id ? "กำลังเปิด Stripe..." : "ชำระเงินทดสอบด้วย Stripe"}
                          </button>
                        )}
                      </div>
                    ))}
                  </div>
                )}
              </section>
            )}
            <section style={panel}>
              <strong>ข้อจำกัดก่อน E2E</strong>
              <p style={{ color: "#64748b" }}>
                Checkout ต้องมีคำสั่งซื้อที่ถูกต้องและร้านค้า Stripe Connect Test Mode ซึ่งเปิดรับชำระแล้ว
                หน้านี้ไม่สร้างคำสั่งซื้อหรือสร้างร้านจำลองแบบข้ามระบบ
              </p>
            </section>
          </>
        )}
      </div>
    </main>
  );
}
