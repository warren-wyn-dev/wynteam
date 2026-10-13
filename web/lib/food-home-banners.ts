import type { SupabaseClient } from "@supabase/supabase-js";
export type FoodHomeBanner = { id:string; title:string; subtitle:string|null; image_path:string; destination_store_id:string|null };
export async function fetchFoodHomeBanners(client: SupabaseClient): Promise<FoodHomeBanner[]> {
 const {data,error}=await client.rpc("food_active_home_banners");
 return error || !Array.isArray(data) ? [] : data as FoodHomeBanner[];
}
export function foodHomeBannerImage(client: SupabaseClient,path:string):string {
 return client.storage.from("food-banners").getPublicUrl(path).data.publicUrl;
}
