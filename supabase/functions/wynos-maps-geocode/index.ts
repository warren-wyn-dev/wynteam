// Public fallback geocoder for WYNOS Maps.
//
// WYNOS-owned Places are queried before this function. When LocationIQ is not
// configured, WYNOS temporarily falls back to the public Photon demo service
// (OpenStreetMap data). Requests are rate-limited server-side and reverse
// results are cached. This is a bridge until WYNOS self-hosted geocoding is live.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const LEGACY_PUBLIC_API_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const PUBLISHABLE_KEYS = (() => {
  try {
    const raw = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
    if (!raw) return [] as string[];
    return Object.values(JSON.parse(raw) as Record<string, string>).filter(Boolean);
  } catch {
    return [] as string[];
  }
})();
const LOCATIONIQ_API_KEY = Deno.env.get("LOCATIONIQ_API_KEY");

const ALLOWED_ORIGINS = new Set([
  "https://wynos.online",
  "https://www.wynos.online",
  "https://maps.wynos.online",
  "https://food.wynos.online",
  "https://merchant.wynos.online",
  "http://localhost:3000",
  "http://localhost:3001",
]);

const MAX_QUERY_LENGTH = 200;
const TIMEOUT_MS = 6500;
const PHOTON_BASE = "https://photon.komoot.io";
const APP_USER_AGENT = "WYNOSMaps/1.0 (+https://wynos.online/maps)";
const THAILAND_BBOX = "97.343,5.61,105.636,20.465";

type LocationResult = {
  name: string;
  address: string | null;
  lat: number;
  lon: number;
  place_id: string;
};

type LocationIqPlace = {
  place_id?: string | number;
  osm_type?: string;
  osm_id?: string | number;
  lat?: string | number;
  lon?: string | number;
  name?: string;
  display_name?: string;
  address?: Record<string, unknown>;
};

type PhotonFeature = {
  geometry?: { coordinates?: unknown[] };
  properties?: Record<string, unknown>;
};

function corsHeaders(origin: string | null) {
  return {
    "Access-Control-Allow-Origin": origin && ALLOWED_ORIGINS.has(origin) ? origin : "https://wynos.online",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Vary": "Origin",
  };
}

function splitDisplayName(displayName: string) {
  const parts = displayName.split(",").map((part) => part.trim()).filter(Boolean);
  const [name, ...rest] = parts;
  return { name: name || displayName.trim(), address: rest.length ? rest.join(", ") : null };
}

function bestAddressName(address: Record<string, unknown> | undefined) {
  if (!address) return "";
  for (const key of [
    "amenity", "shop", "tourism", "office", "leisure", "building",
    "house_name", "road", "neighbourhood", "suburb", "village",
    "town", "city", "municipality", "county", "state",
  ]) {
    const value = address[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  return "";
}

function normalizeLocationIq(raw: LocationIqPlace): LocationResult | null {
  const lat = Number(raw.lat);
  const lon = Number(raw.lon);
  const displayName = typeof raw.display_name === "string" ? raw.display_name.trim() : "";
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || !displayName) return null;

  const split = splitDisplayName(displayName);
  const explicitName = typeof raw.name === "string" ? raw.name.trim() : "";
  const addressName = bestAddressName(raw.address);
  const name = explicitName || addressName || split.name || "สถานที่";
  const address = displayName === name
    ? null
    : displayName.startsWith(name + ",")
      ? displayName.slice(name.length + 1).trim()
      : displayName;
  const placeId = raw.place_id != null
    ? String(raw.place_id)
    : `${raw.osm_type ?? "unknown"}:${raw.osm_id ?? ""}`;

  return { name, address, lat, lon, place_id: placeId };
}

function stringProp(props: Record<string, unknown>, key: string) {
  const value = props[key];
  return typeof value === "string" && value.trim() ? value.trim() : "";
}

function haversineKm(aLat: number, aLon: number, bLat: number, bLon: number) {
  const r = 6371;
  const toRad = (value: number) => value * Math.PI / 180;
  const dLat = toRad(bLat - aLat);
  const dLon = toRad(bLon - aLon);
  const x = Math.sin(dLat / 2) ** 2
    + Math.cos(toRad(aLat)) * Math.cos(toRad(bLat)) * Math.sin(dLon / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}

function normalizePhoton(feature: PhotonFeature, requested?: { lat: number; lon: number }): LocationResult | null {
  const coords = feature.geometry?.coordinates;
  const props = feature.properties ?? {};
  const lon = Number(Array.isArray(coords) ? coords[0] : NaN);
  const lat = Number(Array.isArray(coords) ? coords[1] : NaN);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;

  const featureName = stringProp(props, "name");
  const street = stringProp(props, "street");
  const locality = stringProp(props, "locality");
  const district = stringProp(props, "district");
  const city = stringProp(props, "city");
  const county = stringProp(props, "county");
  const state = stringProp(props, "state");
  const postcode = stringProp(props, "postcode");
  const country = stringProp(props, "country");

  const distanceKm = requested ? haversineKm(requested.lat, requested.lon, lat, lon) : 0;
  const fallbackArea = street || locality || district || city || county || state || country || "สถานที่";
  // Photon reverse can return the nearest named POI even when it is several
  // hundred metres away. Avoid presenting that POI as the exact pin location.
  const name = requested && distanceKm > 0.20 ? fallbackArea : (featureName || fallbackArea);

  const parts = [street, locality, district, city, county, state, postcode, country]
    .filter((value, index, values) => value && value !== name && values.indexOf(value) === index);

  const osmType = stringProp(props, "osm_type") || "unknown";
  const osmId = props.osm_id == null ? "" : String(props.osm_id);
  return {
    name,
    address: parts.length ? parts.join(", ") : null,
    lat,
    lon,
    place_id: `${osmType}:${osmId}`,
  };
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function clientKey(req: Request) {
  const forwarded = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const ip = req.headers.get("cf-connecting-ip")?.trim()
    || req.headers.get("x-real-ip")?.trim()
    || forwarded
    || "unknown";
  const ua = (req.headers.get("user-agent") ?? "").slice(0, 160);
  return sha256(`${SERVICE_ROLE_KEY.slice(0, 24)}|${ip}|${ua}`);
}

async function serviceRpc(name: string, body: Record<string, unknown>) {
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });
  if (!response.ok) return { ok: false, data: null as unknown };
  return { ok: true, data: await response.json().catch(() => null) };
}

async function reserveClient(req: Request) {
  const key = await clientKey(req);
  const result = await serviceRpc("reserve_wynos_maps_geocode_request", { p_client_key: key });
  return result.ok && result.data === true;
}

async function reservePhoton() {
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const result = await serviceRpc("reserve_wynos_maps_photon_request", {});
    if (result.ok && result.data === true) return true;
    await new Promise((resolve) => setTimeout(resolve, 550));
  }
  return false;
}

function reverseCacheKey(lat: number, lon: number) {
  return `${lat.toFixed(4)},${lon.toFixed(4)}`;
}

async function reverseCacheGet(cacheKey: string): Promise<LocationResult | null> {
  const result = await serviceRpc("wynos_maps_reverse_cache_get", { p_cache_key: cacheKey });
  if (!result.ok || !result.data || typeof result.data !== "object") return null;
  const row = result.data as { name?: unknown; address?: unknown; lat?: unknown; lon?: unknown; place_id?: unknown };
  const lat = Number(row.lat);
  const lon = Number(row.lon);
  if (typeof row.name !== "string" || !Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  return {
    name: row.name,
    address: typeof row.address === "string" ? row.address : null,
    lat,
    lon,
    place_id: row.place_id == null ? "" : String(row.place_id),
  };
}

async function reverseCachePut(cacheKey: string, place: LocationResult, provider: "photon" | "locationiq") {
  await serviceRpc("wynos_maps_reverse_cache_put", {
    p_cache_key: cacheKey,
    p_latitude: place.lat,
    p_longitude: place.lon,
    p_name: place.name,
    p_address: place.address,
    p_external_place_id: place.place_id,
    p_provider: provider,
  });
}

async function fetchJson(url: URL, headers: Record<string, string>) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(url, { signal: controller.signal, headers });
    if (!response.ok) throw new Error(`geocoder responded ${response.status}`);
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

async function photon(url: URL) {
  if (!(await reservePhoton())) throw new Error("photon busy");
  return await fetchJson(url, {
    Accept: "application/json",
    "Accept-Language": "th,en;q=0.8",
    "User-Agent": APP_USER_AGENT,
  });
}

async function photonSearch(query: string, location?: { lat: number; lon: number }) {
  const url = new URL(`${PHOTON_BASE}/api`);
  url.searchParams.set("q", query);
  url.searchParams.set("limit", "10");
  url.searchParams.set("bbox", THAILAND_BBOX);
  if (location) {
    url.searchParams.set("lat", String(location.lat));
    url.searchParams.set("lon", String(location.lon));
  }

  const raw = await photon(url) as { features?: PhotonFeature[] };
  return Array.isArray(raw.features)
    ? raw.features.flatMap((feature) => {
      const place = normalizePhoton(feature);
      return place ? [place] : [];
    }).slice(0, 10)
    : [];
}

async function photonReverse(lat: number, lon: number) {
  const cacheKey = reverseCacheKey(lat, lon);
  const cached = await reverseCacheGet(cacheKey);
  if (cached) return cached;

  const url = new URL(`${PHOTON_BASE}/reverse`);
  url.searchParams.set("lat", String(lat));
  url.searchParams.set("lon", String(lon));
  url.searchParams.set("limit", "1");
  url.searchParams.set("radius", "10");

  const raw = await photon(url) as { features?: PhotonFeature[] };
  const feature = Array.isArray(raw.features) ? raw.features[0] : null;
  const place = feature ? normalizePhoton(feature, { lat, lon }) : null;
  if (place) await reverseCachePut(cacheKey, place, "photon");
  return place;
}

async function locationIq(url: URL) {
  return await fetchJson(url, { Accept: "application/json" });
}

function json(origin: string | null, body: unknown, status = 200, provider = "none") {
  return new Response(JSON.stringify({ ...(body as Record<string, unknown>), provider }), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
      "Cache-Control": status === 200 ? "public, max-age=30" : "no-store",
      "X-WYNOS-Maps-Provider": provider,
    },
  });
}

Deno.serve(async (req) => {
  const origin = req.headers.get("Origin");
  if (req.method === "OPTIONS") {
    if (origin && !ALLOWED_ORIGINS.has(origin)) return json(origin, { error: "Origin not allowed" }, 403);
    return new Response(null, { status: 204, headers: corsHeaders(origin) });
  }

  if (req.method !== "POST") return json(origin, { error: "Method not allowed" }, 405);
  if (origin && !ALLOWED_ORIGINS.has(origin)) return json(origin, { error: "Origin not allowed" }, 403);

  const apiKey = req.headers.get("apikey") ?? "";
  const validPublicKey = apiKey.length > 0
    && (apiKey === LEGACY_PUBLIC_API_KEY || PUBLISHABLE_KEYS.includes(apiKey));
  if (!validPublicKey) return json(origin, { error: "Unauthorized" }, 401);

  let body: { mode?: string; query?: string; lat?: number; lon?: number };
  try {
    body = await req.json();
  } catch {
    return json(origin, { error: "Bad request" }, 400);
  }

  if (!(await reserveClient(req))) return json(origin, { error: "Rate limited" }, 429);

  try {
    if (body.mode === "search") {
      const query = body.query?.trim() ?? "";
      if (!query || query.length > MAX_QUERY_LENGTH) return json(origin, { results: [] });

      if (LOCATIONIQ_API_KEY) {
        const url = new URL("https://us1.locationiq.com/v1/search");
        url.searchParams.set("key", LOCATIONIQ_API_KEY);
        url.searchParams.set("q", query);
        url.searchParams.set("format", "json");
        url.searchParams.set("limit", "10");
        url.searchParams.set("accept-language", "th,en");
        url.searchParams.set("countrycodes", "th");
        const raw = await locationIq(url);
        const rows = Array.isArray(raw) ? raw.flatMap((row) => {
          const place = normalizeLocationIq(row as LocationIqPlace);
          return place ? [place] : [];
        }) : [];
        return json(origin, { results: rows }, 200, "locationiq");
      }

      const lat = Number(body.lat);
      const lon = Number(body.lon);
      const bias = Number.isFinite(lat) && Number.isFinite(lon) && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180
        ? { lat, lon }
        : undefined;
      const rows = await photonSearch(query, bias);
      return json(origin, { results: rows }, 200, "photon");
    }

    if (body.mode === "reverse") {
      const lat = Number(body.lat);
      const lon = Number(body.lon);
      if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        return json(origin, { error: "Bad request" }, 400);
      }

      if (LOCATIONIQ_API_KEY) {
        const url = new URL("https://us1.locationiq.com/v1/reverse");
        url.searchParams.set("key", LOCATIONIQ_API_KEY);
        url.searchParams.set("lat", String(lat));
        url.searchParams.set("lon", String(lon));
        url.searchParams.set("format", "json");
        url.searchParams.set("accept-language", "th,en");
        const raw = await locationIq(url);
        const place = normalizeLocationIq(raw as LocationIqPlace);
        if (place) await reverseCachePut(reverseCacheKey(lat, lon), place, "locationiq");
        return json(origin, { results: place ? [place] : [] }, 200, "locationiq");
      }

      const place = await photonReverse(lat, lon);
      return json(origin, { results: place ? [place] : [] }, 200, "photon");
    }

    return json(origin, { error: "Bad request" }, 400);
  } catch (error) {
    console.error("WYNOS Maps geocoder error", error instanceof Error ? error.message : String(error));
    return json(origin, { error: "Geocoder unavailable" }, 502);
  }
});
