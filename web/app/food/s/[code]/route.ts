import { after, NextResponse, type NextRequest } from "next/server";

import { isFoodAppHost } from "@/lib/food-origin";
import { recordFoodShareOpen, resolveFoodShareCode } from "@/lib/food-share-preview";

// Short share link zoky.wynos.online/s/<code> (rewritten here from the Food
// host). Sends people and link-preview crawlers to the store page, which
// carries the store's preview; an unknown or hidden store opens Food home.
export async function GET(request: NextRequest, { params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const normalized = code.trim().toLowerCase();
  const storeId = await resolveFoodShareCode(normalized);
  // Count the open for the store's share results after responding.
  if (storeId) {
    const userAgent = request.headers.get("user-agent");
    after(() => recordFoodShareOpen(normalized, userAgent));
  }
  // Stay on the Food origin the link was opened on (allowlisted host only):
  // zoky.wynos.online, or food.wynos.online while it still serves Food (phase 1).
  const host = request.headers.get("host")?.split(":")[0].toLowerCase() ?? "";
  const target = isFoodAppHost(host) ? new URL("/", `https://${host}`) : new URL("/food", request.url);
  if (storeId) target.searchParams.set("store", storeId);
  return NextResponse.redirect(target, 307);
}
