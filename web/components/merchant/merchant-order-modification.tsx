"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useRef, useState } from "react";

import type { FoodOrder } from "@/lib/food-merchant";
import {
  buildModificationItems, MODIFICATION_EXECUTION_NOTICE, modificationStatusLabel,
  proposeOrderModification, useOrderModifications,
} from "@/lib/order-modification";

export function MerchantOrderModification({ client, order, canManageOrders = false, onReload, onMessage }: {
  client: SupabaseClient;
  order: FoodOrder;
  canManageOrders?: boolean;
  onReload?: () => void;
  onMessage?: (message: string) => void;
}) {
  const { enabled, canManageOrders: authorized, requests, error, reload } = useOrderModifications(client, order.id, order.store_id);
  const [quantities, setQuantities] = useState<Record<string, string>>({});
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const inFlight = useRef(false);
  const retry = useRef<{ payload: string; key: string } | null>(null);
  const items = order.food_order_items ?? [];
  const activeRequest = requests.some((request) => request.status === "pending_customer" || request.status === "accepted_pending_execution");
  const eligible = canManageOrders && authorized && Boolean(order.buyer_id)
    && (order.status === "pending_acceptance" || order.status === "preparing");
  const changed = items.some((item) => (quantities[item.id] ?? String(item.quantity)) !== String(item.quantity));

  const submit = async () => {
    if (inFlight.current || !enabled || !eligible || activeRequest || error) return;
    inFlight.current = true;
    setBusy(true);
    setMessage("");
    try {
      const proposalItems = buildModificationItems(items, quantities);
      const payload = JSON.stringify({ orderId: order.id, reason: reason.trim(), items: proposalItems });
      if (!retry.current || retry.current.payload !== payload) {
        retry.current = { payload, key: crypto.randomUUID() };
      }
      await proposeOrderModification(client, { orderId: order.id, storeId: order.store_id, requestKey: retry.current.key,
        reason, items: proposalItems });
      const result = "ส่งคำขอแล้ว รอลูกค้ายืนยัน รายการและยอดเงินยังไม่เปลี่ยน";
      setMessage(result);
      onMessage?.(result);
      await reload();
      onReload?.();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "ส่งคำขอไม่สำเร็จ");
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  };

  if (!enabled && !error) return null;

  return (
    <section className="wm-detail-section" aria-label="คำขอแก้ไขรายการอาหาร">
      <h3>คำขอแก้ไขรายการอาหาร</h3>
      <p>{MODIFICATION_EXECUTION_NOTICE}</p>
      {error ? <p role="alert">{error}</p> : null}
      {message ? <p role="status" aria-live="polite">{message}</p> : null}
      {error ? <button type="button" className="wm-secondary" onClick={() => void reload()}>โหลดคำขออีกครั้ง</button> : null}
      {requests.map((request) => (
        <article key={request.id}>
          <strong>{modificationStatusLabel(request.status)}</strong>
          <p>{request.reason}</p>
          <ul>{request.proposed_items.map((item) => (
            <li key={item.order_item_id}>{item.item_name}: {item.quantity === 0 ? "ขอนำรายการออก"
              : `ขอลดจาก ${item.original_quantity} เหลือ ${item.quantity}`}</li>
          ))}</ul>
        </article>
      ))}
      {enabled && eligible && !activeRequest && !error ? (
        <form className="wm-form" onSubmit={(event) => { event.preventDefault(); void submit(); }}>
          <div className="wm-form" role="group" aria-label="เสนอการลดจำนวนหรือนำรายการออก">
            {items.map((item) => (
              <label key={item.id}>
                {item.item_name} · จำนวนเดิม {item.quantity}
                <input type="number" inputMode="numeric" min={0} max={item.quantity} step={1} disabled={busy}
                  value={quantities[item.id] ?? String(item.quantity)}
                  onChange={(event) => setQuantities((current) => ({ ...current, [item.id]: event.target.value }))} />
                <small>ระบุ 0 เพื่อขอนำรายการออก</small>
              </label>
            ))}
          </div>
          <label>
            เหตุผลที่ต้องแก้ไข
            <textarea required maxLength={800} value={reason} disabled={busy}
              placeholder="เช่น วัตถุดิบหมด ขอให้ลูกค้ายืนยันก่อนเปลี่ยนรายการ"
              onChange={(event) => setReason(event.target.value)} />
          </label>
          <button className="wm-secondary" type="button" disabled>เปลี่ยนเป็นเมนูอื่น · ยังไม่พร้อมใช้งาน</button>
          <small>ยังปิดการเปลี่ยนเมนูและการนำคำขอไปใช้ จนกว่าระบบคิดราคาและการชำระเงินจะรองรับ</small>
          <button className="wm-primary" type="submit" disabled={busy || !reason.trim() || !changed}>
            {busy ? "กำลังส่งคำขอ…" : "ส่งคำขอให้ลูกค้ายืนยัน"}
          </button>
        </form>
      ) : null}
    </section>
  );
}
