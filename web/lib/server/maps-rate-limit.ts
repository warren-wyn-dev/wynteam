// Per-client fixed-window rate limit for the public WYNOS Maps Core API.
//
// State lives in the memory of one serverless instance, so this is a
// best-effort first layer. The self-hosted geo/routing gateway enforces the
// global limit (see tools/maps-selfhost/Caddyfile).

export type MapsRateLimitBucket = "search" | "reverse" | "route";

const WINDOW_MS = 60_000;
const MAX_TRACKED_CLIENTS = 5_000;

export const MAPS_RATE_LIMITS: Record<MapsRateLimitBucket, number> = {
  search: 30,
  reverse: 30,
  route: 10,
};

type Window = { startedAt: number; count: number };

const windows = new Map<string, Window>();

export function mapsClientKey(headers: Headers) {
  // Vercel overwrites X-Forwarded-For, so its first entry is the client IP.
  const forwarded = headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  const ip = forwarded || headers.get("x-real-ip")?.trim() || "unknown";
  return ip.slice(0, 64);
}

function prune(now: number) {
  for (const [key, window] of windows) {
    if (now - window.startedAt >= WINDOW_MS) windows.delete(key);
  }
  // Still full after pruning: drop the oldest entries rather than grow without bound.
  while (windows.size >= MAX_TRACKED_CLIENTS) {
    const oldest = windows.keys().next().value;
    if (oldest === undefined) break;
    windows.delete(oldest);
  }
}

/** Counts one request and reports whether it is allowed. */
export function takeMapsRateLimit(bucket: MapsRateLimitBucket, clientKey: string, now = Date.now()) {
  const limit = MAPS_RATE_LIMITS[bucket];
  const key = `${bucket}:${clientKey}`;
  let window = windows.get(key);
  if (!window || now - window.startedAt >= WINDOW_MS) {
    if (!window && windows.size >= MAX_TRACKED_CLIENTS) prune(now);
    window = { startedAt: now, count: 0 };
    windows.set(key, window);
  }

  window.count += 1;
  const retryAfterSeconds = Math.max(1, Math.ceil((window.startedAt + WINDOW_MS - now) / 1000));
  return {
    allowed: window.count <= limit,
    limit,
    remaining: Math.max(0, limit - window.count),
    retryAfterSeconds,
  };
}

export function resetMapsRateLimitForTests() {
  windows.clear();
}
