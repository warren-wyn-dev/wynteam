type GeoPlace = {
  name: string;
  address: string | null;
  lat: number;
  lon: number;
};

type NominatimRow = {
  lat?: unknown;
  lon?: unknown;
  name?: unknown;
  display_name?: unknown;
  address?: Record<string, unknown>;
};

const ALLOWED_ROUTING_COSTINGS = new Set(["auto", "motorcycle", "pedestrian", "bicycle"]);

function serviceOrigin(value: string | undefined) {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    return url.toString().replace(/\/$/, "");
  } catch {
    return null;
  }
}

function placeName(row: NominatimRow) {
  if (typeof row.name === "string" && row.name.trim()) return row.name.trim();
  const address = row.address ?? {};
  for (const key of ["amenity", "shop", "tourism", "building", "road", "village", "town", "city", "state"]) {
    const value = address[key];
    if (typeof value === "string" && value.trim()) return value.trim();
  }
  if (typeof row.display_name === "string") return row.display_name.split(",")[0]?.trim() ?? "";
  return "";
}

function normalizeGeoRow(row: NominatimRow): GeoPlace | null {
  const lat = Number(row.lat);
  const lon = Number(row.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  return {
    name: placeName(row),
    address: typeof row.display_name === "string" ? row.display_name : null,
    lat,
    lon,
  };
}

async function fetchJson(url: URL, init?: RequestInit) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5500);
  try {
    const response = await fetch(url, {
      ...init,
      signal: controller.signal,
      headers: {
        Accept: "application/json",
        "X-WYNOS-Maps": "core-api-v1",
        ...init?.headers,
      },
      cache: "no-store",
    });
    if (!response.ok) throw new Error(`maps upstream returned ${response.status}`);
    return await response.json() as unknown;
  } finally {
    clearTimeout(timeout);
  }
}

export function wynosMapsCoreStatus() {
  return {
    geoConfigured: Boolean(serviceOrigin(process.env.WYNOS_GEO_ORIGIN)),
    routingConfigured: Boolean(serviceOrigin(process.env.WYNOS_ROUTING_ORIGIN)),
  };
}

export async function searchWynosGeo(query: string) {
  const origin = serviceOrigin(process.env.WYNOS_GEO_ORIGIN);
  if (!origin) return null;

  const url = new URL(`${origin}/search`);
  url.searchParams.set("q", query.slice(0, 200));
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("limit", "8");
  url.searchParams.set("countrycodes", "th");
  url.searchParams.set("accept-language", "th,en");

  const raw = await fetchJson(url);
  if (!Array.isArray(raw)) return [];
  return raw.flatMap((row) => {
    const place = normalizeGeoRow(row as NominatimRow);
    return place ? [place] : [];
  }).slice(0, 8);
}

export async function reverseWynosGeo(lat: number, lon: number) {
  const origin = serviceOrigin(process.env.WYNOS_GEO_ORIGIN);
  if (!origin) return null;

  const url = new URL(`${origin}/reverse`);
  url.searchParams.set("lat", String(lat));
  url.searchParams.set("lon", String(lon));
  url.searchParams.set("format", "jsonv2");
  url.searchParams.set("addressdetails", "1");
  url.searchParams.set("zoom", "18");
  url.searchParams.set("accept-language", "th,en");

  const raw = await fetchJson(url);
  if (!raw || Array.isArray(raw) || typeof raw !== "object") return [];
  const place = normalizeGeoRow(raw as NominatimRow);
  return place ? [place] : [];
}

export async function routeWynosMaps(input: {
  locations: Array<{ lat: number; lon: number }>;
  costing: string;
}) {
  const origin = serviceOrigin(process.env.WYNOS_ROUTING_ORIGIN);
  if (!origin) return null;
  if (!ALLOWED_ROUTING_COSTINGS.has(input.costing)) throw new Error("unsupported costing");
  if (input.locations.length < 2 || input.locations.length > 25) throw new Error("invalid locations");

  for (const location of input.locations) {
    if (!Number.isFinite(location.lat) || !Number.isFinite(location.lon)) throw new Error("invalid location");
    if (location.lat < -90 || location.lat > 90 || location.lon < -180 || location.lon > 180) {
      throw new Error("invalid location");
    }
  }

  const url = new URL(`${origin}/route`);
  return await fetchJson(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      locations: input.locations,
      costing: input.costing,
      units: "kilometers",
      language: "th-TH",
      directions_options: { units: "kilometers" },
    }),
  });
}
