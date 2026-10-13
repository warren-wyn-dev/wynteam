import { createClient } from "@/lib/supabase/server";

export type AdminFoodBanner = {
  id: string;
  title: string;
  subtitle: string | null;
  image_path: string;
  destination_store_id: string | null;
  sort_order: number;
  starts_at: string;
  ends_at: string | null;
  is_active: boolean;
  version: number;
  created_at: string;
  updated_at: string;
};
export type BannerStore = {id: string; name: string};

export async function fetchAdminFoodBanners(): Promise<AdminFoodBanner[]> {
  const client = await createClient();
  const {data,error} = await client.rpc("admin_food_home_banners");
  if(error) throw error;
  return Array.isArray(data) ? data as AdminFoodBanner[] : [];
}
export async function fetchAdminBannerStores(): Promise<BannerStore[]> {
  const client = await createClient();
  const {data,error} = await client.rpc("admin_food_stores",{p_query:null});
  if(error) throw error;
  return Array.isArray(data) ? data.map((x: {id: string; name: string})=>({id:x.id,name:x.name})) : [];
}
