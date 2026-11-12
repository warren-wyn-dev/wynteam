import type { FoodLocation } from "@/lib/food-customer";

/**
 * Delivery addresses and standalone Maps must use a fresh device fix, not a cached location.
 * A phone can initially report a coarse network location before GPS settles:
 * keep the most accurate update and wait briefly for a better reading.
 */
export function freshGpsLocation(timeoutMs = 12_000): Promise<{ location: FoodLocation; accuracyMeters: number }> {
  return new Promise((resolve, reject) => {
    if (typeof navigator === "undefined" || !navigator.geolocation) {
      reject(new Error("อุปกรณ์นี้ไม่รองรับการระบุตำแหน่ง"));
      return;
    }

    const geolocation = navigator.geolocation;
    let watchId: number | null = null;
    let settled = false;
    let best: { location: FoodLocation; accuracyMeters: number } | null = null;
    const cleanup = () => {
      window.clearTimeout(timer);
      if (watchId != null) geolocation.clearWatch(watchId);
    };
    const finish = (fix: typeof best, error?: Error) => {
      if (settled) return;
      settled = true;
      cleanup();
      if (fix) resolve(fix);
      else reject(error ?? new Error("หาตำแหน่งปัจจุบันไม่สำเร็จ กรุณาลองอีกครั้ง"));
    };

    const timer = window.setTimeout(() => finish(best, new Error("GPS ยังไม่ส่งตำแหน่งใหม่ กรุณาลองอีกครั้ง")), timeoutMs);
    watchId = geolocation.watchPosition(
      (position) => {
        const { latitude, longitude, accuracy } = position.coords;
        if (!Number.isFinite(latitude) || !Number.isFinite(longitude)
          || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return;
        const fix = {
          location: { latitude, longitude },
          accuracyMeters: Number.isFinite(accuracy) && accuracy >= 0 ? accuracy : Number.POSITIVE_INFINITY,
        };
        if (!best || fix.accuracyMeters < best.accuracyMeters) best = fix;
        if (fix.accuracyMeters <= 40) finish(fix);
      },
      (error) => {
        if (error.code === 1) {
          finish(null, new Error("กรุณาอนุญาตตำแหน่งที่แน่นอน (Precise Location) ในการตั้งค่า Safari"));
        } else {
          finish(best, new Error("GPS ไม่พร้อมใช้งาน กรุณาลองใหม่หรือค้นหาสถานที่"));
        }
      },
      { enableHighAccuracy: true, maximumAge: 0, timeout: timeoutMs },
    );
  });
}
