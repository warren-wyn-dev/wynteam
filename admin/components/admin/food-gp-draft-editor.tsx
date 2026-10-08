"use client";

import { useMemo, useState } from "react";
import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/client";
import type { FoodGpStoreDraft } from "@/lib/admin-food-gp";

const money = (satang: number) => new Intl.NumberFormat("th-TH", {
  style: "currency", currency: "THB", minimumFractionDigits: 2,
}).format(satang / 100);

function parseBasisPoints(raw: string): number | null {
  const trimmed = raw.trim();
  if (!/^(?:100(?:\.0{1,2})?|\d{1,2}(?:\.\d{1,2})?)$/.test(trimmed)) return null;
  const value = Number(trimmed);
  if (!Number.isFinite(value) || value < 0 || value > 100) return null;
  return Math.round(value * 100);
}

export function FoodGpDraftEditor({ stores }: { stores: FoodGpStoreDraft[] }) {
  const router = useRouter();
  const [selected, setSelected] = useState(stores[0]?.store_id ?? "");
  const chosen = useMemo(() => stores.find((s) => s.store_id === selected), [selected, stores]);
  const [rate, setRate] = useState(chosen?.rate_bps == null ? "" : (chosen.rate_bps / 100).toFixed(2));
  const [reason, setReason] = useState("");
  const [exampleAmount, setExampleAmount] = useState("500");
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState("");

  const newBps = parseBasisPoints(rate);
  const amountValid = /^(?:\d{1,9})(?:\.\d{1,2})?$/.test(exampleAmount.trim());
  const amountSatang = amountValid ? Math.round(Number(exampleAmount) * 100) : null;
  const previewGp = newBps == null || amountSatang == null
    ? null
    : Math.floor((amountSatang * newBps) / 10000 + 0.5);

  function switchStore(next: string) {
    setSelected(next);
    const row = stores.find((s) => s.store_id === next);
    setRate(row?.rate_bps == null ? "" : (row.rate_bps / 100).toFixed(2));
    setReason("");
    setResult("");
  }

  async function saveDraft() {
    if (!chosen || newBps == null || reason.trim().length < 3 || reason.trim().length > 500 || busy) return;
    setBusy(true);
    setResult("");
    try {
      if (process.env.NEXT_PUBLIC_SUPABASE_URL !== "https://pcatuxtenluqzjzzwsvl.supabase.co") {
        throw new Error("ระบบ GP เปิดให้แก้ไขเฉพาะ Sandbox");
      }
      const supabase = createClient();
      const { error } = await supabase.rpc("admin_food_gp_set_draft", {
        p_store_id: chosen.store_id,
        p_rate_bps: newBps,
        p_expected_rate_bps: chosen.rate_bps,
        p_reason: reason.trim(),
      });
      if (error) throw error;
      setResult("บันทึกอัตราแบบร่างสำเร็จ ไม่มีการหักเงินจริง");
      setReason("");
      router.refresh();
    } catch (e) {
      setResult(e instanceof Error ? e.message : "ไม่สามารถบันทึก GP ได้");
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex flex-col gap-5">
      <div className="rounded-xl border bg-background p-4">
        <h3 className="mb-3 font-semibold">ตั้งค่า GP รายร้าน (แบบร่าง)</h3>
        {stores.length === 0 ? (
          <p className="text-sm text-muted-foreground">ยังไม่มีร้านค้าใน Sandbox</p>
        ) : (
          <div className="grid gap-4 sm:grid-cols-2">
            <label className="flex flex-col gap-1 text-sm">
              ร้านค้า
              <select aria-label="เลือกร้านค้า" value={selected} onChange={(e) => switchStore(e.target.value)}
                className="h-11 rounded-md border bg-background px-3">
                {stores.map((s) => <option key={s.store_id} value={s.store_id}>{s.store_name}</option>)}
              </select>
            </label>
            <label className="flex flex-col gap-1 text-sm">
              อัตรา GP (%) — เว้นว่างไว้ได้จนกว่าจะตัดสินใจ
              <input aria-label="อัตรา GP เป็นเปอร์เซ็นต์" inputMode="decimal" value={rate}
                onChange={(e) => setRate(e.target.value)}
                placeholder="ยังไม่กำหนด" className="h-11 rounded-md border bg-background px-3" />
            </label>
            <label className="flex flex-col gap-1 text-sm sm:col-span-2">
              เหตุผลที่ตั้งหรือเปลี่ยนอัตรา (อย่างน้อย 3 ตัวอักษร)
              <textarea aria-label="เหตุผลในการเปลี่ยน GP" value={reason}
                onChange={(e) => setReason(e.target.value)} maxLength={500} rows={2}
                placeholder="เหตุผลเพื่อบันทึกประวัติการตั้งค่า"
                className="rounded-md border bg-background p-3" />
            </label>
            <div className="flex flex-col gap-2 sm:col-span-2">
              <button type="button" onClick={() => void saveDraft()}
                disabled={busy || newBps == null || !chosen || reason.trim().length < 3 || reason.trim().length > 500 ||
                  newBps === chosen.rate_bps}
                className="h-11 rounded-md bg-foreground px-4 text-sm font-semibold text-background disabled:cursor-not-allowed disabled:opacity-40">
                {busy ? "กำลังบันทึก..." : "บันทึก GP แบบร่าง"}
              </button>
              <p role="status" className="text-sm text-muted-foreground">{result}</p>
            </div>
          </div>
        )}
      </div>

      <div className="rounded-xl border bg-background p-4">
        <h3 className="font-semibold">ตัวอย่างการคำนวณเท่านั้น</h3>
        <p className="mt-1 text-xs text-muted-foreground">ฐานคำนวณคือยอดค่าอาหาร ไม่รวมค่าจัดส่ง คืนเงิน ค่าธรรมเนียม Stripe หรือภาษี</p>
        <label className="mt-4 flex max-w-xs flex-col gap-1 text-sm">
          ยอดค่าอาหารตัวอย่าง (บาท)
          <input aria-label="ยอดค่าอาหารตัวอย่าง" inputMode="decimal" value={exampleAmount}
            onChange={(e) => setExampleAmount(e.target.value)} className="h-11 rounded-md border bg-background px-3" />
        </label>
        <dl className="mt-4 grid gap-3 text-sm sm:grid-cols-3">
          <div><dt className="text-muted-foreground">ยอดค่าอาหาร</dt><dd className="text-lg font-semibold">{amountSatang == null ? "—" : money(amountSatang)}</dd></div>
          <div><dt className="text-muted-foreground">GP จำลอง</dt><dd className="text-lg font-semibold">{previewGp == null ? "ยังไม่กำหนด" : money(previewGp)}</dd></div>
          <div><dt className="text-muted-foreground">ส่วนร้านค้าก่อนค่าธรรมเนียมอื่น</dt><dd className="text-lg font-semibold">{previewGp == null || amountSatang == null ? "—" : money(amountSatang - previewGp)}</dd></div>
        </dl>
        <p className="mt-4 rounded-lg bg-muted/50 p-3 text-xs">
          การหัก GP จริง: ปิดอยู่ · Stripe application fee: 0 บาท · ไม่มีการเปลี่ยนยอดโอนร้านค้า
        </p>
      </div>

      <div className="overflow-x-auto rounded-xl border bg-background">
        <table className="min-w-full text-sm">
          <thead><tr className="border-b bg-muted/50 text-left">
            <th className="p-3">ร้านอาหาร</th><th className="p-3">อัตรา GP แบบร่าง</th><th className="p-3">สถานะ</th>
          </tr></thead>
          <tbody>{stores.map((s) => <tr key={s.store_id} className="border-b last:border-0">
            <td className="p-3">{s.store_name}</td>
            <td className="p-3">{s.rate_bps == null ? "ยังไม่กำหนด" : `${(s.rate_bps / 100).toFixed(2)}%`}</td>
            <td className="p-3">จำลองเท่านั้น</td>
          </tr>)}</tbody>
        </table>
      </div>
    </div>
  );
}
