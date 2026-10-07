import { NextResponse } from "next/server";

import { wynosMapsCoreStatus } from "@/lib/server/wynos-maps-core";

export const dynamic = "force-dynamic";

export async function GET() {
  const status = wynosMapsCoreStatus();
  return NextResponse.json({
    service: "WYNOS Maps Core",
    version: "core-api-v1",
    tiles: "https://tiles.wynos.online",
    geo: status.geoConfigured ? "configured" : "pending",
    routing: status.routingConfigured ? "configured" : "pending",
    routingProvider: status.routingProvider,
  });
}
