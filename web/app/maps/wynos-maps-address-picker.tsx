"use client";

import { CheckCircle2, MapPin } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

import { FoodDeliveryMapPicker } from "@/components/food/food-delivery-map-picker";
import type { FoodLocation, FoodPlace } from "@/lib/food-customer";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const STORAGE_KEY = "wynos:maps:last-pin";

type StoredPin = {
  location: FoodLocation;
  place?: FoodPlace;
  savedAt: string;
};

function readStoredPin(): FoodLocation | null {
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as Partial<StoredPin>;
    const latitude = parsed.location?.latitude;
    const longitude = parsed.location?.longitude;
    if (typeof latitude !== "number" || typeof longitude !== "number") return null;
    if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
    return { latitude, longitude };
  } catch {
    return null;
  }
}

export function WynosMapsAddressPicker() {
  const router = useRouter();
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [initialLocation, setInitialLocation] = useState<FoodLocation | null>(null);
  const [ready, setReady] = useState(false);
  const [saved, setSaved] = useState(false);
  const savedTimer = useRef<number | null>(null);

  useEffect(() => {
    setInitialLocation(readStoredPin());
    setReady(true);
    return () => {
      if (savedTimer.current) window.clearTimeout(savedTimer.current);
    };
  }, []);

  const close = () => {
    if (window.history.length > 1) {
      router.back();
      return;
    }
    router.push("/food");
  };

  const confirm = (location: FoodLocation, place?: FoodPlace) => {
    const payload: StoredPin = {
      location,
      place,
      savedAt: new Date().toISOString(),
    };
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(payload));
    window.dispatchEvent(new CustomEvent("wynos:maps:pin-confirmed", { detail: payload }));
    setSaved(true);
    if (savedTimer.current) window.clearTimeout(savedTimer.current);
    savedTimer.current = window.setTimeout(() => setSaved(false), 2200);
  };

  if (!ready) {
    return (
      <main className="wynos-maps-page wynos-maps-boot">
        <MapPin size={32} />
        <strong>WYNOS Maps</strong>
        <span>กำลังเตรียมแผนที่…</span>
      </main>
    );
  }

  if (!client) {
    return (
      <main className="wynos-maps-page wynos-maps-error">
        <MapPin size={36} />
        <strong>เปิด WYNOS Maps ไม่สำเร็จ</strong>
        <span>ระบบแผนที่ยังเชื่อมต่อบริการตำแหน่งไม่ได้</span>
        <button type="button" onClick={close}>กลับ WYNOS Food</button>
      </main>
    );
  }

  return (
    <main className="wynos-maps-page">
      <div className="wynos-maps-brand-rail" aria-hidden="true">
        <span>WYNOS FOOD</span>
        <i />
        <strong>MAPS</strong>
      </div>

      <FoodDeliveryMapPicker
        client={client}
        storeId={null}
        initialLocation={initialLocation}
        onClose={close}
        onConfirm={confirm}
      />

      {saved ? (
        <div className="wynos-maps-saved" role="status">
          <CheckCircle2 size={18} />
          บันทึกหมุดแล้ว
        </div>
      ) : null}
    </main>
  );
}
