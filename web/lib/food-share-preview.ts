import type { Metadata } from "next";

import {
  FOOD_SITE_URL,
  type FoodStoreSharePreview,
  foodStorePreviewContent,
  foodStoreShareUrl,
  isFoodShareCode,
  isFoodStoreId,
} from "@/lib/food-share";

// LINE/Messenger fetch a shared Food link without signing in, so the preview
// comes from food_store_share_preview: the public profile (name, short
// description, logo, cover) of a published, non-suspended store only.
async function fetchStoreSharePreview(storeId: string): Promise<FoodStoreSharePreview | null> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return null;
  try {
    const response = await fetch(`${url.replace(/\/+$/, "")}/rest/v1/rpc/food_store_share_preview`, {
      method: "POST",
      headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_store_id: storeId }),
      next: { revalidate: 300 },
      signal: AbortSignal.timeout(2500),
    });
    if (!response.ok) return null;
    const rows = (await response.json()) as unknown;
    const row = Array.isArray(rows) ? rows[0] : null;
    if (!row || typeof row !== "object" || typeof (row as FoodStoreSharePreview).name !== "string") return null;
    return row as FoodStoreSharePreview;
  } catch {
    return null;
  }
}

/** The store id behind a short link, or null when unknown or not public. */
export async function resolveFoodShareCode(code: string): Promise<string | null> {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key || !isFoodShareCode(code)) return null;
  try {
    const response = await fetch(`${url.replace(/\/+$/, "")}/rest/v1/rpc/food_store_id_by_share_code`, {
      method: "POST",
      headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({ p_code: code }),
      next: { revalidate: 300 },
      signal: AbortSignal.timeout(2500),
    });
    if (!response.ok) return null;
    const id = (await response.json()) as unknown;
    return typeof id === "string" && isFoodStoreId(id) ? id : null;
  } catch {
    return null;
  }
}

/** Metadata for /?store=<id>; null keeps the generic WYNOS Food preview. */
export async function foodStoreShareMetadata(requested: string | string[] | undefined): Promise<Metadata | null> {
  const storeId = typeof requested === "string" ? requested.trim() : "";
  if (!isFoodStoreId(storeId)) return null;
  const store = await fetchStoreSharePreview(storeId);
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
  if (!store || !supabaseUrl) return null;
  const { title, description, imageUrl, largeImage } = foodStorePreviewContent(store, supabaseUrl);
  const shareUrl = foodStoreShareUrl(store);
  const images = imageUrl ? [{ url: imageUrl, alt: store.name }] : [{ url: `${FOOD_SITE_URL}/icons/food/icon-512.png`, width: 512, height: 512, alt: "WYNOS Food" }];
  return {
    title,
    description,
    openGraph: { type: "website", url: shareUrl, siteName: "WYNOS Food", locale: "th_TH", title, description, images },
    twitter: { card: largeImage ? "summary_large_image" : "summary", title, description, images: images.map((image) => image.url) },
  };
}
