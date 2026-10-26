"use client";
import { useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { FoodOrder, FoodStore } from "@/lib/food-merchant";
import { setStoreFulfillment, resolveCancelRequest, uploadRefundSlip, markStoreRefunded, fulfillmentError } from "@/lib/food-fulfillment-merchant";

export function FulfillmentTags({ order }: { order: FoodOrder }) {
  return <span><span className="wm-status">{order.fulfillment_type === "pickup" ? "รับเอง" : "ส่งเอง"}</span>{order.payment_method === "cod" ? <span className="wm-status">เก็บเงินปลายทาง</span> : null}{order.cancel_requested_at ? <span className="wm-status">ลูกค้าขอยกเลิก</span> : null}{order.refund_status === "pending" ? <span className="wm-status">ค้างคืนเงิน</span> : null}</span>;
}
export function MerchantFulfillmentSettings({ client, store, onSaved }: { client: SupabaseClient; store: FoodStore; onSaved: () => void }) {
  const [pickup, setPickup] = useState(store.pickup_enabled === true);
  const [delivery, setDelivery] = useState(store.delivery_enabled !== false);
  const [cod, setCod] = useState(store.cod_enabled === true);
  const [prep, setPrep] = useState(String(store.prep_minutes ?? 15));
  const [busy, setBusy] = useState(false), [error, setError] = useState("");
  const save = async () => {
    setBusy(true); setError("");
    try { await setStoreFulfillment(client, store.id, { pickup, delivery, cod: delivery && cod, prepMinutes: Number(prep) }); onSaved(); }
    catch (e) { setError(e instanceof Error ? e.message : fulfillmentError(e)); }
    finally { setBusy(false); }
  };
  return <section className="wm-settings-category"><h3>รูปแบบรับอาหาร</h3><fieldset disabled={busy}>
    <label><input type="checkbox" checked={delivery} onChange={e => { setDelivery(e.target.checked); if (!e.target.checked) setCod(false); }} />ร้านจัดส่งเอง</label>
    <label><input type="checkbox" checked={pickup} onChange={e => setPickup(e.target.checked)} />รับเองที่ร้าน</label>
    <label><input type="checkbox" checked={cod} disabled={!delivery} onChange={e => setCod(e.target.checked)} />เก็บเงินปลายทาง</label>
    <small>ใช้ได้เฉพาะร้านจัดส่งเอง</small>
    <label>เวลาเตรียมอาหาร (นาที)<input type="number" min="5" max="120" step="1" value={prep} onChange={e => setPrep(e.target.value)} /></label>
    <button type="button" className="wm-primary" onClick={() => void save()}>บันทึกรูปแบบรับอาหาร</button>
  </fieldset>{error ? <p role="alert">{error}</p> : null}</section>;
}
export function MerchantCancelRefund({ client, store, order, locked, onReload }: { client: SupabaseClient; store: FoodStore; order: FoodOrder; locked: boolean; onReload: () => void }) {
  const [applied, setApplied] = useState(false);
  const [busy, setBusy] = useState(false), [refund, setRefund] = useState(false), [confirmed, setConfirmed] = useState(false);
  const [file, setFile] = useState<File | null>(null), [uploaded, setUploaded] = useState<string | null>(null), [error, setError] = useState("");
  const run = async (action: () => Promise<void>) => {
    setBusy(true); setError("");
    try { await action(); setApplied(true); onReload(); }
    catch(e) { setError(e instanceof Error ? e.message : fulfillmentError(e)); }
    finally { setBusy(false); }
  };
  return <section className="wm-detail-section"><fieldset disabled={locked || busy || applied}>
    {order.cancel_requested_at ? <div role="status"><h3>ลูกค้าขอยกเลิก</h3><p>{order.cancel_request_note}</p>
      <label><input type="checkbox" checked={refund} disabled={order.payment_status !== "paid"} onChange={e => setRefund(e.target.checked)} />คืนเงิน</label>
      <p>ร้านเป็นผู้ตัดสินใจเรื่องคืนเงิน</p>
      <button type="button" onClick={() => { if (window.confirm("อนุมัติคำขอยกเลิก")) void run(() => resolveCancelRequest(client, order.id, true, refund)); }}>อนุมัติคำขอยกเลิก</button>
      <button type="button" onClick={() => { if (window.confirm("ปฏิเสธคำขอยกเลิก")) void run(() => resolveCancelRequest(client, order.id, false, false)); }}>ปฏิเสธคำขอยกเลิก</button>
    </div> : null}
    {order.refund_status === "pending" && order.payment_provider !== "stripe" && order.payment_method !== "cod" ? <div>
      <h3>โอนคืนแล้ว + แนบสลิป</h3><p>โอนเงินคืนลูกค้าด้วยแอปธนาคารก่อนแนบสลิป</p>
      <label>แนบสลิปคืนเงิน<input type="file" accept="image/jpeg,image/png,image/webp" onChange={e => { setFile(e.target.files?.[0] ?? null); setUploaded(null); }} /></label>
      <label><input type="checkbox" checked={confirmed} onChange={e => setConfirmed(e.target.checked)} />โอนเงินคืนครบแล้ว</label>
      <button className="wm-primary" type="button" disabled={!file || !confirmed} onClick={() => void run(async () => {
        const path = uploaded ?? await uploadRefundSlip(client, store.id, order.id, file!);
        setUploaded(path);
        await markStoreRefunded(client, store.id, order.id, path);
      })}>ยืนยันคืนเงิน</button>
    </div> : null}
  </fieldset>{error ? <p role="alert">{error}</p> : null}</section>;
}
