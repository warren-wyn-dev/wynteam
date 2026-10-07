import { NextResponse } from "next/server";

import { mapsRateLimitResponse } from "@/lib/server/maps-rate-limit-response";
import { routeWynosMaps } from "@/lib/server/wynos-maps-core";

export const dynamic = "force-dynamic";

type RouteBody = {
  locations?: Array<{ lat?: unknown; lon?: unknown }>;
  costing?: unknown;
  language?: unknown;
};

export async function POST(request: Request) {
  const limited = mapsRateLimitResponse(request, "route", {});
  if (limited) return limited;

  let body: RouteBody;
  try {
    body = await request.json() as RouteBody;
  } catch {
    return NextResponse.json({ error: "INVALID_JSON" }, { status: 400 });
  }

  const locations = Array.isArray(body.locations)
    ? body.locations.map((location) => ({ lat: Number(location.lat), lon: Number(location.lon) }))
    : [];
  const costing = typeof body.costing === "string" ? body.costing : "motorcycle";
  const language = body.language === "en-US" ? "en-US" : "th-TH";

  try {
    const route = await routeWynosMaps({ locations, costing, language });
    if (route === null) {
      return NextResponse.json(
        { error: "WYNOS_ROUTING_NOT_CONFIGURED" },
        { status: 503, headers: { "X-WYNOS-Maps-Provider": "not-configured" } },
      );
    }
    return NextResponse.json(route, { headers: { "X-WYNOS-Maps-Provider": "wynos-routing" } });
  } catch (error) {
    const message = error instanceof Error ? error.message : "";
    if (message === "unsupported costing" || message === "invalid locations" || message === "invalid location") {
      return NextResponse.json({ error: "INVALID_ROUTE_REQUEST" }, { status: 400 });
    }
    return NextResponse.json({ error: "WYNOS_ROUTING_UNAVAILABLE" }, { status: 502 });
  }
}
