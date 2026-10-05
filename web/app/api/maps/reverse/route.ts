import { NextResponse } from "next/server";

import { mapsRateLimitResponse } from "@/lib/server/maps-rate-limit-response";
import { reverseWynosGeo } from "@/lib/server/wynos-maps-core";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const params = new URL(request.url).searchParams;
  const lat = Number(params.get("lat"));
  const lon = Number(params.get("lon"));
  if (!Number.isFinite(lat) || !Number.isFinite(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    return NextResponse.json({ error: "INVALID_COORDINATES", results: [] }, { status: 400 });
  }

  const limited = mapsRateLimitResponse(request, "reverse", { results: [] });
  if (limited) return limited;

  try {
    const results = await reverseWynosGeo(lat, lon);
    if (results === null) {
      return NextResponse.json(
        { error: "WYNOS_GEO_NOT_CONFIGURED", results: [] },
        { status: 503, headers: { "X-WYNOS-Maps-Provider": "not-configured" } },
      );
    }
    return NextResponse.json(
      { results },
      { headers: { "Cache-Control": "public, s-maxage=300, stale-while-revalidate=1800", "X-WYNOS-Maps-Provider": "wynos-geo" } },
    );
  } catch {
    return NextResponse.json({ error: "WYNOS_GEO_UNAVAILABLE", results: [] }, { status: 502 });
  }
}
