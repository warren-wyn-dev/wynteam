"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useRef, useState } from "react";

import {
  MODIFICATION_EXECUTION_NOTICE, modificationStatusLabel, respondOrderModification, useOrderModifications,
} from "@/lib/order-modification";

export function FoodOrderModification({ client, orderId, onReload, onMessage }: {
  client: SupabaseClient;
  orderId: string;
  onReload?: () => void;
  onMessage?: (message: string) => void;
}) {
  const { enabled, requests, error, reload } = useOrderModifications(client, orderId);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const inFlight = useRef(false);

  const respond = async (requestId: string, accept: boolean) => {
    if (inFlight.current) return;
    inFlight.current = true;
    setBusy(true);
    setMessage("");
    try {
      const status = await respondOrderModification(client, requestId, accept);
      const result = modificationStatusLabel(status);
      setMessage(result);
      onMessage?.(result);
      await reload();
      onReload?.();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "บันทึกคำตอบไม่สำเร็จ");
      await reload();
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  };

  if (!enabled && !error) return null;
  if (!requests.length && !error) return null;

  return (
    <section className="fx-order-block" aria-label="คำขอแก้ไขรายการอาหาร">
      <div className="fx-section-head"><h2>คำขอแก้ไขรายการอาหาร</h2></div>
      {error ? <p role="alert">{error}</p> : null}
      {message ? <p role="status" aria-live="polite">{message}</p> : null}
      {error ? <button type="button" className="fx-btn fx-btn--outline" onClick={() => void reload()}>โหลดคำขออีกครั้ง</button> : null}
      {requests.map((request) => (
        <article key={request.id}>
          <p><strong>{modificationStatusLabel(request.status)}</strong></p>
          <p>เหตุผลจากร้าน: {request.reason}</p>
          <ul>
            {request.proposed_items.map((item) => (
              <li key={item.order_item_id}>
                {item.item_name}: {item.quantity === 0 ? `ขอนำออก (เดิม ${item.original_quantity})`
                  : `ขอลดจาก ${item.original_quantity} เหลือ ${item.quantity}`}
              </li>
            ))}
          </ul>
          <p className="fx-note fx-note--info">{MODIFICATION_EXECUTION_NOTICE}</p>
          {enabled && request.status === "pending_customer" ? (
            <div className="fx-slip-actions">
              <button className="fx-btn fx-btn--primary fx-btn--block" type="button" disabled={busy} onClick={() => void respond(request.id, true)}>
                {busy ? "กำลังบันทึก…" : "ยินยอมให้ร้านดำเนินการตามคำขอ"}
              </button>
              <button className="fx-btn fx-btn--outline fx-btn--block" type="button" disabled={busy} onClick={() => void respond(request.id, false)}>
                ไม่ยินยอม ใช้รายการเดิม
              </button>
            </div>
          ) : null}
        </article>
      ))}
    </section>
  );
}
