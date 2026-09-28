import { NextResponse } from "next/server";

import { androidAssetLinks } from "@/lib/android-asset-links";

// Android checks this file when the app is installed (App Links); see
// docs/engineering/ANDROID_RELEASE.md. Read at request time so a new
// fingerprint only needs the setting changed.
export const dynamic = "force-dynamic";

export function GET() {
  return NextResponse.json(androidAssetLinks(process.env.ANDROID_APP_SHA256_FINGERPRINTS), {
    headers: { "Cache-Control": "public, max-age=300" },
  });
}
