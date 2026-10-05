// Small, storage-agnostic helpers for standalone WYNOS Maps:
// recent searches, share links and distance labels.

export type MapsRecentPlace = {
  placeId: string | null;
  name: string;
  address: string | null;
  latitude: number;
  longitude: number;
  category: string | null;
};

type StorageLike = Pick<Storage, "getItem" | "setItem" | "removeItem">;

export const MAPS_RECENTS_KEY = "wynos:maps:recent-places";
export const MAPS_RECENTS_LIMIT = 8;

function validCoordinate(latitude: number, longitude: number) {
  return Number.isFinite(latitude)
    && Number.isFinite(longitude)
    && latitude >= -90 && latitude <= 90
    && longitude >= -180 && longitude <= 180;
}

function sanitizeRecent(value: unknown): MapsRecentPlace | null {
  if (!value || typeof value !== "object") return null;
  const row = value as Record<string, unknown>;
  const latitude = Number(row.latitude);
  const longitude = Number(row.longitude);
  const name = typeof row.name === "string" ? row.name.trim().slice(0, 160) : "";
  if (!name || !validCoordinate(latitude, longitude)) return null;
  return {
    placeId: typeof row.placeId === "string" ? row.placeId.slice(0, 120) : null,
    name,
    address: typeof row.address === "string" ? row.address.slice(0, 300) : null,
    latitude,
    longitude,
    category: typeof row.category === "string" ? row.category.slice(0, 40) : null,
  };
}

function recentKey(place: MapsRecentPlace) {
  return place.placeId ?? `${place.latitude.toFixed(5)},${place.longitude.toFixed(5)},${place.name}`;
}

/** Reads recents; any storage failure or bad data yields an empty list. */
export function loadRecentPlaces(storage: StorageLike | null | undefined): MapsRecentPlace[] {
  try {
    const raw = storage?.getItem(MAPS_RECENTS_KEY);
    if (!raw) return [];
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.flatMap((row) => {
      const place = sanitizeRecent(row);
      return place ? [place] : [];
    }).slice(0, MAPS_RECENTS_LIMIT);
  } catch {
    return [];
  }
}

/** Puts a place first (deduplicated), keeps the list short, and returns it. */
export function rememberRecentPlace(storage: StorageLike | null | undefined, place: unknown): MapsRecentPlace[] {
  const current = loadRecentPlaces(storage);
  const next = sanitizeRecent(place);
  if (!next) return current;
  const key = recentKey(next);
  const list = [next, ...current.filter((item) => recentKey(item) !== key)].slice(0, MAPS_RECENTS_LIMIT);
  try {
    storage?.setItem(MAPS_RECENTS_KEY, JSON.stringify(list));
  } catch {
    // Recents are a convenience; private mode or full storage just skips saving.
  }
  return list;
}

export function clearRecentPlaces(storage: StorageLike | null | undefined) {
  try {
    storage?.removeItem(MAPS_RECENTS_KEY);
  } catch {
    // Nothing to clear.
  }
}

/** A link that reopens WYNOS Maps at this point. */
export function mapsShareUrl(origin: string, latitude: number, longitude: number) {
  const url = new URL("/maps", origin);
  url.searchParams.set("lat", latitude.toFixed(6));
  url.searchParams.set("lon", longitude.toFixed(6));
  return url.toString();
}

/** Reads ?lat=&lon= from a shared link; anything invalid is ignored. */
export function parseMapsDeepLink(search: string): { latitude: number; longitude: number } | null {
  const params = new URLSearchParams(search);
  const lat = params.get("lat");
  const lon = params.get("lon");
  if (lat == null || lon == null || lat.trim() === "" || lon.trim() === "") return null;
  const latitude = Number(lat);
  const longitude = Number(lon);
  return validCoordinate(latitude, longitude) ? { latitude, longitude } : null;
}

export function formatDistanceKm(km: number | null | undefined) {
  if (km == null || !Number.isFinite(km) || km < 0) return null;
  if (km < 1) return `${Math.max(10, Math.round((km * 1000) / 10) * 10)} ม.`;
  return `${km < 10 ? km.toFixed(1) : Math.round(km)} กม.`;
}
