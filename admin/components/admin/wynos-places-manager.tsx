"use client";

import { CheckCircle2, Database, Pencil, Plus, Upload, X } from "lucide-react";
import { useRouter } from "next/navigation";
import { useMemo, useState, useTransition } from "react";

import {
  adminWynosPlaceError,
  importWynosPlaces,
  saveWynosPlace,
  setWynosPlaceActive,
  type WynosPlaceInput,
} from "@/lib/admin-food-actions";
import type { AdminWynosPlace } from "@/lib/admin-food";

const CATEGORIES = [
  ["place", "สถานที่"], ["restaurant", "ร้านอาหาร"], ["store", "ร้านค้า"],
  ["building", "อาคาร"], ["residence", "ที่พักอาศัย"], ["pickup_point", "จุดรับอาหาร"],
  ["dropoff_point", "จุดส่ง"], ["entrance", "ทางเข้า"], ["poi", "จุดสำคัญ"],
] as const;

const IMPORT_SAMPLE = JSON.stringify([{
  source: "osm",
  source_ref: "node/123",
  name_th: "ชื่อสถานที่",
  category: "poi",
  latitude: 16.18,
  longitude: 103.30,
  address: "มหาสารคาม",
}], null, 2);

type Draft = {
  id: string | null;
  nameTh: string; nameEn: string; category: string; address: string; building: string;
  latitude: string; longitude: string; entranceLatitude: string; entranceLongitude: string;
  source: WynosPlaceInput["source"]; sourceRef: string;
  verificationStatus: WynosPlaceInput["verificationStatus"]; isActive: boolean;
};

const EMPTY_DRAFT: Draft = {
  id: null, nameTh: "", nameEn: "", category: "place", address: "", building: "",
  latitude: "", longitude: "", entranceLatitude: "", entranceLongitude: "",
  source: "wynos", sourceRef: "", verificationStatus: "unverified", isActive: true,
};

function toDraft(place: AdminWynosPlace): Draft {
  return {
    id: place.id,
    nameTh: place.name_th,
    nameEn: place.name_en ?? "",
    category: place.category,
    address: place.address ?? "",
    building: place.building ?? "",
    latitude: String(place.latitude),
    longitude: String(place.longitude),
    entranceLatitude: place.entrance_latitude == null ? "" : String(place.entrance_latitude),
    entranceLongitude: place.entrance_longitude == null ? "" : String(place.entrance_longitude),
    source: place.source === "osm" || place.source === "overture" || place.source === "user_report" ? place.source : "wynos",
    sourceRef: place.source_ref ?? "",
    verificationStatus: place.verification_status,
    isActive: place.is_active,
  };
}

function categoryLabel(value: string) {
  return CATEGORIES.find(([key]) => key === value)?.[1] ?? value;
}

function verificationLabel(value: string) {
  if (value === "wynos_verified") return "WYNOS Verified";
  if (value === "merchant_verified") return "Merchant Verified";
  return "ยังไม่ยืนยัน";
}

export function WynosPlacesManager({ places }: { places: AdminWynosPlace[] }) {
  const router = useRouter();
  const [draft, setDraft] = useState<Draft | null>(null);
  const [importText, setImportText] = useState("");
  const [message, setMessage] = useState("");
  const [pending, startTransition] = useTransition();

  const counts = useMemo(() => ({
    all: places.length,
    active: places.filter((p) => p.is_active).length,
    verified: places.filter((p) => p.verification_status === "wynos_verified").length,
    merchant: places.filter((p) => p.merchant_store_id || p.food_store_place_id).length,
  }), [places]);

  const finish = (done: string) => {
    setMessage(done);
    setDraft(null);
    router.refresh();
  };

  const submit = () => {
    if (!draft) return;
    const latitude = Number(draft.latitude);
    const longitude = Number(draft.longitude);
    const entranceLatitude = draft.entranceLatitude.trim() ? Number(draft.entranceLatitude) : null;
    const entranceLongitude = draft.entranceLongitude.trim() ? Number(draft.entranceLongitude) : null;
    if (!draft.nameTh.trim()) return setMessage("กรุณาใส่ชื่อสถานที่");
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return setMessage("พิกัดไม่ถูกต้อง");
    if ((entranceLatitude == null) !== (entranceLongitude == null)) return setMessage("กรุณาใส่พิกัดทางเข้าให้ครบ");

    startTransition(async () => {
      try {
        await saveWynosPlace({
          id: draft.id,
          nameTh: draft.nameTh, nameEn: draft.nameEn, category: draft.category,
          address: draft.address, building: draft.building,
          latitude, longitude, entranceLatitude, entranceLongitude,
          source: draft.source, sourceRef: draft.sourceRef,
          verificationStatus: draft.verificationStatus, isActive: draft.isActive,
        });
        finish(draft.id ? "อัปเดตสถานที่แล้ว" : "เพิ่มสถานที่แล้ว");
      } catch (error) {
        setMessage(adminWynosPlaceError(error));
      }
    });
  };

  const toggle = (place: AdminWynosPlace) => startTransition(async () => {
    try {
      await setWynosPlaceActive(place.id, !place.is_active);
      finish(place.is_active ? "ซ่อนสถานที่แล้ว" : "เปิดสถานที่แล้ว");
    } catch (error) {
      setMessage(adminWynosPlaceError(error));
    }
  });

  const runImport = () => startTransition(async () => {
    try {
      const parsed = JSON.parse(importText) as unknown;
      if (!Array.isArray(parsed)) throw new Error("places payload must be an array");
      const result = await importWynosPlaces(parsed);
      setImportText("");
      setMessage("นำเข้าแล้ว " + result.rows + " รายการ · ใหม่ " + result.inserted + " · อัปเดต " + result.updated);
      router.refresh();
    } catch (error) {
      setMessage(error instanceof SyntaxError ? "JSON ไม่ถูกต้อง" : adminWynosPlaceError(error));
    }
  });

  return (
    <div className="flex flex-col gap-6">
      {message ? <div className="flex items-center justify-between rounded-lg border bg-muted/40 px-4 py-3 text-sm" role="status">
        <span>{message}</span><button type="button" aria-label="ปิดข้อความ" onClick={() => setMessage("")}><X className="size-4" /></button>
      </div> : null}

      <section className="grid grid-cols-2 gap-3 lg:grid-cols-4">
        {[["ทั้งหมด", counts.all], ["กำลังแสดง", counts.active], ["WYNOS Verified", counts.verified], ["จาก Merchant", counts.merchant]].map(([label, value]) => (
          <div key={String(label)} className="rounded-xl border p-4">
            <p className="text-xs text-muted-foreground">{label}</p>
            <p className="mt-1 text-xl font-semibold tabular-nums">{Number(value).toLocaleString("th-TH")}</p>
          </div>
        ))}
      </section>

      <section className="flex flex-col gap-3 rounded-xl border p-4">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div><h3 className="font-semibold">Places</h3><p className="text-xs text-muted-foreground">Active Places ใช้ใน Search และ Nearby ของ WYNOS Maps</p></div>
          <button type="button" className="inline-flex h-10 items-center gap-2 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground" onClick={() => setDraft({ ...EMPTY_DRAFT })}>
            <Plus className="size-4" /> เพิ่มสถานที่
          </button>
        </div>
        {places.length === 0 ? <div className="rounded-lg border border-dashed p-8 text-center text-sm text-muted-foreground">ยังไม่มีสถานที่ตามตัวกรองนี้</div> : (
          <div className="overflow-x-auto rounded-lg border">
            <table className="w-full min-w-[920px] text-sm">
              <thead className="bg-muted/50 text-left text-xs text-muted-foreground"><tr>
                <th className="px-3 py-2">สถานที่</th><th className="px-3 py-2">ประเภท</th><th className="px-3 py-2">พิกัด</th>
                <th className="px-3 py-2">แหล่งข้อมูล</th><th className="px-3 py-2">ยืนยัน</th><th className="px-3 py-2">สถานะ</th><th className="px-3 py-2 text-right">จัดการ</th>
              </tr></thead>
              <tbody className="divide-y">{places.map((place) => (
                <tr key={place.id} className={place.is_active ? "" : "opacity-60"}>
                  <td className="px-3 py-3"><div className="font-medium">{place.name_th}</div><div className="max-w-[320px] truncate text-xs text-muted-foreground">{place.address || place.id}</div></td>
                  <td className="px-3 py-3">{categoryLabel(place.category)}</td>
                  <td className="px-3 py-3 font-mono text-xs">{place.latitude.toFixed(5)}, {place.longitude.toFixed(5)}</td>
                  <td className="px-3 py-3"><span className="rounded-full bg-muted px-2 py-1 text-xs">{place.source}</span>{place.merchant_store_id ? <span className="ml-1 rounded-full bg-red-50 px-2 py-1 text-xs text-red-700">Food</span> : null}</td>
                  <td className="px-3 py-3">{verificationLabel(place.verification_status)}</td>
                  <td className="px-3 py-3">{place.is_active ? "แสดง" : "ซ่อน"}</td>
                  <td className="px-3 py-3"><div className="flex justify-end gap-2">
                    <button type="button" className="inline-flex h-9 items-center gap-1 rounded-md border px-3 text-xs" onClick={() => setDraft(toDraft(place))}><Pencil className="size-3.5" /> แก้ไข</button>
                    <button type="button" disabled={pending} className="h-9 rounded-md border px-3 text-xs" onClick={() => toggle(place)}>{place.is_active ? "ซ่อน" : "แสดง"}</button>
                  </div></td>
                </tr>
              ))}</tbody>
            </table>
          </div>
        )}
      </section>

      <section className="grid gap-4 rounded-xl border p-4 lg:grid-cols-[1fr_1.3fr]">
        <div><div className="flex items-center gap-2"><Database className="size-4" /><h3 className="font-semibold">Import Places</h3></div>
          <p className="mt-2 text-sm text-muted-foreground">JSON array จาก OpenStreetMap หรือ Overture ครั้งละไม่เกิน 500 รายการ ใช้ source + source_ref ป้องกันข้อมูลซ้ำ</p>
          <pre className="mt-3 overflow-x-auto rounded-lg bg-muted p-3 text-xs">{IMPORT_SAMPLE}</pre>
        </div>
        <div className="flex flex-col gap-2">
          <textarea className="min-h-56 rounded-md border bg-background p-3 font-mono text-xs" value={importText} onChange={(e) => setImportText(e.target.value)} placeholder="วาง JSON array ที่นี่" />
          <button type="button" disabled={pending || !importText.trim()} className="inline-flex h-10 items-center justify-center gap-2 rounded-md border px-4 text-sm font-medium disabled:opacity-50" onClick={runImport}><Upload className="size-4" /> นำเข้า Places</button>
        </div>
      </section>

      {draft ? <div className="fixed inset-0 z-50 grid place-items-center bg-black/40 p-4">
        <div className="max-h-[92dvh] w-full max-w-2xl overflow-y-auto rounded-2xl bg-background p-5 shadow-2xl">
          <div className="mb-4 flex items-center justify-between"><div><h3 className="font-semibold">{draft.id ? "แก้ไข WYNOS Place" : "เพิ่ม WYNOS Place"}</h3>{draft.id ? <p className="text-xs text-muted-foreground">{draft.id}</p> : null}</div>
            <button type="button" className="grid size-9 place-items-center rounded-full bg-muted" onClick={() => setDraft(null)}><X className="size-4" /></button>
          </div>
          <div className="grid gap-3">
            <div className="grid gap-3 sm:grid-cols-2"><label className="grid gap-1 text-sm">ชื่อไทย<input className="h-10 rounded-md border px-3" value={draft.nameTh} onChange={(e) => setDraft({ ...draft, nameTh: e.target.value })} /></label>
              <label className="grid gap-1 text-sm">ชื่ออังกฤษ<input className="h-10 rounded-md border px-3" value={draft.nameEn} onChange={(e) => setDraft({ ...draft, nameEn: e.target.value })} /></label></div>
            <div className="grid gap-3 sm:grid-cols-2"><label className="grid gap-1 text-sm">ประเภท<select className="h-10 rounded-md border bg-background px-3" value={draft.category} onChange={(e) => setDraft({ ...draft, category: e.target.value })}>{CATEGORIES.map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
              <label className="grid gap-1 text-sm">Verification<select className="h-10 rounded-md border bg-background px-3" value={draft.verificationStatus} onChange={(e) => setDraft({ ...draft, verificationStatus: e.target.value as Draft["verificationStatus"] })}><option value="unverified">ยังไม่ยืนยัน</option><option value="merchant_verified">Merchant Verified</option><option value="wynos_verified">WYNOS Verified</option></select></label></div>
            <label className="grid gap-1 text-sm">ที่อยู่<textarea className="min-h-20 rounded-md border p-3" value={draft.address} onChange={(e) => setDraft({ ...draft, address: e.target.value })} /></label>
            <label className="grid gap-1 text-sm">อาคาร / สถานที่ย่อย<input className="h-10 rounded-md border px-3" value={draft.building} onChange={(e) => setDraft({ ...draft, building: e.target.value })} /></label>
            <div className="grid gap-3 sm:grid-cols-2"><label className="grid gap-1 text-sm">Latitude<input className="h-10 rounded-md border px-3 font-mono" inputMode="decimal" value={draft.latitude} onChange={(e) => setDraft({ ...draft, latitude: e.target.value })} /></label>
              <label className="grid gap-1 text-sm">Longitude<input className="h-10 rounded-md border px-3 font-mono" inputMode="decimal" value={draft.longitude} onChange={(e) => setDraft({ ...draft, longitude: e.target.value })} /></label></div>
            <div className="grid gap-3 sm:grid-cols-2"><label className="grid gap-1 text-sm">Entrance latitude<input className="h-10 rounded-md border px-3 font-mono" inputMode="decimal" value={draft.entranceLatitude} onChange={(e) => setDraft({ ...draft, entranceLatitude: e.target.value })} /></label>
              <label className="grid gap-1 text-sm">Entrance longitude<input className="h-10 rounded-md border px-3 font-mono" inputMode="decimal" value={draft.entranceLongitude} onChange={(e) => setDraft({ ...draft, entranceLongitude: e.target.value })} /></label></div>
            <div className="grid gap-3 sm:grid-cols-2"><label className="grid gap-1 text-sm">Source<select className="h-10 rounded-md border bg-background px-3" value={draft.source} onChange={(e) => setDraft({ ...draft, source: e.target.value as Draft["source"] })}><option value="wynos">WYNOS</option><option value="osm">OpenStreetMap</option><option value="overture">Overture</option><option value="user_report">User report</option></select></label>
              <label className="grid gap-1 text-sm">Source reference<input className="h-10 rounded-md border px-3" value={draft.sourceRef} onChange={(e) => setDraft({ ...draft, sourceRef: e.target.value })} /></label></div>
            <label className="flex items-center gap-3 rounded-lg border p-3 text-sm"><input type="checkbox" checked={draft.isActive} onChange={(e) => setDraft({ ...draft, isActive: e.target.checked })} /><span><strong className="block">แสดงบน WYNOS Maps</strong><small className="text-muted-foreground">ปิดไว้ได้ระหว่างตรวจสอบข้อมูล</small></span></label>
            <div className="flex justify-end gap-2 pt-2"><button type="button" className="h-10 rounded-md border px-4 text-sm" onClick={() => setDraft(null)}>ยกเลิก</button>
              <button type="button" disabled={pending} className="inline-flex h-10 items-center gap-2 rounded-md bg-primary px-4 text-sm font-medium text-primary-foreground disabled:opacity-50" onClick={submit}><CheckCircle2 className="size-4" /> บันทึก</button></div>
          </div>
        </div>
      </div> : null}
    </div>
  );
}
