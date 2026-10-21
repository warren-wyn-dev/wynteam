"use client";
import { useEffect, useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import { bangkokToday } from "@/lib/finance-dates";

type Operations = {
  audit: Array<{ id: number; action: string; target_id: string; created_at: string }>;
  gp_rates: Array<{ id: string; store_id: string | null; rate_bp: number; effective_from: string; reason: string }>;
  stores: Array<{ id: string; name: string }>;
  adjustments: Array<{ id: string; store_id: string; amount_satang: number; reason: string; state: string; proposed_by: string }>;
  reconciliation: Array<{ order_id: string; issue: string; checked_at: string }>;
  refunds: Array<{ id: string; order_id: string; state: string; food_satang: number; delivery_satang: number }>;
  payouts: Array<{ id: string; store_id: string; business_day: string; state: string; amount_satang: number }>;
};
const money = (v: number) => new Intl.NumberFormat("th-TH", { style: "currency", currency: "THB" }).format(v / 100);
export function FinanceOperationsPanel({ userId, canEdit }: { userId: string; canEdit: boolean }) {
  const [client] = useState(createClient);
  const [from, setFrom] = useState(bangkokToday); const [to, setTo] = useState(bangkokToday);
  const [data, setData] = useState<Operations | null>(null); const [version, setVersion] = useState(0);
  const [message, setMessage] = useState(""); const [busy, setBusy] = useState(false);
  const [store, setStore] = useState(""); const [amount, setAmount] = useState(""); const [reason, setReason] = useState("");
  const [gp, setGp] = useState("10"); const [gpStart, setGpStart] = useState("");
  const [orderNumber, setOrderNumber] = useState("");
  const [refundOrder, setRefundOrder] = useState<{ id: string; order_number: string; items: Array<{ id: string; name: string; quantity: number }> } | null>(null);
  const [refundItems, setRefundItems] = useState<Record<string, number>>({});
  const [providerRefundId, setProviderRefundId] = useState("");
  const request = useRef({ fingerprint: "", key: "" });
  const gpRequest = useRef({ fingerprint: "", key: "" });
  const itemRequest = useRef({ fingerprint: "", key: "" });
  useEffect(() => { let live = true; void client.rpc("admin_food_finance_operations", { p_from: from, p_to: to })
    .then(({ data: next, error }) => { if (!live) return; if (error) setMessage("โหลดข้อมูลไม่สำเร็จ กรุณาตรวจสิทธิ์การเงินและช่วงวันที่"); else { setData(next); setMessage(""); } });
    return () => { live = false; };
  }, [client, from, to, version]);
  const propose = async () => { setBusy(true); try {
    if (!/^-?\d+(\.\d{1,2})?$/.test(amount)) throw Error("ระบุจำนวนเงินไม่เกินสองตำแหน่งทศนิยม");
    const amountSatang = Math.round(Number(amount) * 100);
    if (!Number.isSafeInteger(amountSatang) || amountSatang === 0) throw Error("จำนวนเงินไม่ถูกต้อง");
    const fingerprint = JSON.stringify([store, amountSatang, reason.trim()]);
    if (request.current.fingerprint !== fingerprint) request.current = { fingerprint, key: crypto.randomUUID() };
    const { error } = await client.rpc("admin_food_finance_adjust", { p_store_id: store, p_amount_satang: amountSatang, p_reason: reason.trim(), p_request_key: request.current.key });
    if (error) throw Error("เสนอปรับยอดไม่สำเร็จ กรุณาตรวจสิทธิ์และข้อมูล");
    setMessage("เสนอรายการแล้ว ต้องให้แอดมินอีกคนตรวจอนุมัติ"); setVersion((v) => v + 1);
  } catch (e) { setMessage(e instanceof Error ? e.message : "บันทึกไม่สำเร็จ"); } finally { setBusy(false); } };
  const review = async (id: string, approve: boolean) => { setBusy(true); try {
    const { error } = await client.rpc("admin_food_finance_review", { p_id: id, p_approve: approve, p_reason: reason.trim() });
    if (error) throw Error("ตรวจอนุมัติไม่สำเร็จ ผู้ตรวจต้องเป็นคนละคนกับผู้เสนอ และระบุเหตุผล");
    setVersion((v) => v + 1);
  } catch (e) { setMessage(e instanceof Error ? e.message : "ตรวจอนุมัติไม่สำเร็จ"); } finally { setBusy(false); } };
  const setRate = async () => { setBusy(true); try {
    if (!/^\d+(\.\d{1,2})?$/.test(gp) || Number(gp) > 100) throw Error("GP ต้องอยู่ระหว่าง 0 ถึง 100%");
    const rate = Math.round(Number(gp) * 100), start = gpStart ? new Date(gpStart).toISOString() : null;
    const fingerprint = JSON.stringify([store, rate, start, reason.trim()]);
    if (gpRequest.current.fingerprint !== fingerprint) gpRequest.current = { fingerprint, key: crypto.randomUUID() };
    const { error } = await client.rpc("admin_food_finance_gp_rate", { p_store_id: store || null, p_rate_bp: rate, p_effective_from: start, p_reason: reason.trim(), p_request_key: gpRequest.current.key });
    if (error) throw Error("ตั้ง GP ไม่สำเร็จ ตรวจวันเริ่มใช้ เหตุผล และสิทธิ์แอดมิน");
    setMessage("ตั้ง GP แล้ว ออเดอร์เดิมคงอัตราเดิม"); setVersion((v) => v + 1);
  } catch (e) { setMessage(e instanceof Error ? e.message : "ตั้ง GP ไม่สำเร็จ"); } finally { setBusy(false); } };
  const configurePayouts = async () => { setBusy(true); try {
    const { error } = await client.functions.invoke("food-finance-payout", { body: { action: "configure", storeId: store } });
    if (error) throw Error("ตั้งรอบโอนไม่สำเร็จ ต้องตรวจสิทธิ์และบัญชี Stripe ก่อนลองใหม่");
    setMessage("ตั้งรอบโอนแล้ว ตัดยอด 00:00 เริ่มโอนยอดพร้อม 08:00 เวลาไทย"); setVersion((v) => v + 1);
  } catch (e) { setMessage(e instanceof Error ? e.message : "ตั้งรอบโอนไม่สำเร็จ"); } finally { setBusy(false); } };
  const loadOrder = async () => { setBusy(true); try {
    const { data: order, error } = await client.rpc("admin_food_finance_order", { p_order_number: orderNumber.trim() });
    if (error) throw Error("ไม่พบออเดอร์หรือไม่มีสิทธิ์ตรวจคืนเงิน");
    setRefundOrder(order); setRefundItems({});
  } catch (e) { setMessage(e instanceof Error ? e.message : "โหลดออเดอร์ไม่สำเร็จ"); } finally { setBusy(false); } };
  const refundSelected = async () => { if (!refundOrder) return; setBusy(true); try {
    const items = Object.entries(refundItems).filter(([, quantity]) => quantity > 0).map(([item_id, quantity]) => ({ item_id, quantity }));
    const fingerprint = JSON.stringify([refundOrder.id, items, reason.trim()]);
    if (itemRequest.current.fingerprint !== fingerprint) itemRequest.current = { fingerprint, key: crypto.randomUUID() };
    const { error } = await client.rpc("merchant_request_item_refund", { p_order_id: refundOrder.id, p_items: items, p_reason: reason.trim(), p_request_key: itemRequest.current.key });
    if (error) throw Error("ขอคืนไม่สำเร็จ ตรวจจำนวนที่เคยคืนและสถานะออเดอร์");
    setMessage("อนุมัติคำขอแล้ว ระบบจะคืนตามรายการและ GP ที่เกี่ยวข้อง"); setVersion((v) => v + 1);
  } catch (e) { setMessage(e instanceof Error ? e.message : "ขอคืนไม่สำเร็จ"); } finally { setBusy(false); } };
  const retryRefund = async (id: string) => { setBusy(true); try {
    const { error } = await client.rpc("admin_food_finance_retry_refund", { p_id: id, p_refund_id: providerRefundId.trim() || null, p_reason: reason.trim() });
    if (error) throw Error("ส่งตรวจซ้ำไม่สำเร็จ ตรวจสถานะและรหัสคืนเงินจาก Stripe");
    setMessage("ส่งเข้าคิวตรวจซ้ำแล้ว ระบบจะยืนยันรายการกับ Stripe ก่อนดำเนินการ"); setVersion((v) => v + 1);
  } catch (e) { setMessage(e instanceof Error ? e.message : "ส่งตรวจซ้ำไม่สำเร็จ"); } finally { setBusy(false); } };
  return <div className="space-y-6"><div className="flex flex-wrap gap-4"><label>ตั้งแต่<input className="block border p-2" type="date" value={from} onChange={(e) => setFrom(e.target.value)} /></label><label>ถึง<input className="block border p-2" type="date" value={to} onChange={(e) => setTo(e.target.value)} /></label><button type="button" onClick={() => setVersion((v) => v + 1)}>รีเฟรช</button></div>
    <p role="status">{message}</p>
    <section className="space-y-3 rounded-xl border p-4"><h2>เสนอปรับยอด / เหตุผลการตรวจ</h2><p>ยอดอนุมัติยังไม่ใช่หลักฐานว่าโอนสำเร็จ ระบบต้องตรวจยอดพร้อมและผลจากผู้ให้บริการอีกครั้ง</p>
      <label className="block">ร้าน<select className="block border p-2" value={store} onChange={(e) => setStore(e.target.value)}><option value="">เลือกร้าน</option>{data?.stores.map((s) => <option key={s.id} value={s.id}>{s.name}</option>)}</select></label>
      <label className="block">จำนวนเงิน บาท (+ เพิ่ม / − ลด)<input className="block border p-2" inputMode="decimal" value={amount} onChange={(e) => setAmount(e.target.value)} /></label>
      <label className="block">เหตุผล<textarea className="block w-full border p-2" maxLength={500} value={reason} onChange={(e) => setReason(e.target.value)} /></label>
      <button className="rounded border p-2" type="button" disabled={busy || !canEdit || !store || reason.trim().length < 3} onClick={() => void propose()}>ส่งให้ผู้ตรวจอีกคน</button>
    </section>
    <section className="space-y-3 rounded-xl border p-4"><h2>GP และรอบโอน</h2><p>ใช้ร้านและเหตุผลที่เลือกด้านบน หากไม่เลือกร้านจะตั้ง GP กลาง</p>
      <label className="block">GP เปอร์เซ็นต์<input className="block border p-2" inputMode="decimal" value={gp} onChange={(e) => setGp(e.target.value)} /></label>
      <label className="block">เริ่มใช้ เวลาของอุปกรณ์ (เว้นว่าง = ตอนนี้)<input className="block border p-2" type="datetime-local" value={gpStart} onChange={(e) => setGpStart(e.target.value)} /></label>
      <button type="button" disabled={busy || !canEdit || reason.trim().length < 3} onClick={() => void setRate()}>บันทึกอัตรา GP</button>
      <p>เปลี่ยนรอบโอนจะหยุดรอบอัตโนมัติเดิมของ Stripe ก่อนใช้รอบ 08:00 เงินเข้าจริงขึ้นกับธนาคาร</p>
      <button type="button" disabled={busy || !canEdit || !store} onClick={() => void configurePayouts()}>เปิดรอบโอน 08:00 ให้ร้านที่เลือก</button>
    </section>
    <section><h2>รายการปรับยอด</h2>{data?.adjustments.map((a) => <article className="my-2 rounded-xl border p-4" key={a.id}><p>{data.stores.find((s) => s.id === a.store_id)?.name ?? "ร้านค้า"} · {money(a.amount_satang)} · {a.reason}</p><p>{a.state === "pending" ? "รอผู้ตรวจคนที่สอง" : a.state === "approved" ? "อนุมัติแล้ว" : "ปฏิเสธ"}</p>{a.state === "pending" && canEdit && a.proposed_by !== userId ? <div className="flex gap-3"><button disabled={busy || reason.trim().length < 3} onClick={() => void review(a.id, true)}>อนุมัติ</button><button disabled={busy || reason.trim().length < 3} onClick={() => void review(a.id, false)}>ปฏิเสธ</button></div> : null}</article>)}</section>
    <section><h2>ยอดที่ต้องตรวจสอบกับ Stripe</h2>{data?.reconciliation.length === 0 ? <p>ไม่มีรายการผิดปกติที่บันทึกไว้</p> : null}{data?.reconciliation.map((r) => <p key={r.order_id}>{r.order_id} · {r.issue === "awaiting_provider" ? "รอข้อมูลผู้ให้บริการ" : "ยอดไม่ตรง ต้องตรวจสอบ"}</p>)}</section>
    <section className="space-y-3 rounded-xl border p-4"><h2>ตรวจและอนุมัติคืนบางเมนู รวมออเดอร์ส่งแล้ว</h2>
      <label>เลขออเดอร์<input className="block border p-2" placeholder="WF000009" value={orderNumber} onChange={(e) => setOrderNumber(e.target.value)} /></label>
      <button disabled={busy || !canEdit} onClick={() => void loadOrder()}>เปิดรายการเพื่อตรวจสอบ</button>
      {refundOrder?.items?.map((i) => <label className="block" key={i.id}>{i.name}<select className="ml-3 border p-2" value={refundItems[i.id] ?? 0} onChange={(e) => setRefundItems((v) => ({ ...v, [i.id]: Number(e.target.value) }))}>{Array.from({ length: i.quantity + 1 }, (_, n) => <option key={n} value={n}>{n}</option>)}</select></label>)}
      <p>ตรวจหลักฐานและระบุเหตุผลด้านบนก่อนอนุมัติ จำนวนที่คืนไปแล้วจะถูกตรวจซ้ำฝั่งเซิร์ฟเวอร์</p>
      <button disabled={busy || !canEdit || !refundOrder || reason.trim().length < 3 || !Object.values(refundItems).some((n) => n > 0)} onClick={() => void refundSelected()}>ยืนยันผลตรวจและส่งคืนเงิน</button>
    </section>
    <section><h2>คำขอคืนเงินที่ยังไม่จบ</h2><label>รหัสคืนเงินจาก Stripe สำหรับรายการรอตรวจสอบ<input className="block border p-2" value={providerRefundId} placeholder="re_…" onChange={(e) => setProviderRefundId(e.target.value)} /></label>{data?.refunds.map((r) => <div key={r.id}><p>{r.order_id} · {money(r.food_satang + r.delivery_satang)} · {r.state === "needs_review" ? "ต้องตรวจสอบ" : "กำลังดำเนินการ"}</p>{r.state === "needs_review" ? <button disabled={busy || !canEdit || reason.trim().length < 3} onClick={() => void retryRefund(r.id)}>ตรวจแล้ว ส่งประมวลผลซ้ำ</button> : null}</div>)}</section>
    <section><h2>รอบโอนเงิน</h2><p>ตัดยอด 00:00 เริ่มโอนยอดพร้อม 08:00 เวลาไทย</p>{data?.payouts.map((p) => <p key={p.id}>{p.business_day} · {money(p.amount_satang)} · {p.state}</p>)}</section>
    <section><h2>ประวัติ GP</h2>{data?.gp_rates.map((r) => <p key={r.id}>{r.store_id ? data.stores.find((s) => s.id === r.store_id)?.name ?? "ร้านค้า" : "อัตรากลาง"} · {r.rate_bp / 100}% · เริ่ม {new Date(r.effective_from).toLocaleString("th-TH")} · {r.reason}</p>)}</section>
    <section><h2>ประวัติการดำเนินการ ล่าสุด 200 รายการ</h2>{data?.audit.map((a) => <p key={a.id}>{new Date(a.created_at).toLocaleString("th-TH")} · {a.action} · {a.target_id}</p>)}</section>
  </div>;
}
