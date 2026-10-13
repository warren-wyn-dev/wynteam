"use client";

import type { SupabaseClient } from "@supabase/supabase-js";
import { useEffect, useRef, useState } from "react";
import type { FoodStore } from "@/lib/food-merchant";

export type MerchantBusyMode = "off" | "prep" | "pause";
type BusyStore = Pick<FoodStore, "id" | "prep_time_min_minutes" | "prep_time_max_minutes">
  & { busy_mode?: MerchantBusyMode };
type BusyCapabilities = { enabled: boolean; canManageStore: boolean };
type BusyDraft = { mode: MerchantBusyMode; prepMin: string; prepMax: string; pauseUntil: string };
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const MODES: Array<{ mode: MerchantBusyMode; label: string }> = [
  { mode: "off", label: "ปิด Busy Mode" },
  { mode: "prep", label: "เพิ่มเวลาเตรียม" },
  { mode: "pause", label: "พักรับออเดอร์" },
];

export async function fetchMerchantBusyCapabilities(client: SupabaseClient, storeId: string): Promise<BusyCapabilities> {
  if (!UUID.test(storeId)) return { enabled: false, canManageStore: false };
  try {
    const { data, error } = await client.rpc("food_order_operations_features", { p_store_id: storeId });
    return { enabled: !error && data?.busy_mode === true, canManageStore: !error && data?.can_manage_store === true };
  } catch {
    return { enabled: false, canManageStore: false };
  }
}

export function buildMerchantBusyParams(store: BusyStore, draft: BusyDraft, now = Date.now()) {
  if (!UUID.test(store.id) || !MODES.some(({ mode }) => mode === draft.mode)) throw new Error("ข้อมูลโหมดร้านไม่ถูกต้อง");
  let prepMin: number | null = null;
  let prepMax: number | null = null;
  let pauseUntil: string | null = null;
  if (draft.mode === "prep") {
    if (!/^[1-9][0-9]{0,2}$/.test(draft.prepMin) || !/^[1-9][0-9]{0,2}$/.test(draft.prepMax)) {
      throw new Error("ระบุเวลาเตรียมเป็นจำนวนเต็มตั้งแต่ 1 ถึง 240 นาที");
    }
    prepMin = Number(draft.prepMin);
    prepMax = Number(draft.prepMax);
    if (prepMin > 240 || prepMax > 240 || prepMax < prepMin) throw new Error("ช่วงเวลาเตรียมไม่ถูกต้อง");
    if (prepMin < Number(store.prep_time_min_minutes) || prepMax < Number(store.prep_time_max_minutes)) {
      throw new Error("Busy Mode ต้องใช้เวลาเตรียมไม่น้อยกว่าค่าปัจจุบัน");
    }
  }
  if (draft.mode === "pause") {
    const parts = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(draft.pauseUntil);
    const deadline = new Date(draft.pauseUntil);
    if (!parts || !Number.isFinite(deadline.getTime()) || deadline.getTime() <= now
      || deadline.getFullYear() !== Number(parts[1]) || deadline.getMonth() + 1 !== Number(parts[2])
      || deadline.getDate() !== Number(parts[3]) || deadline.getHours() !== Number(parts[4])
      || deadline.getMinutes() !== Number(parts[5])) {
      throw new Error("เลือกวันและเวลาสิ้นสุดการพักที่อยู่ในอนาคต");
    }
    pauseUntil = deadline.toISOString();
  }
  return { p_store_id: store.id, p_mode: draft.mode, p_prep_min: prepMin, p_prep_max: prepMax, p_pause_until: pauseUntil };
}

export async function saveMerchantBusyMode(client: SupabaseClient, store: BusyStore, draft: BusyDraft, now = Date.now()) {
  const params = buildMerchantBusyParams(store, draft, now);
  const capabilities = await fetchMerchantBusyCapabilities(client, store.id);
  if (!capabilities.enabled || !capabilities.canManageStore) throw new Error("ยังไม่เปิด Busy Mode หรือไม่มีสิทธิ์จัดการร้าน");
  const { error } = await client.rpc("merchant_set_food_busy_mode", params);
  if (error) throw new Error("บันทึก Busy Mode ไม่สำเร็จ กรุณาโหลดข้อมูลร้านล่าสุดแล้วลองใหม่");
}

export function MerchantBusyModePanel({ client, store, capabilities, onReload, onMessage }: {
  client: SupabaseClient;
  store: BusyStore;
  capabilities: BusyCapabilities;
  onReload: () => Promise<void> | void;
  onMessage?: (message: string) => void;
}) {
  const [mode, setMode] = useState<MerchantBusyMode>(store.busy_mode ?? "off");
  const [prepMin, setPrepMin] = useState(store.prep_time_min_minutes == null ? "" : String(store.prep_time_min_minutes));
  const [prepMax, setPrepMax] = useState(store.prep_time_max_minutes == null ? "" : String(store.prep_time_max_minutes));
  const [pauseUntil, setPauseUntil] = useState("");
  const [confirmed, setConfirmed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const inFlight = useRef(false);
  if (!capabilities.enabled || !capabilities.canManageStore) return null;

  const submit = async () => {
    if (inFlight.current || !confirmed) return;
    inFlight.current = true;
    setBusy(true);
    setMessage("");
    try {
      await saveMerchantBusyMode(client, store, { mode, prepMin, prepMax, pauseUntil });
      const success = "บันทึก Busy Mode แล้ว";
      setMessage(success);
      onMessage?.(success);
      setConfirmed(false);
      await onReload();
    } catch (error) {
      setMessage(error instanceof Error ? error.message : "บันทึก Busy Mode ไม่สำเร็จ");
    } finally {
      inFlight.current = false;
      setBusy(false);
    }
  };

  return (
    <section className="wm-scheduled-settings" aria-label="Busy Mode">
      <strong>Busy Mode · ร้านกำลังยุ่ง</strong>
      <small>ลูกค้าจะเห็นเวลาเตรียมหรือสถานะพักรับออเดอร์จากข้อมูลร้านล่าสุด</small>
      <div className="wm-form" role="radiogroup" aria-label="โหมดรับออเดอร์ช่วงร้านยุ่ง">
        {MODES.map((option) => (
          <label className="wm-check-row" key={option.mode}>
            <input type="radio" name={`busy-mode-${store.id}`} value={option.mode} checked={mode === option.mode} disabled={busy}
              onChange={() => { setMode(option.mode); setConfirmed(false); }} />
            <span>{option.label}</span>
          </label>
        ))}
      </div>
      {mode === "prep" ? (
        <div className="wm-form-grid">
          <label>เตรียมอย่างน้อย (นาที)<input type="number" inputMode="numeric" min={1} max={240} step={1} value={prepMin} disabled={busy}
            onChange={(event) => { setPrepMin(event.target.value); setConfirmed(false); }} /></label>
          <label>เตรียมไม่เกิน (นาที)<input type="number" inputMode="numeric" min={1} max={240} step={1} value={prepMax} disabled={busy}
            onChange={(event) => { setPrepMax(event.target.value); setConfirmed(false); }} /></label>
        </div>
      ) : null}
      {mode === "pause" ? (
        <label>พักรับออเดอร์ถึง (เวลาท้องถิ่นของเครื่อง)<input type="datetime-local" value={pauseUntil} disabled={busy}
          onChange={(event) => { setPauseUntil(event.target.value); setConfirmed(false); }} /></label>
      ) : null}
      <small>ปิด Busy Mode จะยกเลิกเฉพาะการพักจากโหมดนี้ เวลาเตรียมจะคงค่าปัจจุบัน และไม่ย้อนกลับอัตโนมัติ</small>
      <label className="wm-check-row">
        <input type="checkbox" checked={confirmed} disabled={busy} onChange={(event) => setConfirmed(event.target.checked)} />
        <span>ยืนยันโหมดและค่าที่เลือกก่อนบันทึก</span>
      </label>
      {message ? <p role="status" aria-live="polite">{message}</p> : null}
      <button type="button" className="wm-primary" disabled={busy || !confirmed} onClick={() => void submit()}>
        {busy ? "กำลังบันทึก…" : "บันทึก Busy Mode"}
      </button>
    </section>
  );
}

export function MerchantBusyMode(props: {
  client: SupabaseClient;
  store: BusyStore;
  onReload: () => Promise<void> | void;
  onMessage?: (message: string) => void;
}) {
  const [state, setState] = useState({ storeId: props.store.id, enabled: false, canManageStore: false });
  useEffect(() => {
    let live = true;
    void fetchMerchantBusyCapabilities(props.client, props.store.id).then((capabilities) => {
      if (live) setState({ storeId: props.store.id, ...capabilities });
    });
    return () => { live = false; };
  }, [props.client, props.store.id]);
  const capabilities = state.storeId === props.store.id ? state : { enabled: false, canManageStore: false };
  return <MerchantBusyModePanel key={props.store.id} {...props} capabilities={capabilities} />;
}
