"use client";

import { MonitorSmartphone } from "lucide-react";

import { previewMerchantOrderSound } from "@/components/merchant/merchant-order-alert";
import { useMerchantOrderScreen } from "@/lib/merchant-order-screen";

/** On/off card for "หน้าจอรับออเดอร์" (Merchant home and notification settings). */
export function MerchantOrderScreenCard({ onMessage }: { onMessage: (message: string) => void }) {
  const { on, supported, setOn } = useMerchantOrderScreen();

  const toggle = async () => {
    if (on) {
      setOn(false);
      onMessage("ปิดหน้าจอรับออเดอร์แล้ว หน้าจอจะดับตามปกติ");
      return;
    }
    setOn(true);
    // This tap also unlocks sound, so the next order can ring on its own.
    const played = await previewMerchantOrderSound();
    onMessage(played
      ? "เปิดหน้าจอรับออเดอร์แล้ว · วางเครื่องไว้หน้าร้านได้เลย"
      : "เปิดหน้าจอรับออเดอร์แล้ว แต่เปิดเสียงไม่ได้ ตรวจว่ามือถือไม่ได้ปิดเสียงอยู่");
  };

  return (
    <section className={`wm-order-screen-card ${on ? "is-on" : ""}`} aria-label="หน้าจอรับออเดอร์">
      <span className="wm-order-screen-icon"><MonitorSmartphone size={22} /></span>
      <span className="wm-order-screen-copy">
        <strong>หน้าจอรับออเดอร์</strong>
        <small>{supported
          ? "หน้าจอไม่ดับ เสียงดังทุกออเดอร์ · วางเครื่องไว้หน้าร้านแล้วเปิดแอปนี้ค้างไว้"
          : "เครื่องนี้กันหน้าจอดับเองไม่ได้ ให้ตั้งล็อกหน้าจออัตโนมัติเป็น \"ไม่ต้อง\" แล้วเปิดแอปนี้ค้างไว้"}</small>
      </span>
      <button
        className={`wm-switch-button ${on ? "is-on" : ""}`}
        type="button"
        role="switch"
        aria-checked={on}
        aria-label="หน้าจอรับออเดอร์"
        onClick={() => void toggle()}
      >
        <span className={`wm-switch ${on ? "is-on" : ""}`}><i /></span>
      </button>
    </section>
  );
}

/** Thin bar while the mode is on: is the screen kept awake, is sound ready. */
export function MerchantOrderScreenBar({ soundReady }: { soundReady: boolean }) {
  const { on, awake, supported, setOn } = useMerchantOrderScreen();
  if (!on) return null;
  const status = !soundReady
    ? "แตะหน้าจอหนึ่งครั้งเพื่อเปิดเสียง"
    : supported && !awake
      ? "หน้าจออาจดับ · แตะเพื่อกันหน้าจอดับอีกครั้ง"
      : "พร้อมรับออเดอร์ · หน้าจอไม่ดับ เสียงพร้อม";
  const ready = soundReady && (!supported || awake);
  return (
    <div className={`wm-order-screen-bar ${ready ? "is-ready" : "is-warning"}`} role="status">
      <i aria-hidden="true" />
      <span>{status}</span>
      <button type="button" onClick={() => setOn(false)}>ปิด</button>
    </div>
  );
}
