"use client";

import { useMemo, useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { createClient } from "@/lib/supabase/client";
import type { MerchantDeliveryStore } from "@/lib/admin-merchant-delivery";

type SettingKey = "delivery_fee" | "delivery_radius_km" | "delivery_base_km" | "delivery_fee_per_km";
const KEYS: SettingKey[] = ["delivery_fee", "delivery_radius_km", "delivery_base_km", "delivery_fee_per_km"];
const fields: {key: SettingKey; label: string; suffix: string; max: number; min: number}[] = [
  { key: "delivery_fee", label: "ค่าส่งเริ่มต้น", suffix: "บาท", min: 0, max: 10000 },
  { key: "delivery_radius_km", label: "รัศมีจัดส่งสูงสุด", suffix: "กม.", min: 0.01, max: 50 },
  { key: "delivery_base_km", label: "ระยะทางที่รวมในค่าส่งเริ่มต้น", suffix: "กม.", min: 0, max: 50 },
  { key: "delivery_fee_per_km", label: "ค่าส่งเพิ่มเติมต่อ กม.", suffix: "บาท/กม.", min: 0, max: 1000 },
];

function parseNumber(value: string): number {
  if (!value.trim()) return NaN;
  return Number(value);
}
function initialForm(store: MerchantDeliveryStore) {
  return Object.fromEntries(KEYS.map((key) => [key, String(store[key])])) as Record<SettingKey, string>;
}
function snapshot(store: MerchantDeliveryStore) {
  return Object.fromEntries(KEYS.map((key) => [key, Number(store[key])])) as Record<SettingKey, number>;
}
function baht(v: number): string {
  return new Intl.NumberFormat("th-TH", {minimumFractionDigits: 0, maximumFractionDigits: 2}).format(v) + " ฿";
}

/** Edits live per-store settings only after explicit confirmation. Database does a second permission check and audit. */
export function MerchantDeliverySettings({ stores, canEdit }: {stores: MerchantDeliveryStore[]; canEdit: boolean}) {
  const router = useRouter();
  const [items, setItems] = useState(stores);
  const [storeId, setStoreId] = useState(stores[0]?.id ?? "");
  const store = items.find((item) => item.id === storeId) ?? null;
  const [form, setForm] = useState<Record<SettingKey,string>>(stores[0] ? initialForm(stores[0]) : {
    delivery_fee: "", delivery_radius_km: "", delivery_base_km: "", delivery_fee_per_km: "",
  });
  const [reason, setReason] = useState("");
  const [km, setKm] = useState("2.5");
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [saving, startTransition] = useTransition();

  function selectStore(id: string) {
    setStoreId(id);
    const selected = items.find((item) => item.id === id);
    if (selected) setForm(initialForm(selected));
    setReason("");
    setError(null);
    setSuccess(null);
  }
  const proposed = useMemo(() => Object.fromEntries(KEYS.map(key => [key, parseNumber(form[key])])) as Record<SettingKey, number>, [form]);
  const hasChanges = store ? KEYS.some((key) => Number(store[key]) !== proposed[key]) : false;
  const invalidField = fields.find((field) => !Number.isFinite(proposed[field.key])
    || proposed[field.key] < field.min || proposed[field.key] > field.max);
  const distance = parseNumber(km);
  const preview = Number.isFinite(distance) && distance >= 0 && distance <= 50
    ? proposed.delivery_fee + Math.ceil(Math.max(0, distance - proposed.delivery_base_km) * proposed.delivery_fee_per_km)
    : null;

  async function refreshFromServer() {
    const { data, error: loadError } = await createClient().rpc("admin_merchant_delivery_stores");
    if (loadError) throw loadError;
    if (!Array.isArray(data)) throw new Error("ข้อมูลร้านไม่ถูกต้อง");
    const updated = data as MerchantDeliveryStore[];
    setItems(updated);
    const next = updated.find((item) => item.id === storeId);
    if (next) setForm(initialForm(next));
    setReason("");
    router.refresh();
  }

  function save() {
    setError(null);
    setSuccess(null);
    if (!canEdit || !store) return;
    if (invalidField || !hasChanges || reason.trim().length < 5 || reason.trim().length > 300) {
      setError("กรุณากรอกค่าให้ถูกต้อง เปลี่ยนอย่างน้อยหนึ่งค่า และระบุเหตุผล 5–300 ตัวอักษร");
      return;
    }
    if (!window.confirm("ยืนยันปรับค่าส่งของร้าน " + store.name + " หรือไม่? ค่านี้จะมีผลกับการคำนวณออเดอร์ใหม่ทันที")) return;
    startTransition(async () => {
      try {
        const { error: writeError } = await createClient().rpc("admin_update_merchant_delivery", {
          p_store_id: store.id,
          p_expected: snapshot(store),
          p_delivery_fee: proposed.delivery_fee,
          p_delivery_radius_km: proposed.delivery_radius_km,
          p_delivery_base_km: proposed.delivery_base_km,
          p_delivery_fee_per_km: proposed.delivery_fee_per_km,
          p_reason: reason.trim(),
        });
        if (writeError) throw writeError;
        await refreshFromServer();
        setSuccess("บันทึกข้อมูลร้านสำเร็จและตรวจข้อมูลล่าสุดแล้ว");
      } catch (err) {
        const message = err instanceof Error ? err.message : String(err);
        setError(message.includes("settings changed")
          ? "ข้อมูลร้านมีการเปลี่ยนจากที่แสดงอยู่ กรุณากด 'โหลดข้อมูลล่าสุด' ก่อนบันทึก"
          : message.includes("Not authorized") ? "คุณไม่มีสิทธิ์แก้ข้อมูลร้าน" : "บันทึกไม่สำเร็จ: " + message);
      }
    });
  }

  return (
    <div className="space-y-6">
      <section className="rounded-2xl border bg-background p-4 sm:p-6">
        <h2 className="text-lg font-semibold">ตั้งค่าค่าส่งร้านอาหารจริง</h2>
        <p className="mt-1 text-sm text-muted-foreground">แก้ค่าส่งและรัศมีสำหรับร้านจัดส่งเองผ่านข้อมูลเดียวกับ Merchant และหน้า Checkout · ยังไม่ใช่ระบบ WYNOS Rider</p>
        <label className="mt-5 block text-sm font-medium" htmlFor="merchant-delivery-store">เลือกร้านอาหาร</label>
        <select id="merchant-delivery-store" value={storeId} onChange={(e) => selectStore(e.target.value)}
          className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm">
          {items.length === 0 ? <option value="">ไม่มีร้านอาหาร</option> : null}
          {items.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
        </select>
        {store ? (
          <>
            <div className="mt-3 text-xs text-muted-foreground">{store.published ? "เผยแพร่แล้ว" : "ยังไม่เผยแพร่"} · {store.geocoded ? "ร้านตั้งพิกัดแล้ว" : "ร้านยังไม่ได้ตั้งพิกัด — ระบบอาจคิดค่าจัดส่งเริ่มต้นเท่านั้น"}</div>
            <div className="mt-5 grid gap-4 sm:grid-cols-2">
              {fields.map((field) => (
                <label key={field.key} className="block text-sm font-medium">
                  {field.label} <span className="font-normal text-muted-foreground">({field.suffix})</span>
                  <input type="number" step="0.01" min={field.min} max={field.max} inputMode="decimal"
                    value={form[field.key]} disabled={!canEdit || saving}
                    onChange={(e) => { setForm((prev) => ({...prev,[field.key]:e.target.value})); setSuccess(null); }}
                    className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm tabular-nums disabled:opacity-60" />
                </label>
              ))}
            </div>
            <div className="mt-5 rounded-xl bg-muted/40 p-4">
              <p className="font-medium text-sm">ทดลองค่าส่งร้านจัดส่งเอง</p>
              <p className="text-xs text-muted-foreground mt-1">ตัวอย่างตามสูตรที่ระบบ Food ใช้ในปัจจุบัน โดยระยะเป็นเส้นตรงระหว่างพิกัด ไม่ใช่ระยะตามถนน</p>
              <label htmlFor="preview-distance" className="mt-3 block text-sm">ระยะทางตัวอย่าง (กม.)</label>
              <input id="preview-distance" type="number" min="0" max="50" step="0.1" inputMode="decimal"
                value={km} onChange={(e) => setKm(e.target.value)}
                className="mt-2 h-11 w-full rounded-lg border bg-background px-3 text-sm"/>
              <p className="mt-3 text-xl font-semibold tabular-nums">{!invalidField && preview !== null ? baht(preview) : "ระยะทางหรือค่าจัดส่งไม่ถูกต้อง"}</p>
              <p className="mt-1 text-xs text-muted-foreground">เป็นการทดลองคำนวณ ยังไม่เปลี่ยนค่าใดจนกดบันทึก</p>
            </div>
            {canEdit ? (
              <>
                <label htmlFor="delivery-change-reason" className="mt-5 block text-sm font-medium">เหตุผลการแก้ไข (บังคับ)</label>
                <textarea id="delivery-change-reason" value={reason} maxLength={300} rows={2}
                  onChange={(e) => setReason(e.target.value)} disabled={saving}
                  placeholder="เช่น ปรับตามข้อตกลงกับร้านหลังตรวจสอบต้นทุนจัดส่ง"
                  className="mt-2 w-full rounded-lg border bg-background p-3 text-sm"/>
                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" disabled={saving || !!invalidField || !hasChanges || reason.trim().length < 5}
                    onClick={save} className="min-h-11 rounded-lg bg-foreground px-5 text-sm font-semibold text-background disabled:opacity-40">
                    {saving ? "กำลังบันทึก…" : "ตรวจและยืนยันบันทึกจริง"}
                  </button>
                  <button type="button" disabled={saving} onClick={() => startTransition(async () => {
                    setError(null);setSuccess(null);
                    try {await refreshFromServer();} catch (err) {setError("โหลดข้อมูลล่าสุดไม่สำเร็จ: " + String(err));}
                  })} className="min-h-11 rounded-lg border px-5 text-sm font-medium">โหลดข้อมูลล่าสุด</button>
                </div>
              </>
            ) : <p className="mt-4 text-sm text-muted-foreground">คุณมีสิทธิ์ดูอย่างเดียว การแก้ไขต้องใช้ merchant:edit</p>}
            {error ? <p role="alert" className="mt-3 text-sm text-red-600">{error}</p> : null}
            {success ? <p role="status" className="mt-3 text-sm font-medium">{success}</p> : null}
          </>
        ) : <p className="mt-4 text-sm text-muted-foreground">ยังไม่มีร้านที่สามารถตั้งค่าได้</p>}
      </section>
      <p className="text-xs leading-relaxed text-muted-foreground">
        หมายเหตุ: การเปลี่ยนค่าส่งจะมีผลกับการคำนวณคำสั่งซื้อใหม่โดยไม่แก้ยอดออเดอร์เดิม
        ระบบฐานข้อมูลตรวจสิทธิ์ทุกครั้ง ล็อกค่าปัจจุบันเพื่อป้องกันการเขียนทับ และบันทึกเหตุผลกับค่าก่อน/หลังใน Audit Log
        รัศมีใช้ระยะตามพิกัด ไม่ใช่การวาดโพลิกอนบนแผนที่
      </p>
    </div>
  );
}
