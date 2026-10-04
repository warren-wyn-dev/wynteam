// Public fallback geocoder for WYNOS Maps.
//
// This function is intentionally public to support maps.wynos.online before a
// user signs in. It never exposes the LocationIQ key. Access is restricted to
// the project's public API key + WYNOS browser origins and protected by a
// server-side hashed-client rate limiter. WYNOS-owned Places are queried by
// the client before this function is called.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const PUBLIC_API_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const LOCATIONIQ_API_KEY = Deno.env.get("LOCATIONIQ_API_KEY");

const ALLOWED_ORIGINS = new Set([
  "https://wynos.online",
  "https://www.wynos.online",
  "https://maps.wynos.online",
  "http://localhost:3000",
  "http://localhost:3001",
]);

const MAX_QUERY_LENGTH = 200;
const TIMEOUT_MS = 6500;

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
  display_name?: string;
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
  return {
    name: name || displayName.trim(),
    address: rest.length ? rest.join(", ") : null,
  };
}

function normalizePlace(raw: LocationIqPlace): LocationResult | null {
  const lat = Number(raw.lat);
  const lon = Number(raw.lon);
  const displayName = typeof raw.display_name === "string" ? raw.display_name.trim() : "";
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || !displayName) return null;

  const { name, address } = splitDisplayName(displayName);
  const placeId = raw.place_id != null
    ? String(raw.place_id)
    : `${raw.osm_type ?? "unknown"}:${raw.osm_id ?? ""}`;

  return { name, address, lat, lon, place_id: placeId };
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

async function reserve(req: Request) {
  const key = await clientKey(req);
  const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/reserve_wynos_maps_geocode_request`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ p_client_key: key }),
  });
  if (!response.ok) return false;
  return (await response.json().catch(() => false)) === true;
}

async function locationIq(url: URL) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      signal: controller.signal,
      headers: { Accept: "application/json" },
    });
    if (!response.ok) throw new Error(`LocationIQ responded ${response.status}`);
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

function json(origin: string | null, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(origin),
      "Content-Type": "application/json",
      "Cache-Control": status === 200 ? "public, max-age=30" : "no-store",
      "X-WYNOS-Maps-Provider": "locationiq-fallback",
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

  const apiKey = req.headers.get("apikey");
  if (!PUBLIC_API_KEY || !apiKey || apiKey !== PUBLIC_API_KEY) {
    return json(origin, { error: "Unauthorized" }, 401);
  }
  if (!LOCATIONIQ_API_KEY) return json(origin, { error: "Geocoder not configured" }, 503);
  if (!(await reserve(req))) return json(origin, { error: "Rate limited" }, 429);

  let body: { mode?: string; query?: string; lat?: number; lon?: number };
  try {
    body = await req.json();
  } catch {
    return json(origin, { error: "Bad request" }, 400);
  }

  try {
    if (body.mode === "search") {
      const query = body.query?.trim() ?? "";
      if (!query || query.length > MAX_QUERY_LENGTH) return json(origin, { results: [] });

      const url = new URL("https://us1.locationiq.com/v1/search");
      url.searchParams.set("key", LOCATIONIQ_API_KEY);
      url.searchParams.set("q", query);
      url.searchParams.set("format", "json");
      url.searchParams.set("limit", "10");
      url.searchParams.set("accept-language", "th,en");
      url.searchParams.set("countrycodes", "th");

      const raw = await locationIq(url);
      const rows = Array.isArray(raw) ? raw.flatMap((row) => {
        const place = normalizePlace(row as LocationIqPlace);
        return place ? [place] : [];
      }) : [];
      return json(origin, { results: rows });
    }

    if (body.mode === "reverse") {
      const lat = Number(body.lat);
      const lon = Number(body.lon);
      if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
        return json(origin, { error: "Bad request" }, 400);
      }

      const url = new URL("https://us1.locationiq.com/v1/reverse");
      url.searchParams.set("key", LOCATIONIQ_API_KEY);
      url.searchParams.set("lat", String(lat));
      url.searchParams.set("lon", String(lon));
      url.searchParams.set("format", "json");
      url.searchParams.set("accept-language", "th,en");

      const raw = await locationIq(url);
      const place = normalizePlace(raw as LocationIqPlace);
      return json(origin, { results: place ? [place] : [] });
    }

    return json(origin, { error: "Bad request" }, 400);
  } catch {
    return json(origin, { error: "Geocoder unavailable" }, 502);
  }
});
