import { createClient } from "@/lib/supabase/server";

export type AdminMenuOptionChoice = { id: string; name: string; price: number };
export type AdminMenuOptionGroup = {
  id: string; name: string; required: boolean; max_select: number;
  choices: AdminMenuOptionChoice[];
};

export type AdminMerchantMenuItem = {
  id: string;
  store_id: string;
  store_name: string;
  name: string;
  category: string;
  description: string | null;
  price: number;
  is_available: boolean;
  daily_stock_limit: number | null;
  sold_out_until: string | null;
  image_path: string | null;
  options: AdminMenuOptionGroup[];
  archived_at: string | null;
  updated_at: string;
};

export type AdminMerchantMenuStore = {
  id: string; name: string; menu_category_order: string[]; updated_at: string;
};
export type AdminMerchantMenuCatalog = {
  stores: AdminMerchantMenuStore[];
  items: AdminMerchantMenuItem[];
  images: Array<{ store_id: string; path: string }>;
};

export function parseAdminMenuCatalog(data: unknown): AdminMerchantMenuCatalog {
  if (!data || typeof data !== "object") throw new Error("invalid_menu_catalog");
  const value = data as Partial<AdminMerchantMenuCatalog>;
  if (!Array.isArray(value.stores) || !Array.isArray(value.items) || !Array.isArray(value.images)) {
    throw new Error("invalid_menu_catalog");
  }
  return value as AdminMerchantMenuCatalog;
}

export async function fetchAdminMerchantMenuCatalog(): Promise<AdminMerchantMenuCatalog> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_merchant_menu_catalog", { p_store_id: null })
    .abortSignal(AbortSignal.timeout(15_000));
  if (error) throw error;
  return parseAdminMenuCatalog(data);
}

export async function fetchAdminMerchantMenu(): Promise<AdminMerchantMenuItem[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_merchant_menu_items", {p_store_id: null});
  if (error) throw error;
  return Array.isArray(data) ? (data as AdminMerchantMenuItem[]) : [];
}
