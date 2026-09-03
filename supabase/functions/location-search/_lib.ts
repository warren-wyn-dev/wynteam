// WYN-098: pure/testable logic for location-search, split out of
// index.ts the same way send-push-notification's own _lib.ts is (see
// that file's doc comment) -- importing index.ts itself would call
// Deno.serve() as a module-load side effect.

/** One normalized place result the Flutter client's LocationPickerSheet
 * renders as a row -- see .wyn/docs/design/wyn-098-location-checkin.md
 * Screen 2. [address] is the disambiguating subtitle (e.g. "สยามพารากอน"
 * for a "Starbucks" search with multiple branches) -- null when
 * LocationIQ's response has nothing beyond the name itself worth
 * showing as a 2nd line. */
export interface LocationResult {
  name: string;
  address: string | null;
  lat: number;
  lon: number;
  placeId: string;
}

/** LocationIQ's own `/v1/search` and `/v1/autocomplete` response shape
 * (both return an array of these) -- only the fields this function
 * actually reads are declared; everything else LocationIQ sends back
 * is ignored. `place_id` is usually present and numeric-as-string;
 * `osm_type`/`osm_id` are the documented fallback identifier pair per
 * Product spec ("place_id (หรือ osm_id+osm_type ตามที่ endpoint ส่งกลับมา)"). */
interface LocationIqPlace {
  place_id?: string | number;
  osm_type?: string;
  osm_id?: string | number;
  lat: string;
  lon: string;
  display_name: string;
}

/** LocationIQ's `display_name` is a single comma-separated string (e.g.
 * "Starbucks, 991, Rama I Rd, Pathum Wan, Bangkok, 10330, Thailand")
 * -- the first segment is the place's own name, the rest is address
 * detail worth showing as a subtitle to disambiguate same-named
 * results (Product spec's "ผลการค้นหาสถานที่กำกวม/ซ้ำกันหลายรายการ"
 * edge case, Design spec Screen 2's Starbucks example). */
function splitDisplayName(displayName: string): { name: string; address: string | null } {
  const parts = displayName.split(",").map((p) => p.trim()).filter((p) => p.length > 0);
  if (parts.length === 0) return { name: displayName.trim(), address: null };
  const [name, ...rest] = parts;
  return { name, address: rest.length > 0 ? rest.join(", ") : null };
}

function placeIdOf(place: LocationIqPlace): string {
  if (place.place_id !== undefined && place.place_id !== null) {
    return String(place.place_id);
  }
  return `${place.osm_type ?? "unknown"}:${place.osm_id ?? ""}`;
}

function toLocationResult(place: LocationIqPlace): LocationResult | null {
  const lat = Number(place.lat);
  const lon = Number(place.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || !place.display_name) return null;
  const { name, address } = splitDisplayName(place.display_name);
  return { name, address, lat, lon, placeId: placeIdOf(place) };
}

/** `/v1/search` and `/v1/autocomplete` both return a JSON array on
 * success -- an unexpected shape (LocationIQ error payload, a
 * malformed/empty body) parses to an empty list rather than throwing,
 * so the caller can treat "no results" and "couldn't parse the
 * response" the same way (both surface as the ordinary empty-results
 * state client-side, not a hard error). */
export function parseSearchResults(raw: unknown): LocationResult[] {
  if (!Array.isArray(raw)) return [];
  const results: LocationResult[] = [];
  for (const entry of raw) {
    const parsed = toLocationResult(entry as LocationIqPlace);
    if (parsed) results.push(parsed);
  }
  return results;
}

/** `/v1/reverse` returns a single JSON object (not an array) on
 * success. Null on anything else -- same "unparseable = no result"
 * posture as [parseSearchResults]. */
export function parseReverseGeocodeResult(raw: unknown): LocationResult | null {
  if (raw === null || typeof raw !== "object" || Array.isArray(raw)) return null;
  return toLocationResult(raw as LocationIqPlace);
}

export function buildSearchUrl(apiKey: string, query: string): string {
  const params = new URLSearchParams({
    key: apiKey,
    q: query,
    format: "json",
    limit: "10",
    // Product spec's UI copy table has no Thai-vs-English distinction,
    // but WYN targets Thai users first -- biasing results toward
    // Thailand keeps a bare "starbucks"-style query useful without
    // requiring the user to type a country/city qualifier themselves.
    countrycodes: "th",
  });
  return `https://us1.locationiq.com/v1/search?${params.toString()}`;
}

export function buildReverseUrl(apiKey: string, lat: number, lon: number): string {
  const params = new URLSearchParams({
    key: apiKey,
    lat: String(lat),
    lon: String(lon),
    format: "json",
  });
  return `https://us1.locationiq.com/v1/reverse?${params.toString()}`;
}

// ---------------------------------------------------------------------
// Rate limiting (Product spec's "Rate-limiting/abuse prevention ฝั่ง
// WYN", ชั้นที่ 2 -- server-side, mandatory). 20 requests/minute/user,
// an AI Product Manager-proposed starting point per that spec, not a
// value verified against LocationIQ's own real free-tier terms.
// ---------------------------------------------------------------------
export const RATE_LIMIT_MAX_REQUESTS = 20;
export const RATE_LIMIT_WINDOW_SECONDS = 60;

/** True when [requestCountInWindow] (the number of
 * location_search_requests rows already logged for this user in the
 * trailing [RATE_LIMIT_WINDOW_SECONDS]) means one more request should
 * be rejected outright, before ever calling LocationIQ. */
export function isRateLimited(requestCountInWindow: number): boolean {
  return requestCountInWindow >= RATE_LIMIT_MAX_REQUESTS;
}

// ---------------------------------------------------------------------
// Auth -- extracts the caller's user id from the JWT Supabase's
// platform-level `verify_jwt` gate has *already validated* before this
// function's code ever runs (the standard, default behavior for a
// deployed Edge Function -- see supabase/functions/location-search/
// index.ts's own doc comment). Decoding (not re-verifying) the
// already-trusted token's payload here is the same "no Supabase JS
// client dependency, raw fetch/parsing only" posture
// send-push-notification's own _lib.ts/index.ts already established
// for this project's Edge Functions.
// ---------------------------------------------------------------------
export function userIdFromAuthHeader(authHeader: string | null): string | null {
  if (!authHeader) return null;
  const token = authHeader.replace(/^Bearer\s+/i, "");
  const parts = token.split(".");
  if (parts.length !== 3) return null;
  try {
    const payloadJson = atob(parts[1].replace(/-/g, "+").replace(/_/g, "/"));
    const payload = JSON.parse(payloadJson) as { sub?: string };
    return typeof payload.sub === "string" ? payload.sub : null;
  } catch {
    return null;
  }
}
