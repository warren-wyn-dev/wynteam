"use client";

import { CheckCircle2, MapPin } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";

import { FoodDeliveryMapPicker } from "@/components/food/food-delivery-map-picker";
import type { FoodLocation, FoodPlace } from "@/lib/food-customer";
import { parseMapsDeepLink } from "@/lib/maps-places";
import { getSupabaseBrowserClient } from "@/lib/supabase/browser";

const STORAGE_KEY = "wynos:maps:last-pin";

type StoredPin = {
  location: FoodLocation;
  place?: FoodPlace;
  savedAt: string;
};

export function WynosMapsAddressPicker() {
  const router = useRouter();
  const client = useMemo(() => getSupabaseBrowserClient(), []);
  const [saved, setSaved] = useState(false);
  const savedTimer = useRef<number | null>(null);
  // A shared link (?lat=&lon=) opens the map on that point; read it after
  // mount so the server render and first client render match.
  const [start, setStart] = useState<{ ready: boolean; location: FoodLocation | null }>({ ready: false, location: null });

  useEffect(() => {
    const timer = window.setTimeout(() => setStart({ ready: true, location: parseMapsDeepLink(window.location.search) }), 0);
    return () => window.clearTimeout(timer);
  }, []);

  const close = () => {
    if (window.history.length > 1) {
      router.back();
      return;
    }
    window.location.assign("https://wynos.online/");
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

  if (!client) {
    return (
      <main className="wynos-maps-page wynos-maps-error">
        <MapPin size={36} />
        <strong>เปิด WYNOS Maps ไม่สำเร็จ</strong>
        <span>ระบบแผนที่ยังเชื่อมต่อบริการตำแหน่งไม่ได้</span>
        <button type="button" onClick={close}>กลับ WYNOS</button>
      </main>
    );
  }

  return (
    <main className="wynos-maps-page">
      {start.ready ? (
        <FoodDeliveryMapPicker
          client={client}
          storeId={null}
          initialLocation={start.location}
          onClose={close}
          onConfirm={confirm}
          autoLocate={!start.location}
          standalone
        />
      ) : null}

      {saved ? (
        <div className="wynos-maps-saved" role="status">
          <CheckCircle2 size={18} />
          บันทึกตำแหน่งแล้ว
        </div>
      ) : null}
    </main>
  );
}
