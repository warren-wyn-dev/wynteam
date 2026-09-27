import { NextResponse } from "next/server";
import { assetLinks } from "@/lib/android-asset-links";

export function GET() {
  return NextResponse.json(assetLinks(process.env.ANDROID_TWA_SHA256_FINGERPRINTS), {
    headers: { "Cache-Control": "public, max-age=3600" },
  });
}
