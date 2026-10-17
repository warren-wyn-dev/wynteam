import "server-only";

import { adminCan, requireAdminRole } from "@/lib/auth";
import { createClient } from "@/lib/supabase/server";

export type MarketingArea = "banners" | "featured";
export type MarketingPanel = "manage" | "preview" | "analytics";

export function marketingArea(value: string | string[] | undefined): MarketingArea {
  return value === "featured" ? "featured" : "banners";
}

export function marketingPanel(value: string | string[] | undefined): MarketingPanel {
  return value === "preview" || value === "analytics" ? value : "manage";
}

export type BannerPreviewItem = {
  id: string;
  title: string;
  subtitle: string | null;
  imagePath: string;
  imageUrl: string;
  destinationStoreId: string | null;
};

export type MarketingPreview = {
  area: "banners";
  checkedAt: string;
  items: BannerPreviewItem[];
} | {
  area: "featured";
  checkedAt: string;
  namesAvailable: boolean;
  items: Array<{ storeId: string; priority: number; storeName: string | null }>;
};

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const BANNER_PATH = /^banners\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(png|jpg|jpeg|webp)$/;
const READ_TIMEOUT_MS = 10_000;

function records(data: unknown, maximum: number): Array<Record<string, unknown>> {
  if (!Array.isArray(data) || data.length > maximum || data.some(
    (row) => row === null || typeof row !== "object" || Array.isArray(row),
  )) throw new Error("Invalid public placement response");
  return data;
}

/**
 * Read the same public selections used by Food, in their returned order. This
 * does not simulate a schedule, query a customer's location, or ingest events.
 * Keep the Admin page protected even though these two RPCs are public reads.
 */
export async function fetchMarketingPreview(area: MarketingArea): Promise<MarketingPreview> {
  const ctx = await requireAdminRole();
  if (!adminCan(ctx, "food")) throw new Error("Food access is required");

  const client = await createClient();
  if (area === "banners") {
    const { data, error } = await client.rpc("food_active_home_banners")
      .abortSignal(AbortSignal.timeout(READ_TIMEOUT_MS));
    if (error) throw error;
    const seen = new Set<string>();
    const items = records(data, 8).map((row): BannerPreviewItem => {
      if (typeof row.id !== "string" || !UUID.test(row.id) || seen.has(row.id)
        || typeof row.title !== "string" || row.title.length < 2 || row.title.length > 90
        || (row.subtitle !== null && (typeof row.subtitle !== "string" || row.subtitle.length > 180))
        || typeof row.image_path !== "string" || !BANNER_PATH.test(row.image_path)
        || (row.destination_store_id !== null
          && (typeof row.destination_store_id !== "string" || !UUID.test(row.destination_store_id)))) {
        throw new Error("Invalid public banner response");
      }
      seen.add(row.id);
      return {
        id: row.id,
        title: row.title,
        subtitle: row.subtitle as string | null,
        imagePath: row.image_path,
        imageUrl: client.storage.from("food-banners").getPublicUrl(row.image_path).data.publicUrl,
        destinationStoreId: row.destination_store_id as string | null,
      };
    });
    return { area, checkedAt: new Date().toISOString(), items };
  }

  const [selection, labels] = await Promise.allSettled([
    client.rpc("food_active_featured_stores").abortSignal(AbortSignal.timeout(READ_TIMEOUT_MS)),
    client.rpc("admin_food_featured_stores").abortSignal(AbortSignal.timeout(READ_TIMEOUT_MS)),
  ]);
  if (selection.status === "rejected") throw selection.reason;
  if (selection.value.error) throw selection.value.error;

  // A failed Admin label lookup must never erase a successful public selection.
  const namesAvailable = labels.status === "fulfilled" && !labels.value.error
    && Array.isArray(labels.value.data);
  const names = new Map<string, string>();
  if (namesAvailable && labels.status === "fulfilled") {
    for (const row of labels.value.data as unknown[]) {
      if (row && typeof row === "object" && "store_id" in row && "store_name" in row
        && typeof row.store_id === "string" && typeof row.store_name === "string") {
        names.set(row.store_id, row.store_name);
      }
    }
  }
  const seen = new Set<string>();
  const items = records(selection.value.data, 20).map((row) => {
    if (typeof row.store_id !== "string" || !UUID.test(row.store_id) || seen.has(row.store_id)
      || typeof row.priority !== "number" || !Number.isInteger(row.priority)
      || row.priority < 1 || row.priority > 100) throw new Error("Invalid public featured response");
    seen.add(row.store_id);
    return { storeId: row.store_id, priority: row.priority, storeName: names.get(row.store_id) ?? null };
  });
  return { area, checkedAt: new Date().toISOString(), namesAvailable, items };
}
