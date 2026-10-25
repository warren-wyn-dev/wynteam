import { createClient } from "@/lib/supabase/server";

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
  updated_at: string;
};

export async function fetchAdminMerchantMenu(): Promise<AdminMerchantMenuItem[]> {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("admin_merchant_menu_items", {p_store_id: null});
  if (error) throw error;
  return Array.isArray(data) ? (data as AdminMerchantMenuItem[]) : [];
}
