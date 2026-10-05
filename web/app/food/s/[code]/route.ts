import { after, NextResponse, type NextRequest } from "next/server";

import { FOOD_SITE_URL } from "@/lib/food-share";
import { recordFoodShareOpen, resolveFoodShareCode } from "@/lib/food-share-preview";

// Short share link food.wynos.online/s/<code> (rewritten here from the Food
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
  const onFoodHost = request.headers.get("host")?.split(":")[0].toLowerCase() === "food.wynos.online";
  const target = onFoodHost ? new URL("/", FOOD_SITE_URL) : new URL("/food", request.url);
  if (storeId) target.searchParams.set("store", storeId);
  return NextResponse.redirect(target, 307);
}
