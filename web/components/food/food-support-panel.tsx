"use client";

import { useState, useTransition } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { useIsDeveloperAccount } from "@/lib/use-is-developer-account";
import {
  createFoodSupportCase, foodSupportErrorCopy, loadFoodSupportCase, loadFoodSupportCases,
  replyFoodSupportCase, type FoodSupportCase, type FoodSupportDetail, type FoodSupportStatus, type SupportOrder,
} from "@/lib/food-support";

const statusLabels: Record<FoodSupportStatus, string> = {
  open: "รอรับเรื่อง", in_progress: "กำลังตรวจสอบ", waiting_customer: "รอข้อมูลจากคุณ", resolved: "ปิดเคสแล้ว", appealed: "กำลังทบทวนอุทธรณ์",
};

/** New consumer capability follows the existing developer-first rollout policy. */
export function FoodSupportEntry({ client, userId, orders }: { client: SupabaseClient; userId: string; orders: SupportOrder[] }) {
  const enabled = useIsDeveloperAccount(client, userId);
  return enabled ? <FoodSupportPanel key={userId} client={client} orders={orders} /> : null;
}

/** Mount with key={signedInUserId}; keep customer case state isolated on account switches. */
export function FoodSupportPanel({ client, orders, initialOrderId = "" }: {
  client: SupabaseClient; orders: SupportOrder[]; initialOrderId?: string;
}) {
  const [opened, setOpened] = useState(false);
  const [loaded, setLoaded] = useState(false);
  const [items, setItems] = useState<FoodSupportCase[]>([]);
  const [detail, setDetail] = useState<FoodSupportDetail | null>(null);
  const [orderId, setOrderId] = useState(initialOrderId || orders[0]?.id || "");
  const [kind, setKind] = useState("order");
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");
  const [evidenceItemId, setEvidenceItemId] = useState("");
  const [compensationRequested, setCompensationRequested] = useState(false);
  const [reply, setReply] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [busy, startTransition] = useTransition();
  const order = orders.find(item => item.id === orderId);
  function showError(error: unknown) { setError(foodSupportErrorCopy(error)); }
  function refresh() {
    setError(""); setSuccess("");
    startTransition(async () => {
      try { setItems(await loadFoodSupportCases(client)); setLoaded(true); if (detail) setDetail(await loadFoodSupportCase(client, detail.id)); }
      catch (error) { setLoaded(false); showError(error); }
    });
  }
  function select(id: string) {
    setError(""); setSuccess(""); setDetail(null); setReply("");
    startTransition(async () => {
      try { setDetail(await loadFoodSupportCase(client, id)); }
      catch (error) { showError(error); }
    });
  }
  function storeDetail(updated: FoodSupportDetail) {
    setLoaded(true);
    setDetail(updated);
    setItems(previous => [updated, ...previous.filter(item => item.id !== updated.id)].slice(0, 50));
  }
  function submit() {
    if (busy || !order || subject.trim().length < 5 || body.trim().length < 5) return;
    setError(""); setSuccess("");
    startTransition(async () => {
      try {
        const created = await createFoodSupportCase(client, { orderId: order.id, kind, subject, body, evidenceItemId, compensationRequested });
        storeDetail(created); setSubject(""); setBody(""); setEvidenceItemId(""); setCompensationRequested(false);
        setSuccess("ส่งเรื่องแล้ว ติดตามคำตอบได้ที่เคสของฉัน");
      } catch (error) { showError(error); }
    });
  }
  function sendReply(appeal: boolean) {
    if (!detail || busy || reply.trim().length < 5) return;
    const current = detail; setError(""); setSuccess("");
    startTransition(async () => {
      try {
        storeDetail(await replyFoodSupportCase(client, current, reply, appeal)); setReply("");
        setSuccess(appeal ? "ส่งคำอุทธรณ์ให้เจ้าหน้าที่ทบทวนแล้ว" : "ส่งข้อมูลเพิ่มเติมแล้ว");
      } catch (error) { showError(error); }
    });
  }
  return <section className="food-support-panel" aria-label="ศูนย์ช่วยเหลือออเดอร์" style={{ padding: 16, border: "1px solid var(--line, #e5e7eb)", borderRadius: 16, background: "var(--surface, #fff)", color: "var(--text, #171717)" }}>
    <button type="button" disabled={busy} aria-expanded={opened} onClick={() => {
      setOpened(!opened); if (!opened) refresh();
    }} style={{ minHeight: 44, fontWeight: 700, width: "100%", textAlign: "left" }}>ช่วยเหลือและติดตามปัญหาออเดอร์ {opened ? "▴" : "▾"}</button>
    {opened && <div style={{ display: "grid", gap: 16, marginTop: 12 }}>
      <p style={{ fontSize: 13 }}>แจ้งปัญหาผูกกับออเดอร์ของคุณ เจ้าหน้าที่จะตรวจสอบก่อนดำเนินการ ไม่ต้องใส่เบอร์โทร อีเมล รหัสผ่าน หรือข้อมูลบัตร</p>
      {orders.length ? <form onSubmit={event => { event.preventDefault(); submit(); }} style={{ display: "grid", gap: 12 }}>
        <h3 style={{ fontWeight: 700 }}>แจ้งปัญหาใหม่</h3>
        <label>ออเดอร์<select value={orderId} disabled={busy} onChange={event => { setOrderId(event.target.value); setEvidenceItemId(""); }} style={inputStyle} required>
          {!order && <option value="">เลือกออเดอร์</option>}{orders.map(item => <option key={item.id} value={item.id}>{item.order_number}</option>)}
        </select></label>
        <label>เรื่องที่ต้องการความช่วยเหลือ<select value={kind} disabled={busy} onChange={event => setKind(event.target.value)} style={inputStyle}>
          <option value="order">ปัญหาออเดอร์</option><option value="payment">การชำระเงิน</option><option value="review">รายงานปัญหารีวิว</option><option value="safety">ความปลอดภัย / สงสัยทุจริต</option><option value="other">อื่น ๆ</option>
        </select></label>
        <label>หัวข้อ (5–120 ตัวอักษร)<input value={subject} onChange={event => setSubject(event.target.value)} minLength={5} maxLength={120} required disabled={busy} style={inputStyle} /></label>
        <label>รายละเอียด (5–2,000 ตัวอักษร)<textarea value={body} onChange={event => setBody(event.target.value)} rows={3} minLength={5} maxLength={2000} required disabled={busy} style={inputStyle} /></label>
        <label>อ้างอิงรายการอาหาร<select value={evidenceItemId} onChange={event => setEvidenceItemId(event.target.value)} disabled={busy} style={inputStyle}>
          <option value="">ไม่ระบุ</option>{order?.food_order_items?.map(item => <option data-i18n-skip key={item.id} value={item.id}>{item.item_name}</option>)}
        </select></label>
        <label style={{ display: "flex", gap: 8, alignItems: "center", minHeight: 44 }}><input type="checkbox" checked={compensationRequested} onChange={event => setCompensationRequested(event.target.checked)} disabled={busy} />ขอให้เจ้าหน้าที่พิจารณาชดเชย</label>
        <p style={{ fontSize: 12 }}>คำขอชดเชยรอการตรวจสอบ ไม่ใช่การอนุมัติคืนเงินหรือโอนเงิน</p>
        <button type="submit" disabled={busy || !order || subject.trim().length < 5 || body.trim().length < 5} style={buttonStyle}>{busy ? "กำลังส่ง…" : "ส่งเรื่องให้เจ้าหน้าที่"}</button>
      </form> : <p>ยังไม่มีออเดอร์สำหรับแจ้งปัญหา</p>}
      <div style={{ display: "grid", gap: 10 }}><h3 style={{ fontWeight: 700 }}>เคสของฉัน (ล่าสุด 50 รายการ)</h3>
        <button disabled={busy} type="button" onClick={refresh} style={buttonStyle}>โหลดข้อมูลล่าสุด</button>
        {!items.length && <p>{busy ? "กำลังโหลดเคส…" : loaded ? "ยังไม่มีเคส" : "ยังโหลดเคสไม่สำเร็จ กรุณาลองใหม่"}</p>}
        {items.map(item => <button type="button" disabled={busy} onClick={() => select(item.id)} key={item.id} style={{ ...buttonStyle, textAlign: "left" }} aria-pressed={detail?.id === item.id}>
          <strong data-i18n-skip style={{ display: "block", overflowWrap: "anywhere" }}>{item.subject}</strong><span style={{ fontSize: 12 }}>{item.order_number} · {statusLabels[item.status]}</span>
        </button>)}
      </div>
      {detail && <article style={{ borderTop: "1px solid var(--line, #e5e7eb)", paddingTop: 12, display: "grid", gap: 12 }}>
        <h3 data-i18n-skip style={{ fontWeight: 700, overflowWrap: "anywhere" }}>{detail.subject}</h3><p>{statusLabels[detail.status]} · {detail.order_number}</p>
        {detail.evidence_item_name && <p>รายการอาหารที่อ้างอิง: <span data-i18n-skip>{detail.evidence_item_name}</span></p>}
        <ol aria-label="บทสนทนากับเจ้าหน้าที่" style={{ display: "grid", gap: 10 }}>
          {detail.messages.map(message => <li key={message.id} style={{ padding: 12, border: "1px solid var(--line, #e5e7eb)", borderRadius: 12 }}>
            <strong style={{ fontSize: 12 }}>{message.actor_role === "support" ? "เจ้าหน้าที่" : "คุณ"}</strong><p data-i18n-skip style={{ whiteSpace: "pre-wrap", overflowWrap: "anywhere" }}>{message.body}</p>
          </li>)}
        </ol>
        {(detail.status !== "resolved" || detail.appeal_count === 0) ? <form onSubmit={event => { event.preventDefault(); sendReply(detail.status === "resolved"); }} style={{ display: "grid", gap: 10 }}>
          <label>{detail.status === "resolved" ? "เหตุผลขออุทธรณ์ (ได้หนึ่งครั้ง)" : "ข้อมูลเพิ่มเติมถึงเจ้าหน้าที่"}<textarea minLength={5} maxLength={2000} rows={3} required value={reply} onChange={event => setReply(event.target.value)} disabled={busy} style={inputStyle} /></label>
          <button type="submit" disabled={busy || reply.trim().length < 5} style={buttonStyle}>{busy ? "กำลังส่ง…" : detail.status === "resolved" ? "ส่งคำอุทธรณ์ให้เจ้าหน้าที่" : "ส่งข้อมูลเพิ่มเติม"}</button>
        </form> : <p>เจ้าหน้าที่ทบทวนคำอุทธรณ์และปิดเคสแล้ว</p>}
      </article>}
      {error && <p role="alert" style={{ color: "#b91c1c" }}>{error}</p>}
      {success && <p role="status">{success}</p>}
    </div>}
  </section>;
}
const inputStyle = { display: "block", width: "100%", minHeight: 44, marginTop: 6, padding: 10, border: "1px solid var(--line, #d1d5db)", borderRadius: 10, background: "var(--surface, #fff)", color: "inherit" };
const buttonStyle = { minHeight: 44, padding: "10px 14px", border: "1px solid var(--line, #d1d5db)", borderRadius: 10, color: "inherit", background: "var(--surface, #fff)" };
