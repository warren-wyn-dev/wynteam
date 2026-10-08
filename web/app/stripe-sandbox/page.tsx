"use client";

import { useCallback, useEffect, useState, type CSSProperties } from "react";
import type { User } from "@supabase/supabase-js";

import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const SANDBOX_URL = "https://pcatuxtenluqzjzzwsvl.supabase.co";
const ENABLED =
  process.env.NEXT_PUBLIC_WYNOS_STRIPE_SANDBOX === "true" &&
  process.env.NEXT_PUBLIC_SUPABASE_URL === SANDBOX_URL;

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
  const [returnStatus, setReturnStatus] = useState<string | null>(null);

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
      setReturnStatus("Stripe กลับจากหน้าชำระเงินแล้ว โปรดรอ Webhook ยืนยันและกดรีเฟรชสถานะ");
    } else if (stripe === "cancelled") {
      setReturnStatus("คุณยกเลิกการชำระเงินทดสอบแล้ว");
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
      if (error) throw error;
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
            <p>โปรเจกต์นี้ต้องตั้ง NEXT_PUBLIC_WYNOS_STRIPE_SANDBOX=true และชี้ไปยัง Supabase Sandbox เท่านั้น</p>
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
                        {["pending", "issue"].includes(order.payment_status) && (
                          <button disabled={Boolean(busyOrder)} onClick={() => void checkout(order)} style={action}>
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
