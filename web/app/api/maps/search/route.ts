import { NextResponse } from "next/server";

import { searchWynosGeo } from "@/lib/server/wynos-maps-core";

export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const query = new URL(request.url).searchParams.get("q")?.trim() ?? "";
  if (!query) return NextResponse.json({ results: [] });

  try {
    const results = await searchWynosGeo(query);
    if (results === null) {
      return NextResponse.json(
        { error: "WYNOS_GEO_NOT_CONFIGURED", results: [] },
        { status: 503, headers: { "X-WYNOS-Maps-Provider": "not-configured" } },
      );
    }
    return NextResponse.json(
      { results },
      { headers: { "Cache-Control": "public, s-maxage=60, stale-while-revalidate=300", "X-WYNOS-Maps-Provider": "wynos-geo" } },
    );
  } catch {
    return NextResponse.json({ error: "WYNOS_GEO_UNAVAILABLE", results: [] }, { status: 502 });
  }
}
