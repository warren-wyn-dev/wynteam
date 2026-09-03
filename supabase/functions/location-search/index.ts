// WYN-098: Location Check-in search/reverse-geocode proxy.
//
// Called directly by the Flutter client (`supabase.functions.invoke`,
// see app/lib/features/drop/data/location_repository.dart), unlike
// send-push-notification (webhook-triggered) -- the caller's JWT is
// attached automatically by the Supabase client and, per this
// function's platform-level `verify_jwt` setting (the default for a
// deployed Edge Function -- true unless explicitly disabled via
// `supabase functions deploy --no-verify-jwt`, which this project does
// NOT pass), Supabase itself rejects an unauthenticated/invalid-JWT
// request *before* this code ever runs. userIdFromAuthHeader() in
// _lib.ts only *decodes* (never re-verifies) that already-trusted
// token to read the caller's user id for rate-limiting -- see that
// function's own doc comment.
//
// Required secret (`supabase secrets set LOCATIONIQ_API_KEY=...`, set
// by Founder/DevOps once a LocationIQ account exists -- see
// .wyn/company/DECISIONS.md 2026-09-02, "Founder เลือก LocationIQ"):
//   LOCATIONIQ_API_KEY
//
// Request body: {"mode": "search", "query": "starbucks"}
//            or {"mode": "reverse", "lat": 13.75, "lon": 100.50}
// Response body: {"results": LocationResult[]} on success,
//                {"error": "..."} with a non-200 status otherwise.
import {
  buildReverseUrl,
  buildSearchUrl,
  isRateLimited,
  parseReverseGeocodeResult,
  parseSearchResults,
  userIdFromAuthHeader,
} from "./_lib.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// 5-8 seconds per Product spec's Edge Cases table ("Edge Function
// ต้องมี timeout ที่เหมาะสม (เช่น 5-8 วินาที)") -- LocationIQ being
// slow/down must never hang this function indefinitely.
const LOCATIONIQ_TIMEOUT_MS = 7000;

async function countRecentRequests(userId: string): Promise<number> {
  const since = new Date(Date.now() - 60_000).toISOString();
  const response = await fetch(
    `${SUPABASE_URL}/rest/v1/location_search_requests` +
      `?user_id=eq.${userId}&requested_at=gte.${encodeURIComponent(since)}&select=id`,
    {
      headers: {
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        // exact count without fetching every row's full body -- Prefer
        // header is PostgREST's own mechanism for this.
        Prefer: "count=exact",
      },
    },
  );
  const contentRange = response.headers.get("content-range");
  // Format is "0-19/42" (or "*/0" when empty) -- the part after "/" is
  // the total count. Falls back to the fetched row count (safe under-
  // count, never an over-count that would wrongly reject a request) if
  // the header is missing/unparseable for any reason.
  const total = contentRange?.split("/")[1];
  if (total && total !== "*") return Number(total);
  const rows = await response.json().catch(() => []);
  return Array.isArray(rows) ? rows.length : 0;
}

async function logRequest(userId: string): Promise<void> {
  await fetch(`${SUPABASE_URL}/rest/v1/location_search_requests`, {
    method: "POST",
    headers: {
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ user_id: userId }),
  });
}

async function fetchLocationIq(url: string): Promise<unknown> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), LOCATIONIQ_TIMEOUT_MS);
  try {
    const response = await fetch(url, { signal: controller.signal });
    if (!response.ok) {
      throw new Error(`LocationIQ responded ${response.status}`);
    }
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), { status: 405 });
  }

  const userId = userIdFromAuthHeader(req.headers.get("Authorization"));
  if (!userId) {
    return new Response(JSON.stringify({ error: "Not authenticated" }), { status: 401 });
  }

  let body: { mode?: string; query?: string; lat?: number; lon?: number };
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "Bad request" }), { status: 400 });
  }

  // Server-side rate limit -- mandatory, not just the client's own
  // debounce (Product spec's ชั้นที่ 2). Checked *before* ever calling
  // LocationIQ, so an over-limit request never touches the app's
  // shared quota at all.
  const recentCount = await countRecentRequests(userId);
  if (isRateLimited(recentCount)) {
    return new Response(JSON.stringify({ error: "Rate limited" }), { status: 429 });
  }

  const apiKey = Deno.env.get("LOCATIONIQ_API_KEY");
  if (!apiKey) {
    // Not configured yet (Founder/DevOps hasn't set up LocationIQ) --
    // same "succeed with an empty/graceful result instead of a scary
    // 500" posture send-push-notification's own missing-FCM-config
    // branch already established. The client's own error copy ("ค้นหา
    // สถานที่ไม่สำเร็จตอนนี้...") covers this the same as any other
    // API failure -- posting still isn't blocked either way.
    return new Response(JSON.stringify({ error: "LocationIQ not configured" }), { status: 503 });
  }

  try {
    if (body.mode === "search") {
      const query = body.query?.trim();
      if (!query) {
        return new Response(JSON.stringify({ results: [] }), { status: 200 });
      }
      await logRequest(userId);
      const raw = await fetchLocationIq(buildSearchUrl(apiKey, query));
      return new Response(JSON.stringify({ results: parseSearchResults(raw) }), { status: 200 });
    }

    if (body.mode === "reverse") {
      if (typeof body.lat !== "number" || typeof body.lon !== "number") {
        return new Response(JSON.stringify({ error: "Bad request" }), { status: 400 });
      }
      await logRequest(userId);
      const raw = await fetchLocationIq(buildReverseUrl(apiKey, body.lat, body.lon));
      const result = parseReverseGeocodeResult(raw);
      return new Response(
        JSON.stringify({ results: result ? [result] : [] }),
        { status: 200 },
      );
    }

    return new Response(JSON.stringify({ error: "Bad request" }), { status: 400 });
  } catch (_error) {
    // LocationIQ timeout/non-OK response/network error -- fails
    // gracefully per Product spec's Edge Cases table ("แสดง 'ค้นหา
    // สถานที่ไม่สำเร็จตอนนี้...' โพสต์ยังโพสต์ได้ตามปกติโดยไม่มี
    // สถานที่แนบ"). The request was already logged above (it did
    // reach LocationIQ, or attempted to) -- correctly counts toward
    // this user's own rate limit either way.
    return new Response(JSON.stringify({ error: "Location search failed" }), { status: 502 });
  }
});
