// Share links for WYNOS Food stores: a merchant or customer posts
// https://food.wynos.online/?store=<id> to a group chat and whoever taps it
// opens that store's menu. Only a well-formed store id is ever read back;
// the server still decides (RLS) whether the store is visible to the viewer.
export const FOOD_SITE_URL = "https://food.wynos.online";

const STORE_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const PENDING_KEY = "wynos-food-shared-store-v1";
const PENDING_MAX_AGE_MS = 60 * 60 * 1000;

export function isFoodStoreId(value: string): boolean {
  return STORE_ID.test(value);
}

export function foodStoreShareUrl(storeId: string): string {
  return `${FOOD_SITE_URL}/?store=${encodeURIComponent(storeId)}`;
}

export function foodStoreShareData(store: { id: string; name: string }) {
  return {
    title: `${store.name} | WYNOS Food`,
    text: `สั่งอาหารร้าน ${store.name} ผ่าน WYNOS Food กดลิงก์นี้ได้เลย`,
    url: foodStoreShareUrl(store.id),
  };
}

/** The store id in `?store=`, or null when missing or malformed. */
export function sharedFoodStoreId(search: string): string | null {
  const requested = new URLSearchParams(search).get("store")?.trim() ?? "";
  return isFoodStoreId(requested) ? requested : null;
}

/**
 * Keeps a shared store across the sign-in wall. Food lives at "/" on its own
 * domain, which the generic return path never stores, so without this a
 * signed-out customer would land on the default store after signing in.
 */
export function rememberSharedFoodStore(storeId: string): void {
  if (!isFoodStoreId(storeId)) return;
  try { window.sessionStorage.setItem(PENDING_KEY, JSON.stringify({ storeId, at: Date.now() })); } catch { /* storage unavailable */ }
}

/** The remembered shared store, or null. Read-only; see clearSharedFoodStore. */
export function pendingSharedFoodStore(): string | null {
  let raw: string | null = null;
  try { raw = window.sessionStorage.getItem(PENDING_KEY); } catch { return null; }
  if (!raw) return null;
  try {
    const { storeId, at } = JSON.parse(raw) as { storeId?: unknown; at?: unknown };
    if (typeof storeId !== "string" || typeof at !== "number" || Date.now() - at > PENDING_MAX_AGE_MS) return null;
    return isFoodStoreId(storeId) ? storeId : null;
  } catch {
    return null;
  }
}

export function clearSharedFoodStore(): void {
  try { window.sessionStorage.removeItem(PENDING_KEY); } catch { /* storage unavailable */ }
}

export type FoodStoreSharePreview = {
  id: string;
  name: string;
  description: string | null;
  logo_path: string | null;
  cover_path: string | null;
};

/** Public URL of a file in the food-public bucket (store logos and covers). */
export function foodPublicFileUrl(supabaseUrl: string, path: string): string {
  const encoded = path.split("/").map(encodeURIComponent).join("/");
  return `${supabaseUrl.replace(/\/+$/, "")}/storage/v1/object/public/food-public/${encoded}`;
}

/** Link-preview title, text and image for a shared store. */
export function foodStorePreviewContent(store: FoodStoreSharePreview, supabaseUrl: string) {
  const image = store.cover_path ?? store.logo_path;
  return {
    title: `${store.name} | WYNOS Food`,
    description: store.description ?? `สั่งอาหารร้าน ${store.name} ผ่าน WYNOS Food`,
    imageUrl: image ? foodPublicFileUrl(supabaseUrl, image) : null,
    largeImage: Boolean(store.cover_path),
  };
}
