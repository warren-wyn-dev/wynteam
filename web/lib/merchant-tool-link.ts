import { isFoodStoreId } from "@/lib/food-share";

const TOOL_PAGES = ["finance", "ads", "campaigns", "promotions", "feedback", "store"] as const;
export type MerchantToolPage = typeof TOOL_PAGES[number];
export type MerchantToolLink = { tool: MerchantToolPage; storeId: string | null };

/** A navigation preference only; the existing Merchant snapshot still checks access. */
export function parseMerchantToolLink(search: string): MerchantToolLink | null {
  const params = new URLSearchParams(search);
  // Existing order notifications, notification tests and payment returns own
  // their entry behavior, even when their query value is malformed.
  if (["order", "notification-test", "payments"].some((key) => params.has(key))) return null;
  const tools = params.getAll("merchant-tool");
  if (tools.length !== 1 || !TOOL_PAGES.some((tool) => tool === tools[0])) return null;
  const stores = params.getAll("merchant-store");
  if (stores.length > 1) return null;
  const requestedStore = stores[0]?.trim();
  if (requestedStore !== undefined && !isFoodStoreId(requestedStore)) return null;
  return {
    tool: tools[0] as MerchantToolPage,
    storeId: requestedStore?.toLowerCase() ?? null,
  };
}
