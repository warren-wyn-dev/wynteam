"use client";

import { useCallback, useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";

type ChatRow = {
  id: string;
  body: string;
  sender_id: string;
  created_at: string;
};

/** Fail-closed: never enable on merchant.wynos.online and never in a normal build.
 * Requires a reviewed isolated staging DB with order-scoped RLS installed.
 */
function chatPreviewEnabled(): boolean {
  if (process.env.NEXT_PUBLIC_ZOKY_CHAT_STAGING !== "true") return false;
  if (typeof window === "undefined") return false;
  const host = window.location.hostname.toLowerCase();
  if (host === "merchant.wynos.online" || host === "wynos.online") return false;
  return host === "localhost" || host.endsWith(".vercel.app") || host.includes("staging");
}

export function ZokyMerchantOrderChat({
  client,
  orderId,
}: {
  client: SupabaseClient;
  orderId: string;
}) {
  const [enabled, setEnabled] = useState(false);
  const [currentUserId, setCurrentUserId] = useState<string | null>(null);
  const [rows, setRows] = useState<ChatRow[]>([]);
  const [draft, setDraft] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => { setEnabled(chatPreviewEnabled()); }, []);

  const refresh = useCallback(async () => {
    if (!chatPreviewEnabled()) return;
    const { data: auth, error: authError } = await client.auth.getUser();
    if (authError || !auth.user?.id) {
      setError("กรุณาเข้าสู่ระบบ Merchant ใหม่");
      return;
    }
    setCurrentUserId(auth.user.id);
    const { data, error: readError } = await client
      .from("food_order_chat_messages")
      .select("id,body,sender_id,created_at")
      .eq("order_id", orderId)
      .order("created_at", { ascending: true })
      .limit(100);
    if (readError) {
      setError("ระบบแชต Staging ยังไม่พร้อมหรือไม่มีสิทธิ์ในออเดอร์นี้");
      return;
    }
    setRows((data ?? []) as ChatRow[]);
    setError("");
  }, [client, orderId]);

  useEffect(() => {
    if (!enabled) return;
    let live = true;
    void refresh();
    const timer = window.setInterval(() => { if (live) void refresh(); }, 15000);
    return () => { live = false; window.clearInterval(timer); };
  }, [enabled, refresh]);

  if (!enabled) return null;

  const send = async () => {
    const message = draft.trim();
    if (!message || message.length > 1200 || busy || !currentUserId) return;
    setBusy(true);
    setError("");
    const { error: sendError } = await client
      .from("food_order_chat_messages")
      .insert({
        order_id: orderId,
        sender_id: currentUserId,
        client_id: crypto.randomUUID(),
        body: message,
      });
    setBusy(false);
    if (sendError) {
      setError("ส่งไม่สำเร็จ โปรดตรวจสอบสิทธิ์และระบบ Staging");
      return;
    }
    setDraft("");
    await refresh();
  };

  return (
    <section className="wm-detail-section" aria-label="แชตลูกค้าสำหรับ Staging">
      <h3>แชตลูกค้า (ทดสอบ)</h3>
      <p>เฉพาะออเดอร์นี้ · ข้อความตัวอักษรเท่านั้น · ยังไม่เปิดใน Production</p>
      <div aria-live="polite" style={{ maxHeight: 260, overflowY: "auto", padding: 8 }}>
        {rows.length === 0 ? <p>ยังไม่มีข้อความ</p> : rows.map((row) => (
          <p key={row.id} style={{
            textAlign: row.sender_id === currentUserId ? "right" : "left",
            overflowWrap: "anywhere",
          }}>
            <small>{row.sender_id === currentUserId ? "ร้านค้า" : "ลูกค้า"}</small>
            <span style={{ display: "block" }}>{row.body}</span>
          </p>
        ))}
      </div>
      <label>
        ส่งข้อความถึงลูกค้า
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value.slice(0, 1200))}
          placeholder="พิมพ์ข้อความเกี่ยวกับออเดอร์นี้"
          maxLength={1200}
          rows={2}
        />
      </label>
      {error ? <p role="alert">{error}</p> : null}
      <button className="wm-primary wm-full" type="button"
        disabled={busy || !currentUserId || !draft.trim()}
        onClick={() => void send()}>
        {busy ? "กำลังส่ง…" : "ส่งข้อความ"}
      </button>
    </section>
  );
}
