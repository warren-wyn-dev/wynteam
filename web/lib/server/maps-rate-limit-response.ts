import { NextResponse } from "next/server";

import { mapsClientKey, takeMapsRateLimit, type MapsRateLimitBucket } from "@/lib/server/maps-rate-limit";

/** Returns a 429 response when the caller is over its limit, otherwise null. */
export function mapsRateLimitResponse(request: Request, bucket: MapsRateLimitBucket, body: Record<string, unknown>) {
  const result = takeMapsRateLimit(bucket, mapsClientKey(request.headers));
  if (result.allowed) return null;
  return NextResponse.json(
    { ...body, error: "WYNOS_MAPS_RATE_LIMITED" },
    {
      status: 429,
      headers: {
        "Cache-Control": "no-store",
        "Retry-After": String(result.retryAfterSeconds),
        "X-RateLimit-Limit": String(result.limit),
        "X-RateLimit-Remaining": "0",
      },
    },
  );
}
